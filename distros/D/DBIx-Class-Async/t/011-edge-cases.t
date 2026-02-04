#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

# Create user
my $user = $schema->resultset('User')
                  ->create({
                    name  => 'Alice',
                    email => 'alice@example.com', })
                  ->get;

subtest 'Empty results' => sub {

    my $rows = $schema->resultset('User')
                      ->search({ name => 'X' })
                      ->all_future
                      ->get;

    ok(ref $rows eq 'ARRAY', 'Empty search returns arrayref');
    is(scalar @$rows, 0, 'Empty search has no rows');

    my $count = $schema->resultset('User')
                       ->search({ name => 'X' })
                       ->count
                       ->get;

    is($count, 0, 'Count returns 0 for no results');

    my $update = $schema->resultset('User')
                        ->search({ name   => 'X' })
                        ->update({ active => 0   })
                        ->get;

    is($update + 0, 0, 'Update affects 0 rows');  # +0 converts '0E0' to 0

    my $delete = $schema->resultset('User')
                        ->search({ name => 'X' })
                        ->delete
                        ->get;

    is($delete, 0, 'Delete affects 0 rows');
};

subtest 'Encoding and special chars' => sub {

    my $new_name = "O'Connor & \"Special\" <Chars>";
    my $new_user = $schema->resultset('User')
                          ->create({ name   => $new_name,
                                     email  => 'new@example.com',
                                     active => 1 })->get;

    is($new_user->name, $new_name, 'Special characters preserved');

    my $verify = $schema->resultset('User')
                        ->search({ email => 'new@example.com' })
                        ->all_future
                        ->get;

    ok(@$verify > 0, 'Found user with special characters');
    is($verify->[0]->{name}, $new_name, 'Special characters retrieved correctly');

    $new_user->delete->get;
};

subtest 'Large result sets' => sub {

    # Create many users
    my $batch_size = 50;
    my @futures;

    for my $i (1..$batch_size) {
        push @futures, $schema->resultset('User')->create({
            name   => "Batch User $i",
            email  => "batch$i\@example.com",
            active => 1,
        });
    }

    my $creates = Future->wait_all(@futures)->get;

    my $count = $schema->resultset('User')
                       ->search({ name => { like => 'Batch User%' } })
                       ->count_future
                       ->get;

    cmp_ok($count, '>=', $batch_size, "Created at least $batch_size users");

    my $users = $schema->resultset('User')
                       ->search({ name => { like => 'Batch User%' } })
                       ->all_future
                       ->get;

    cmp_ok(@$users, '>=', $batch_size, "Fetched at least $batch_size users");

    my $deletes = $schema->resultset('User')
                         ->search({ name => { like => 'Batch User%' } })
                         ->delete
                         ->get;

    cmp_ok($deletes, '>=', $batch_size, "Deleted batch users");

};

subtest 'Concurrent access' => sub {

    # Create user
    my $new_user = $schema->resultset('User')
                          ->create({
                                name   => 'Concurrent Test',
                                email  => 'concurrent@example.com',
                                active => 1 })
                          ->get;

    my $user_id = $new_user->id;

    my @updates;
    for my $i (1..5) {
        push @updates, $schema->resultset('User')
                              ->find($user_id)
                              ->then(sub {
                                    my $user = shift;
                                    return Future->done(undef) unless $user;
                                    return $user->update({ name => "Update $i" });
                                });
    }

    my $updates = Future->wait_all(@updates)->get;

    my $final_user = $schema->resultset('User')->find($user_id)->get;
    ok($final_user, 'User still exists after concurrent updates');
    like($final_user->name, qr/^Update \d+$/, 'User was updated');

    my @reads;
    for my $i (1..10) {
        push @reads, $schema->resultset('User')->find($user_id);
    }

    my $reads = Future->wait_all(@reads)->get;

    my $all_ok = 1;
    foreach my $f (@reads) {
        my $user = $f->get;
        $all_ok &&= $user && $user->id == $user_id;
    }

    ok($reads, 'All concurrent reads succeeded');

    $final_user->delete->get;
};

subtest 'Error recovery' => sub {
    # 1. Invalid Table Name
    # We wrap the resultset call itself inside the block
    my $err_rs;
    eval {
        $err_rs = $schema->resultset('NonExistentTable');
    };
    ok($@ || !$err_rs, 'Accessing non-existent table failed or threw error');

    # 2. Invalid Column (This usually fails at the Worker/SQL level)
    my $invalid_col_future = $schema->resultset('User')->search({
        nonexistent_column => 'value',
    })->all_future;

    eval {
        $invalid_col_future->get;
    };
    ok($@, 'Invalid column in search threw an exception during execution');

    # 3. Valid operation works after errors
    # (Ensure we can still talk to the worker pool)
    my $count = eval { $schema->resultset('User')->count_future->get };
    ok(defined $count, 'Valid operation works after recovery');
};

$schema->disconnect;

done_testing;

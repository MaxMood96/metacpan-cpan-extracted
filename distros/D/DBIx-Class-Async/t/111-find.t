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

$schema->resultset('User')->create({
    id    => 1,
    name  => 'BottomUp User',
    email => 'bu@test.com'
})->get;

subtest 'ResultSet find() - Success' => sub {
    my $rs = $schema->resultset('User');

    # 1. Setup
    my $name = "Finder";
    my $created = $rs->create({ name => $name, email => 'find@test.com' })->get;
    my $id = $created->id;

    # 2. Test find by Primary Key
    my $user = $rs->find($id)->get;

    isa_ok($user, 'DBIx::Class::Async::Row', 'find() returns a Row object');
    is($user->id, $id, 'Found the correct ID');
    is($user->name, $name, 'Data is intact');
};

subtest 'ResultSet find() - No result' => sub {
    my $rs = $schema->resultset('User');

    # Use an ID that definitely doesn't exist
    my $user = $rs->find(999_999_999)->get;

    is($user, undef, 'find() returns undef for non-existent record');
};

subtest 'The Chain: find()->then(delete)' => sub {
    my $rs = $schema->resultset('User');
    my $temp_user = $rs->create({ name => 'To Be Deleted' })->get;
    my $id = $temp_user->id;

    # The exact use case you requested
    my $future = $rs->find($id)->then(sub {
        my $user = shift;

        return Future->done(0) unless $user; # Guard against undef
        return $user->delete;
    });

    my $deleted_count = $future->get;
    is($deleted_count + 0, 1, 'Chain successfully deleted the row');

    # Verify it's gone
    my $gone = $rs->find($id)->get;
    is($gone, undef, 'Confirmed: Record is no longer in DB');
};

subtest 'Testing find_or_new' => sub {
    my $rs = $schema->resultset('User');
    my $initial_queries = $rs->stats('queries');
    my $new_name = "New User " . time;

    # 1. Attempt to find a non-existent user
    my $future = $rs->find_or_new({ name => $new_name });

    my $user;
    $future->on_done(sub { $user = shift; $loop->stop; });
    $loop->run;

    # 2. Verify results
    isa_ok($user, 'DBIx::Class::Async::Row', "Returned a Row object");
    is($user->name, $new_name, "Object has the correct name");
    ok(!$user->in_storage, "Object is NOT in storage (it is 'new')");

    # 3. Verify accounting
    is($rs->stats('queries'), $initial_queries + 1, "Only 1 query dispatched (the find)");
};

subtest 'Testing find_or_create' => sub {
    my $rs = $schema->resultset('User');
    my $initial_queries = $rs->stats('queries');
    my $unique_name = "Created User " . time;

    # 1. Attempt to find_or_create (should create)
    note "First call: Should CREATE";
    my $f1 = $rs->find_or_create({ name => $unique_name });

    my $user1;
    $f1->on_done(sub { $user1 = shift; $loop->stop; });
    $loop->run;

    ok($user1->in_storage, "User 1 is now in storage");
    is($rs->stats('queries'), $initial_queries + 2, "Dispatched 2 queries (1 find + 1 create)");

    # 2. Attempt to find_or_create again (should find)
    my $f2 = $rs->find_or_create({ name => $unique_name });

    my $user2;
    $f2->on_done(sub { $user2 = shift; $loop->stop; });
    $loop->run;

    is($user2->id, $user1->id, "Found the exact same user");
    is($rs->stats('queries'), $initial_queries + 3, "Only 1 additional query dispatched (just the find)");
};

$schema->disconnect;

done_testing;

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
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

subtest 'Row Object Delete' => sub {
    my $rs = $schema->resultset('User');

    my $user = $rs->create({
        name  => 'Suicidal Row',
        email => 'rip@test.com'
    })->get;

    my $user_id = $user->id;
    ok($user_id, "Created user with ID: $user_id");
    is($user->in_storage, 1, 'Object starts in_storage => 1');

    my $rows_affected = $user->delete->get;

    is($rows_affected, 1, 'Row->delete reported 1 row affected');
    is($user->in_storage, 0, 'Object now has in_storage => 0');
};

subtest 'Row Object Delete - Not in Storage' => sub {
    my $new_user = $schema->resultset('User')->new_result({ name => 'Ghost' });

    isa_ok($new_user, 'DBIx::Class::Async::Row', 'new_result created a Row object');
    is($new_user->in_storage, 0, 'New result is not in storage');

    my $res = $new_user->delete->get;
    is($res, 0, 'Deleting a non-stored row returns 0 immediately');
};

subtest 'Chained find()->delete()' => sub {
    my $rs = $schema->resultset('User');
    my $initial_user = $rs->create({ name => 'Chain Test', email => 'chain@test.com' })->get;
    my $target_id    = $initial_user->id;

    # The Chain: find -> then -> delete
    my $chain_future = $rs->find($target_id)->then(sub {
        my $user = shift;
        return Future->fail("User not found") unless $user;

        # Trigger the row-level delete
        return $user->delete;
    });

    my $rows_affected = $chain_future->get;
    is($rows_affected, 1, 'Chain reported 1 row deleted');

    my $exists = $rs->find($target_id)->get;
    is($exists, undef, 'User is officially gone from the database');
};

$schema->disconnect;

done_testing;

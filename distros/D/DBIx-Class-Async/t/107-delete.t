#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
#use Test::Deep;
use File::Temp;
#use Test::Exception;
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

subtest 'ResultSet Delete - Path A (Direct)' => sub {
    # 1. Setup: Create a specific user to kill
    my $name = "Delete Me Direct";
    $schema->resultset('User')->create({ name => $name, email => 'direct@test.com' })->get;

    # 2. Path A: Simple hash condition, no complex attributes
    my $rs = $schema->resultset('User')->search({ name => $name });

    my $future = $rs->delete();
    my $count = $future->get;

    is($count, 1, 'Path A: Deleted exactly 1 row');

    # 3. Verify
    my $exists = $schema->resultset('User')->search({ name => $name })->count_future->get;
    is($exists, 0, 'User no longer exists in DB');
};

subtest 'ResultSet Delete - Path B (Safe Path via all)' => sub {
    # 1. Setup: Create multiple rows
    $schema->resultset('User')->create({ name => "Batch 1", email => 'b1@test.com' })->get;
    $schema->resultset('User')->create({ name => "Batch 2", email => 'b2@test.com' })->get;
    $schema->resultset('User')->create({ name => "Batch 3", email => 'b3@test.com' })->get;

    # 2. Path B: Adding 'rows' or 'offset' forces the safe ID-mapping path
    # We target 2 rows specifically using LIMIT
    my $rs = $schema->resultset('User')->search(
        { name => { -like => 'Batch %' } },
        { rows => 2, order_by => 'id' }
    );

    # This should trigger delete_all() internally
    my $future = $rs->delete();
    my $count = $future->get;

    is($count, 2, 'Path B: Correctly identified and deleted 2 rows via mapping');

    # 3. Verify: Only 1 batch user should remain
    my $remaining = $schema->resultset('User')->search({
        name => { -like => 'Batch %' }
    })->count_future->get;

    is($remaining, 1, 'Exactly one batch user remains');
};

subtest 'ResultSet Delete - Empty Resultset' => sub {
    my $rs = $schema->resultset('User')->search({ id => 999999 });

    my $count = $rs->delete->get;
    is($count, 0, 'Deleting an empty resultset returns 0 and does not crash');
};

$schema->disconnect;

done_testing;

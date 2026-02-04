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

subtest 'Successful Batch' => sub {
    my $batch_f = $schema->txn_batch([
        {
            type      => 'create',
            resultset => 'User',
            data      => { name => 'Alice', email => 'alice@example.com' }
        },
        {
            type      => 'create',
            resultset => 'User',
            data      => { name => 'Bob', email => 'bob@example.com' }
        },
    ]);

    my $inner_batch_f = $loop->await($batch_f);
    my $response      = $inner_batch_f->get;

    is($response->{count}, 2, "Batch reports 2 successful operations");
    my $search_f       = $schema->resultset('User')->search_future({});
    my $inner_search_f = $loop->await($search_f);
    my $users          = $inner_search_f->get;

    is(ref $users, 'ARRAY', "Search results is an ARRAY reference");
    is(scalar @$users, 2, "Both users exist in DB");
};

subtest 'Atomic Rollback on Failure' => sub {
    my $batch_f = $schema->txn_batch([
        {
            type      => 'create',
            resultset => 'User',
            data      => { name => 'Charlie', email => 'charlie@example.com' }
        },
        {
            type      => 'update',
            resultset => 'User',
            id        => 999,
            data      => { name => 'NonExistent' }
        },
    ]);

    my $inner_batch_f = $loop->await($batch_f);
    ok($inner_batch_f->failure, "Batch failed as expected");
    like($inner_batch_f->failure, qr/Record not found/, "Error caught correctly");

    my $search_f       = $schema->resultset('User')->search_future({ name => 'Charlie' });
    my $inner_search_f = $loop->await($search_f);
    my $users          = $inner_search_f->get;

    is(scalar @$users, 0, "Charlie was rolled back and does not exist");
};

$schema->disconnect;

done_testing;

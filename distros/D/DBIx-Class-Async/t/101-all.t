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

my $user = $schema->resultset('User')->create({
    name   => 'Alice',
    email  => 'alice@example.com',
    active => 1,
})->get;


subtest 'Smart all() - Caching and Iterator Validation' => sub {
    my $rs = $schema->resultset('User')->search({ id => 1 });

    # Reset stats for a clean run
    $rs->{_async_db}{_stats}{_queries} = 0;

    # FIRST CALL
    my $future1 = $rs->all;
    my $results1 = $future1->get; # Blocks until worker returns

    is(scalar @$results1, 1, 'First call: Found 1 user');
    is($rs->{_async_db}{_stats}{_queries}, 1, 'Stats: Query count is 1 after first fetch');
    isa_ok($results1->[0], 'DBIx::Class::Async::Row', 'Data is correctly inflated/hijacked');

    # SECOND CALL (Cache Hit)
    my $results2 = $rs->all->get;

    is(scalar @$results2, 1, 'Second call: Still has 1 user');
    is($rs->{_async_db}{_stats}{_queries}, 1, 'Stats: Query count remains 1 (Cache HIT)');
    is($results1->[0], $results2->[0], 'Both calls returned the exact same object instances');

    # ITERATOR INTEGRATION
    # Since all() was called, the buffer is full and pos is 0.
    my $next_row = $rs->next->get;
    ok($next_row, 'next() successfully retrieved row from all() buffer');
    is($next_row->id, 1, 'Iterator data matches cached data');

    # Check that we reached the end
    my $end = $rs->next->get;
    is($end, undef, 'Iterator correctly reached the end of the buffer');
};

$schema->disconnect;

done_testing;

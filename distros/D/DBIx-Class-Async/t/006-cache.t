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
my $schema_class   = 'TestSchema';
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => $schema_class,
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

my $row = {
    name     => 'Alice',
    age      => 20,
    email    => 'alice@example.com',
    active   => 1,
    settings => undef,
    balance  => 10,
};

my $rs = $schema->resultset('User');
$schema->await($rs->create($row));

# First query (should miss cache)
my $results1 = $rs->search({ active => 1 })->all->get;

# Second identical query (should hit cache)
my $results2 = $rs->search({ active => 1 })->all->get;

is(scalar @$results2, scalar @$results1, 'cached results have same count');

cmp_ok($schema->cache_hits,   '>=', 1, 'cache hits recorded');
cmp_ok($schema->cache_misses, '>=', 1, 'cache misses recorded');

# Test with cache disabled
my $schema_no_cache = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    {
        workers      => 2,
        schema_class => $schema_class,
        async_loop   => $loop,
        cache_ttl    => 0,
    });

my $results3 = $schema_no_cache->resultset('User')
                               ->search({ active => 1 })
                               ->all;

my $rows = $schema_no_cache->await($results3);
ok(scalar @$rows, 'search works with cache disabled');

$schema->disconnect;
$schema_no_cache->disconnect;

done_testing;

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

my $alice = $schema->resultset('User')
                   ->create({
                        name  => 'Alice',
                        email => 'alice@example.com', })
                   ->get;

my $john  = $schema->resultset('User')
                   ->create({
                        name  => 'John',
                        email => 'john@example.com', })
                   ->get;

$schema->resultset('User')
       ->search
       ->all
       ->get;

$schema->resultset('User')
       ->count
       ->get;

$schema->resultset('User')
       ->count
       ->get;

is($schema->total_queries, 4, 'total queries');
is($schema->error_count,   0, 'error count');
is($schema->cache_hits,    1, 'cache hits');
is($schema->cache_misses,  2, 'cache misses');
is($schema->cache_retries, 0, 'cache retries');

# Test: Create should invalidate existing count cache
my $pre_create_count = $schema->resultset('User')->count->get; # Should be 2 (from cache)

$schema->resultset('User')->create({
    name => 'Bob',
    email => 'bob@example.com'
})->get;

my $post_create_count = $schema->resultset('User')->count->get;

is($post_create_count, 3, 'Count updated correctly after create (Cache Invalidation)');

# Test: Distinct conditions should have distinct cache entries
my $alice_count = $schema->resultset('User')->search({ name => 'Alice' })->count->get; # Miss
my $john_count  = $schema->resultset('User')->search({ name => 'John' })->count->get;  # Miss

is($alice_count, 1, 'Alice count correct');
is($john_count, 1, 'John count correct');

# Test: Offset/Limit should affect the cache key
$schema->resultset('User')->search({}, { rows => 1, offset => 0 })->count->get; # Miss
$schema->resultset('User')->search({}, { rows => 1, offset => 1 })->count->get; # Miss

$schema->disconnect;

done_testing;

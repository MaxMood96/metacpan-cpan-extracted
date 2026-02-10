#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $loop = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);

my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    {
        workers      => 2,
        schema_class => 'TestSchema',
        async_loop   => $loop,
        cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

# Create test data
my $alice = $schema->await(
    $schema->resultset('User')->create({
        name  => 'Alice',
        email => 'alice@example.com',
    })
);

my $john = $schema->await(
    $schema->resultset('User')->create({
        name  => 'John',
        email => 'john@example.com',
    })
);

# Reset stats after setup
$schema->{_async_db}{_stats} = {
    _queries      => 0,
    _errors       => 0,
    _cache_hits   => 0,
    _cache_misses => 0,
    _retries      => 0,
};

# Test cache behavior with all()
# Query 1: First all() - cache miss
$schema->await($schema->resultset('User')->search->all);

# Query 2: Second all() - cache hit
$schema->await($schema->resultset('User')->search->all);

# Verify all() is using cache
is($schema->{_async_db}{_stats}{_cache_hits}, 1, 'all() uses cache (1 hit)');
is($schema->{_async_db}{_stats}{_cache_misses}, 1, 'all() cache miss on first query');

# Test that count() does NOT use cache
my $stats_before_count = {
    hits   => $schema->{_async_db}{_stats}{_cache_hits},
    misses => $schema->{_async_db}{_stats}{_cache_misses},
};

$schema->await($schema->resultset('User')->count);
$schema->await($schema->resultset('User')->count);

# count() should not affect cache stats
is($schema->{_async_db}{_stats}{_cache_hits}, $stats_before_count->{hits},
   'count() does not use cache (hits unchanged)');
is($schema->{_async_db}{_stats}{_cache_misses}, $stats_before_count->{misses},
   'count() does not register cache misses');

is($schema->{_async_db}{_stats}{_errors}, 0, 'no errors');

# Test: Count is always fresh (no caching)
my $pre_create_count = $schema->await($schema->resultset('User')->count);
is($pre_create_count, 2, 'Count before create');

$schema->await($schema->resultset('User')->create({
    name  => 'Bob',
    email => 'bob@example.com'
}));

my $post_create_count = $schema->await($schema->resultset('User')->count);
is($post_create_count, 3, 'Count after create is accurate (no stale cache)');

# Test: Distinct search conditions have distinct cache entries
my $alice_rows = $schema->await(
    $schema->resultset('User')->search({ name => 'Alice' })->all
);
is(scalar @$alice_rows, 1, 'Alice search correct');

# Second query with same condition - should hit cache
my $alice_rows_cached = $schema->await(
    $schema->resultset('User')->search({ name => 'Alice' })->all
);
is(scalar @$alice_rows_cached, 1, 'Alice search cached');

my $john_rows = $schema->await(
    $schema->resultset('User')->search({ name => 'John' })->all
);
is(scalar @$john_rows, 1, 'John search correct');

# Test: Different conditions have different cache keys
my $cache_hits_before_john2 = $schema->{_async_db}{_stats}{_cache_hits};
my $john_rows2 = $schema->await(
    $schema->resultset('User')->search({ name => 'John' })->all
);
my $cache_hits_after_john2 = $schema->{_async_db}{_stats}{_cache_hits};

is($cache_hits_after_john2, $cache_hits_before_john2 + 1,
   'Repeated search with same condition hits cache');

$schema->disconnect;
done_testing;

__END__

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

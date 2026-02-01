use strict;
use warnings;
use Test::More tests => 7;

use lru;
use const;

# Test storing const values in LRU cache

my $cache = lru::new(10);

# Store a const value
my $pi = const::c(3.14159);
$cache->set('pi', $pi);

is($cache->get('pi'), 3.14159, 'const value stored and retrieved from cache');

# Store a const hash ref
my $config = const::c({ debug => 1, verbose => 0 });
$cache->set('config', $config);

my $retrieved = $cache->get('config');
is_deeply($retrieved, { debug => 1, verbose => 0 }, 'const hashref stored in cache');

# Store multiple const values
const::const(my @primes => (2, 3, 5, 7, 11));
$cache->set('primes', \@primes);

my $cached_primes = $cache->get('primes');
is_deeply($cached_primes, [2, 3, 5, 7, 11], 'const array stored in cache');

# Test cache eviction with const values
my $small_cache = lru::new(3);
$small_cache->set('a', const::c('alpha'));
$small_cache->set('b', const::c('beta'));
$small_cache->set('c', const::c('gamma'));
$small_cache->set('d', const::c('delta'));  # Should evict 'a'

is($small_cache->get('a'), undef, 'const value properly evicted');
is($small_cache->get('d'), 'delta', 'new const value accessible');

# Test with nested const structures
my $nested = const::c({
    name => 'test',
    values => [1, 2, 3],
    meta => { created => 12345 }
});
$cache->set('nested', $nested);

my $got = $cache->get('nested');
is($got->{name}, 'test', 'nested const - name matches');
is_deeply($got->{values}, [1, 2, 3], 'nested const - array matches');

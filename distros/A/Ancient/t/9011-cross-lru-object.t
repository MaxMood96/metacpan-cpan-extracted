use strict;
use warnings;
use Test::More tests => 10;

use lru;
use object;

# Test caching object instances

BEGIN {
    object::define('User', qw(id name email));
}

my $cache = lru::new(100);

# Create and cache an object
my $user1 = new User 1, 'Alice', 'alice@example.com';
$cache->set('user:1', $user1);

my $cached = $cache->get('user:1');
isa_ok($cached, 'User', 'cached object is still a User');
is($cached->id, 1, 'object id preserved');
is($cached->name, 'Alice', 'object name preserved');
is($cached->email, 'alice@example.com', 'object email preserved');

# Cache multiple objects
my $user2 = new User 2, 'Bob', 'bob@example.com';
my $user3 = new User 3, 'Carol', 'carol@example.com';

$cache->set('user:2', $user2);
$cache->set('user:3', $user3);

is($cache->size, 3, 'cache has 3 objects');

# Modify cached object (objects are mutable)
$cached->name('Alice Smith');
my $refetched = $cache->get('user:1');
is($refetched->name, 'Alice Smith', 'object modification persists in cache');

# Test eviction with objects
my $small_cache = lru::new(2);
$small_cache->set('u1', new User 10, 'User10', 'u10@test.com');
$small_cache->set('u2', new User 20, 'User20', 'u20@test.com');
$small_cache->set('u3', new User 30, 'User30', 'u30@test.com');  # Evicts u1

is($small_cache->get('u1'), undef, 'old object evicted');
is($small_cache->get('u3')->name, 'User30', 'new object accessible');

# Test peek doesn't break object
my $peeked = $small_cache->peek('u2');
isa_ok($peeked, 'User', 'peeked object is User');
is($peeked->id, 20, 'peeked object data correct');

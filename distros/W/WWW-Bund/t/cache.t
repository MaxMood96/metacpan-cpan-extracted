use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(remove_tree);

use WWW::Bund::Cache;

my $tmpdir = tempdir(CLEANUP => 1);

# Basic set/get
{
    my $cache = WWW::Bund::Cache->new(cache_dir => $tmpdir, ttl => 3600);
    $cache->set('key1', 'value1');
    is($cache->get('key1'), 'value1', 'basic set/get');
}

# Cache miss
{
    my $cache = WWW::Bund::Cache->new(cache_dir => $tmpdir);
    is($cache->get('nonexistent'), undef, 'cache miss returns undef');
}

# Default TTL expiry (simulate with low TTL)
{
    my $dir = tempdir(CLEANUP => 1);
    my $cache = WWW::Bund::Cache->new(cache_dir => $dir, ttl => 1);
    $cache->set('expire_test', 'data');
    is($cache->get('expire_test'), 'data', 'fresh entry is valid');
    sleep 2;
    is($cache->get('expire_test'), undef, 'expired entry returns undef');
}

# Per-key TTL override: short override expires before default
{
    my $dir = tempdir(CLEANUP => 1);
    my $cache = WWW::Bund::Cache->new(cache_dir => $dir, ttl => 3600);
    $cache->set('short_ttl', 'data');
    is($cache->get('short_ttl', 3600), 'data', 'per-key TTL: valid with long TTL');
    is($cache->get('short_ttl', 1), 'data', 'per-key TTL: fresh entry valid even with 1s TTL');
    sleep 2;
    is($cache->get('short_ttl', 1), undef, 'per-key TTL: expired with short override');
    # But default TTL would still consider it valid:
    $cache->set('long_default', 'data2');
    sleep 2;
    is($cache->get('long_default'), 'data2', 'default TTL still valid after 2s');
}

# Per-key TTL with undef falls back to default
{
    my $dir = tempdir(CLEANUP => 1);
    my $cache = WWW::Bund::Cache->new(cache_dir => $dir, ttl => 3600);
    $cache->set('fallback', 'data');
    is($cache->get('fallback', undef), 'data', 'undef per-key TTL falls back to default');
}

# Clear
{
    my $dir = tempdir(CLEANUP => 1);
    my $cache = WWW::Bund::Cache->new(cache_dir => $dir);
    $cache->set('a', '1');
    $cache->set('b', '2');
    $cache->clear;
    is($cache->get('a'), undef, 'clear removes all entries');
    is($cache->get('b'), undef, 'clear removes all entries (b)');
}

# Binary data
{
    my $dir = tempdir(CLEANUP => 1);
    my $cache = WWW::Bund::Cache->new(cache_dir => $dir);
    my $binary = join('', map { chr($_) } 0..255);
    $cache->set('binary', $binary);
    is($cache->get('binary'), $binary, 'binary data round-trips');
}

# --- XDG cache path ---
{
    local $ENV{XDG_CACHE_HOME} = tempdir(CLEANUP => 1);
    local $ENV{HOME} = '/should/not/be/used';

    require WWW::Bund;
    my $client = WWW::Bund->new;
    is($client->cache_dir,
       File::Spec->catdir($ENV{XDG_CACHE_HOME}, 'www-bund'),
       'cache_dir respects XDG_CACHE_HOME');
}

# XDG fallback to HOME/.cache
{
    local $ENV{XDG_CACHE_HOME};
    delete $ENV{XDG_CACHE_HOME};
    my $fake_home = tempdir(CLEANUP => 1);
    local $ENV{HOME} = $fake_home;

    require WWW::Bund;
    my $client = WWW::Bund->new;
    is($client->cache_dir,
       File::Spec->catdir($fake_home, '.cache', 'www-bund'),
       'cache_dir falls back to $HOME/.cache/www-bund');
}

done_testing;

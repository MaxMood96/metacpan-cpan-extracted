#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Test lru module functions work correctly in map/grep context
# This ensures call checkers properly handle $_ usage

use lru qw(import);

# ============================================
# Function-style calls with $_ - these test the call checker $_ detection
# ============================================
subtest 'lru_get function-style with $_ in map' => sub {
    my $cache = lru->new(10);
    $cache->set("a", 100);
    $cache->set("b", 200);
    $cache->set("c", 300);
    
    my @keys = ("a", "b", "c");
    # Using lru_get($cache, $_) - this is the pattern that triggers call checker
    my @values = map { lru_get($cache, $_) } @keys;
    is_deeply(\@values, [100, 200, 300], 'lru_get function with $_ in map returns all values');
};

subtest 'lru_exists function-style with $_ in grep' => sub {
    my $cache = lru->new(10);
    $cache->set("x", 1);
    $cache->set("y", 2);
    
    my @keys = ("x", "y", "z", "w");
    my @existing = grep { lru_exists($cache, $_) } @keys;
    is_deeply(\@existing, ["x", "y"], 'lru_exists function with $_ in grep finds correct keys');
};

# ============================================
# lru->get in map (method style)
# ============================================
subtest 'lru->get in map' => sub {
    my $cache = lru->new(10);
    $cache->set("a", 100);
    $cache->set("b", 200);
    $cache->set("c", 300);
    
    my @keys = ("a", "b", "c");
    my @values = map { $cache->get($_) } @keys;
    is_deeply(\@values, [100, 200, 300], 'get returns correct values in map');
};

# ============================================
# lru->exists in grep
# ============================================
subtest 'lru->exists in grep' => sub {
    my $cache = lru->new(10);
    $cache->set("x", 1);
    $cache->set("y", 2);
    
    my @keys = ("x", "y", "z", "w");
    my @existing = grep { $cache->exists($_) } @keys;
    is_deeply(\@existing, ["x", "y"], 'exists finds correct keys in grep');
};

# ============================================
# lru->get with undef values in map
# ============================================
subtest 'lru->get with missing keys in map' => sub {
    my $cache = lru->new(10);
    $cache->set("present", 42);
    
    my @keys = ("present", "missing", "also_missing");
    my @values = map { $cache->get($_) // "UNDEF" } @keys;
    is_deeply(\@values, [42, "UNDEF", "UNDEF"], 'get handles missing keys in map');
};

# ============================================
# Multiple caches in map
# ============================================
subtest 'multiple caches in map' => sub {
    my $c1 = lru->new(5);
    my $c2 = lru->new(5);
    my $c3 = lru->new(5);
    
    $c1->set("key", 1);
    $c2->set("key", 2);
    $c3->set("key", 3);
    
    my @caches = ($c1, $c2, $c3);
    my @values = map { $_->get("key") } @caches;
    is_deeply(\@values, [1, 2, 3], 'get from multiple caches in map works');
};

# ============================================
# lru->delete in map
# ============================================
subtest 'lru->delete in map' => sub {
    my $cache = lru->new(10);
    $cache->set("a", 1);
    $cache->set("b", 2);
    $cache->set("c", 3);
    
    my @to_delete = ("a", "c");
    my @deleted = map { $cache->delete($_) } @to_delete;
    is_deeply(\@deleted, [1, 3], 'delete returns correct values in map');
    
    ok(!$cache->exists("a"), 'a was deleted');
    ok($cache->exists("b"), 'b still exists');
    ok(!$cache->exists("c"), 'c was deleted');
};

# ============================================
# Nested map with lru
# ============================================
subtest 'nested map with lru' => sub {
    my $cache = lru->new(10);
    $cache->set("k1", 10);
    $cache->set("k2", 20);
    
    my @key_groups = (["k1", "k2"], ["k2", "k1"]);
    my @results = map {
        my $group = $_;
        [ map { $cache->get($_) } @$group ]
    } @key_groups;
    
    is_deeply($results[0], [10, 20], 'first group correct');
    is_deeply($results[1], [20, 10], 'second group correct');
};

# ============================================
# for/foreach loops with lru
# ============================================
subtest 'lru->get in foreach loop' => sub {
    my $cache = lru->new(10);
    $cache->set("a", 100);
    $cache->set("b", 200);
    $cache->set("c", 300);
    
    my @keys = ("a", "b", "c");
    my @values;
    for (@keys) {
        push @values, $cache->get($_);
    }
    is_deeply(\@values, [100, 200, 300], 'get in foreach with $_ works');
};

subtest 'lru_get function in for loop' => sub {
    my $cache = lru->new(10);
    $cache->set("x", 10);
    $cache->set("y", 20);
    $cache->set("z", 30);
    
    my @keys = ("x", "y", "z");
    my @values;
    for (@keys) {
        push @values, lru_get($cache, $_);
    }
    is_deeply(\@values, [10, 20, 30], 'lru_get function in for loop with $_ works');
};

subtest 'lru->exists in for loop' => sub {
    my $cache = lru->new(10);
    $cache->set("present1", 1);
    $cache->set("present2", 2);
    
    my @keys = ("present1", "missing", "present2");
    my $count = 0;
    for (@keys) {
        $count++ if $cache->exists($_);
    }
    is($count, 2, 'exists counts correctly in for loop with $_');
};

subtest 'nested for with lru' => sub {
    my $cache = lru->new(10);
    $cache->set("k1", 10);
    $cache->set("k2", 20);
    
    my @key_groups = (["k1", "k2"], ["k2", "k1"]);
    my @results;
    for my $group (@key_groups) {
        my @vals;
        for (@$group) {
            push @vals, $cache->get($_);
        }
        push @results, \@vals;
    }
    
    is_deeply($results[0], [10, 20], 'nested for first group correct');
    is_deeply($results[1], [20, 10], 'nested for second group correct');
};

# ============================================
# Explicit lexical loop variable (for my $key)
# ============================================
subtest 'for my $key with lru->get' => sub {
    my $cache = lru->new(10);
    $cache->set("a", 100);
    $cache->set("b", 200);
    $cache->set("c", 300);
    
    my @keys = ("a", "b", "c");
    my @values;
    for my $key (@keys) {
        push @values, $cache->get($key);
    }
    is_deeply(\@values, [100, 200, 300], 'get works with explicit $key');
};

subtest 'for my $k with lru_get function' => sub {
    my $cache = lru->new(10);
    $cache->set("x", 10);
    $cache->set("y", 20);
    $cache->set("z", 30);
    
    my @keys = ("x", "y", "z");
    my @values;
    for my $k (@keys) {
        push @values, lru_get($cache, $k);
    }
    is_deeply(\@values, [10, 20, 30], 'lru_get function works with explicit $k');
};

subtest 'for my $key with lru->exists' => sub {
    my $cache = lru->new(10);
    $cache->set("present1", 1);
    $cache->set("present2", 2);
    
    my @keys = ("present1", "missing", "present2");
    my $count = 0;
    for my $key (@keys) {
        $count++ if $cache->exists($key);
    }
    is($count, 2, 'exists works with explicit $key');
};

subtest 'nested for my with lru' => sub {
    my $cache = lru->new(10);
    $cache->set("k1", 10);
    $cache->set("k2", 20);
    
    my @key_groups = (["k1", "k2"], ["k2", "k1"]);
    my @results;
    for my $group (@key_groups) {
        my @vals;
        for my $key (@$group) {
            push @vals, $cache->get($key);
        }
        push @results, \@vals;
    }
    
    is_deeply($results[0], [10, 20], 'nested for my first group correct');
    is_deeply($results[1], [20, 10], 'nested for my second group correct');
};

done_testing();

#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(
    noop stub_true stub_false stub_array stub_hash stub_string stub_zero
));

# ============================================
# noop tests
# ============================================

is(noop(), undef, 'noop: returns undef');
is(noop(1, 2, 3), undef, 'noop: ignores arguments, returns undef');
is(noop("hello", { foo => 1 }), undef, 'noop: ignores any arguments');

# noop as default callback
my @results = map { noop($_) } (1, 2, 3);
is_deeply(\@results, [undef, undef, undef], 'noop: works in map');

# ============================================
# stub_true tests
# ============================================

ok(stub_true(), 'stub_true: returns true');
ok(stub_true(0), 'stub_true: ignores falsy arg, returns true');
ok(stub_true(undef), 'stub_true: ignores undef, returns true');
is(stub_true(), 1, 'stub_true: returns 1');

# stub_true as filter
my @nums = (1, 2, 3, 4, 5);
my @filtered = grep { stub_true() } @nums;
is_deeply(\@filtered, \@nums, 'stub_true: accepts all in grep');

# ============================================
# stub_false tests
# ============================================

ok(!stub_false(), 'stub_false: returns false');
ok(!stub_false(1), 'stub_false: ignores truthy arg, returns false');
ok(!stub_false("hello"), 'stub_false: ignores string, returns false');

# stub_false as filter
@filtered = grep { stub_false() } @nums;
is_deeply(\@filtered, [], 'stub_false: rejects all in grep');

# ============================================
# stub_array tests
# ============================================

my $arr = stub_array();
ok(ref($arr) eq 'ARRAY', 'stub_array: returns arrayref');
is_deeply($arr, [], 'stub_array: returns empty array');

# Each call returns a new array
my $arr2 = stub_array();
isnt($arr, $arr2, 'stub_array: returns new array each time');
push @$arr, 1;
is_deeply($arr2, [], 'stub_array: arrays are independent');

# ============================================
# stub_hash tests
# ============================================

my $hash = stub_hash();
ok(ref($hash) eq 'HASH', 'stub_hash: returns hashref');
is_deeply($hash, {}, 'stub_hash: returns empty hash');

# Each call returns a new hash
my $hash2 = stub_hash();
isnt($hash, $hash2, 'stub_hash: returns new hash each time');
$hash->{foo} = 1;
is_deeply($hash2, {}, 'stub_hash: hashes are independent');

# ============================================
# stub_string tests
# ============================================

is(stub_string(), '', 'stub_string: returns empty string');
is(length(stub_string()), 0, 'stub_string: has zero length');
ok(defined(stub_string()), 'stub_string: is defined (not undef)');

# ============================================
# stub_zero tests
# ============================================

is(stub_zero(), 0, 'stub_zero: returns 0');
ok(defined(stub_zero()), 'stub_zero: is defined');
ok(!stub_zero(), 'stub_zero: is falsy');
cmp_ok(stub_zero(), '==', 0, 'stub_zero: numerically equals 0');

# ============================================
# Practical use cases
# ============================================

# Default callback
sub process_items {
    my ($items, $on_each) = @_;
    $on_each //= \&noop;  # Default to noop
    my @results;
    for my $item (@$items) {
        $on_each->($item);
        push @results, $item;
    }
    return @results;
}

my @processed = process_items([1, 2, 3]);
is_deeply(\@processed, [1, 2, 3], 'practical: noop as default callback');

# Accept-all filter
sub filter_items {
    my ($items, $predicate) = @_;
    $predicate //= \&stub_true;  # Default to accept all
    return grep { $predicate->($_) } @$items;
}

@filtered = filter_items([1, 2, 3, 4, 5]);
is_deeply(\@filtered, [1, 2, 3, 4, 5], 'practical: stub_true as default filter');

# Factory functions
sub make_collection {
    my ($type) = @_;
    my $factory = $type eq 'array' ? \&stub_array : \&stub_hash;
    return $factory->();
}

my $coll = make_collection('array');
ok(ref($coll) eq 'ARRAY', 'practical: stub_array as factory');

$coll = make_collection('hash');
ok(ref($coll) eq 'HASH', 'practical: stub_hash as factory');

done_testing;

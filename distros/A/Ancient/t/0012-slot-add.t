#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use slot;

# Test slot::add
slot::add('test_add');
is(slot::get('test_add'), undef, 'newly added slot is undef');

slot::set('test_add', 42);
is(slot::get('test_add'), 42, 'can set and get slot created with add');

# Test slot::index
my $idx = slot::index('test_add');
ok(defined $idx, 'slot::index returns defined value');
is($idx, 0, 'first slot has index 0');

# Test slot::get_by_idx / slot::set_by_idx
is(slot::get_by_idx($idx), 42, 'get_by_idx returns correct value');

slot::set_by_idx($idx, 100);
is(slot::get_by_idx($idx), 100, 'set_by_idx updates value');
is(slot::get('test_add'), 100, 'set_by_idx reflects in name-based get');

# Test multiple slots
slot::add('test_add2', 'test_add3');
my $idx2 = slot::index('test_add2');
my $idx3 = slot::index('test_add3');
ok($idx2 > $idx, 'second slot has higher index');
ok($idx3 > $idx2, 'third slot has higher index');

# Test bounds checking
is(slot::get_by_idx(-1), undef, 'get_by_idx with negative index returns undef');
is(slot::get_by_idx(9999), undef, 'get_by_idx with out of bounds index returns undef');

# Test slot::add is idempotent
my $count_before = scalar(slot::slots());
slot::add('test_add');  # Already exists
my $count_after = scalar(slot::slots());
is($count_after, $count_before, 'slot::add does not duplicate existing slots');

done_testing;

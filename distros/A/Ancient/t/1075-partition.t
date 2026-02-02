#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(partition);

# ============================================
# partition tests
# ============================================

# Basic partition
my @nums = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
my $result = partition(sub { $_ % 2 == 0 }, @nums);
is_deeply($result->[0], [2, 4, 6, 8, 10], 'partition: even numbers (pass)');
is_deeply($result->[1], [1, 3, 5, 7, 9], 'partition: odd numbers (fail)');

# All pass
my $all_pass = partition(sub { $_ > 0 }, @nums);
is_deeply($all_pass->[0], [1..10], 'partition: all pass');
is_deeply($all_pass->[1], [], 'partition: none fail');

# None pass
my $none_pass = partition(sub { $_ > 100 }, @nums);
is_deeply($none_pass->[0], [], 'partition: none pass');
is_deeply($none_pass->[1], [1..10], 'partition: all fail');

# Empty list
my $empty = partition(sub { 1 }, ());
is_deeply($empty->[0], [], 'partition: empty list - pass');
is_deeply($empty->[1], [], 'partition: empty list - fail');

# Single element pass
my $single_pass = partition(sub { 1 }, 42);
is_deeply($single_pass->[0], [42], 'partition: single element pass');
is_deeply($single_pass->[1], [], 'partition: single element - fail empty');

# Single element fail
my $single_fail = partition(sub { 0 }, 42);
is_deeply($single_fail->[0], [], 'partition: single element - pass empty');
is_deeply($single_fail->[1], [42], 'partition: single element fail');

# Uses $_ correctly
my $uses_default = partition(sub { $_ > 5 }, @nums);
is_deeply($uses_default->[0], [6, 7, 8, 9, 10], 'partition: uses $_ correctly');

# Uses $_[0] correctly
my $uses_arg = partition(sub { $_[0] > 5 }, @nums);
is_deeply($uses_arg->[0], [6, 7, 8, 9, 10], 'partition: uses $_[0] correctly');

# With strings
my @words = qw(apple banana apricot cherry avocado);
my $starts_a = partition(sub { /^a/ }, @words);
is_deeply($starts_a->[0], [qw(apple apricot avocado)], 'partition: strings starting with a');
is_deeply($starts_a->[1], [qw(banana cherry)], 'partition: strings not starting with a');

# With hashrefs
my @users = (
    { name => 'Alice', age => 25 },
    { name => 'Bob', age => 17 },
    { name => 'Carol', age => 30 },
    { name => 'Dave', age => 15 },
);
my $adults = partition(sub { $_->{age} >= 18 }, @users);
is(scalar @{$adults->[0]}, 2, 'partition: 2 adults');
is(scalar @{$adults->[1]}, 2, 'partition: 2 minors');
is($adults->[0][0]{name}, 'Alice', 'partition: first adult is Alice');
is($adults->[1][0]{name}, 'Bob', 'partition: first minor is Bob');

# Preserves order
my @ordered = (5, 2, 8, 1, 9, 3);
my $gt5 = partition(sub { $_ > 5 }, @ordered);
is_deeply($gt5->[0], [8, 9], 'partition: preserves order in pass');
is_deeply($gt5->[1], [5, 2, 1, 3], 'partition: preserves order in fail');

done_testing;

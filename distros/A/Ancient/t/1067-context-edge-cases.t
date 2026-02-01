#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use util;

# Test edge cases and boundary conditions for custom ops in context

# ============================================
# Undef handling
# ============================================
subtest 'undef in map/grep' => sub {
    my @with_undefs = (1, undef, 3, undef, 5);
    
    # is_defined should work correctly
    my @defined = grep { util::is_defined($_) } @with_undefs;
    is_deeply(\@defined, [1, 3, 5], 'grep filters undefs');
    
    # Map over undefs
    my @mapped = map { util::is_defined($_) ? $_ * 2 : 0 } @with_undefs;
    is_deeply(\@mapped, [2, 0, 6, 0, 10], 'map handles undefs');
};

# ============================================
# Empty string handling
# ============================================
subtest 'empty string handling' => sub {
    my @strings = ('hello', '', 'world', '');
    
    my @non_empty = grep { util::is_defined($_) && length($_) > 0 } @strings;
    is_deeply(\@non_empty, ['hello', 'world'], 'grep filters empty strings');
    
    my @trimmed = map { util::trim($_) } ('  a  ', '', '  b  ');
    is_deeply(\@trimmed, ['a', '', 'b'], 'trim handles empty string');
};

# ============================================
# Zero handling
# ============================================
subtest 'zero value handling' => sub {
    my @nums = (0, 1, 0, 2, 0);
    
    # is_zero should work
    my @zeros = grep { util::is_zero($_) } @nums;
    is(scalar(@zeros), 3, 'grep finds 3 zeros');
    
    # clamp with zero
    my @clamped = map { util::clamp($_, 0, 10) } (-5, 0, 5, 15);
    is_deeply(\@clamped, [0, 0, 5, 10], 'clamp handles zero correctly');
};

# ============================================
# Negative number handling
# ============================================
subtest 'negative number handling' => sub {
    my @nums = (-10, -5, 0, 5, 10);
    
    my @positive = grep { util::is_positive($_) } @nums;
    is_deeply(\@positive, [5, 10], 'grep finds positive numbers');
    
    my @negative = grep { util::is_negative($_) } @nums;
    is_deeply(\@negative, [-10, -5], 'grep finds negative numbers');
    
    my @clamped = map { util::clamp($_, -3, 3) } @nums;
    is_deeply(\@clamped, [-3, -3, 0, 3, 3], 'clamp with negative bounds');
};

# ============================================
# Large list handling
# ============================================
subtest 'large list handling' => sub {
    my @large = (1..1000);
    
    my @clamped = map { util::clamp($_, 100, 900) } @large;
    is($clamped[0], 100, 'first element clamped to min');
    is($clamped[500], 501, 'middle element unchanged');
    is($clamped[999], 900, 'last element clamped to max');
    is(scalar(@clamped), 1000, 'all 1000 elements processed');
    
    my @even = grep { util::is_even($_) } @large;
    is(scalar(@even), 500, 'grep finds 500 even numbers in 1000');
};

# ============================================
# Floating point handling
# ============================================
subtest 'floating point handling' => sub {
    my @floats = (1.5, 2.7, 3.14159, 0.0, -1.5);
    
    my @clamped = map { util::clamp($_, 0.5, 3.0) } @floats;
    is($clamped[0], 1.5, 'float in range');
    is($clamped[1], 2.7, 'float in range');
    is($clamped[2], 3.0, 'float clamped to max');
    is($clamped[3], 0.5, 'float clamped to min');
    is($clamped[4], 0.5, 'negative float clamped to min');
};

# ============================================
# Reference types in map/grep
# ============================================
subtest 'reference types' => sub {
    my @refs = ([1,2], {a=>1}, sub{1}, \my $s, qr/foo/);
    my @non_refs = (1, 'string', undef);
    my @mixed = (@refs, @non_refs);
    
    my @found_refs = grep { util::is_ref($_) } @mixed;
    is(scalar(@found_refs), 5, 'grep finds 5 refs');
    
    my @arrays = grep { util::is_array($_) } @mixed;
    is(scalar(@arrays), 1, 'grep finds 1 array');
    
    my @hashes = grep { util::is_hash($_) } @mixed;
    is(scalar(@hashes), 1, 'grep finds 1 hash');
    
    my @codes = grep { util::is_code($_) } @mixed;
    is(scalar(@codes), 1, 'grep finds 1 code');
};

# ============================================
# Deeply nested data
# ============================================
subtest 'deeply nested data' => sub {
    my @deep = (
        { data => [1, 2, 3] },
        { data => [4, 5] },
        { data => [6, 7, 8, 9] },
    );
    
    my @all_nums;
    for my $item (@deep) {
        for (@{$item->{data}}) {
            push @all_nums, util::clamp($_, 3, 7);
        }
    }
    is_deeply(\@all_nums, [3, 3, 3, 4, 5, 6, 7, 7, 7], 'nested hash/array with clamp');
};

# ============================================
# Boolean edge cases
# ============================================
subtest 'boolean edge cases' => sub {
    my @vals = (0, '', undef, 1, 'a', [], {});
    
    # Defined values
    my @defined = grep { util::is_defined($_) } @vals;
    is(scalar(@defined), 6, '6 defined values (including 0 and empty string)');
    
    # References (arrays and hashes are refs even if empty)
    my @refs = grep { util::is_ref($_) } @vals;
    is(scalar(@refs), 2, '2 refs (empty array and hash)');
};

# ============================================
# String edge cases
# ============================================
subtest 'string edge cases' => sub {
    my @strings = (
        '   ',           # whitespace only
        "\t\n",          # tabs and newlines
        '  hello  ',     # surrounded by spaces
        'world',         # no spaces
        '',              # empty
    );
    
    my @trimmed = map { util::trim($_) } @strings;
    is_deeply(\@trimmed, ['', '', 'hello', 'world', ''], 'trim handles edge cases');
};

# ============================================
# Numeric string handling
# ============================================
subtest 'numeric strings' => sub {
    my @numeric_strings = ('42', '3.14', '-10', '0', '1e5');
    
    my @clamped = map { util::clamp($_, 0, 100) } @numeric_strings;
    is($clamped[0], 42, 'numeric string 42');
    is($clamped[1], 3.14, 'numeric string 3.14');
    is($clamped[2], 0, 'negative clamped to 0');
    is($clamped[3], 0, 'zero stays zero');
    is($clamped[4], 100, '1e5 clamped to 100');
};

# ============================================
# Very large numbers
# ============================================
subtest 'very large numbers' => sub {
    my @large = (1e10, 1e15, 1e20);
    
    my @clamped = map { util::clamp($_, 0, 1e12) } @large;
    is($clamped[0], 1e10, '1e10 in range');
    is($clamped[1], 1e12, '1e15 clamped to max');
    is($clamped[2], 1e12, '1e20 clamped to max');
};

# ============================================
# Very small numbers
# ============================================
subtest 'very small numbers' => sub {
    my @small = (1e-10, 1e-5, 0.001);
    
    my @clamped = map { util::clamp($_, 1e-8, 1e-3) } @small;
    is($clamped[0], 1e-8, '1e-10 clamped to min');
    is($clamped[1], 1e-5, '1e-5 in range');
    is($clamped[2], 1e-3, '0.001 equals max');
};

# ============================================
# ltrim/rtrim in map/grep
# ============================================
subtest 'ltrim in map' => sub {
    my @strings = ('  hello', '  world  ', 'foo  ', '   bar   ');
    my @result = map { util::ltrim($_) } @strings;
    is_deeply(\@result, ['hello', 'world  ', 'foo  ', 'bar   '], 'ltrim in map');
};

subtest 'rtrim in map' => sub {
    my @strings = ('hello  ', '  world  ', '  foo', '   bar   ');
    my @result = map { util::rtrim($_) } @strings;
    is_deeply(\@result, ['hello', '  world', '  foo', '   bar'], 'rtrim in map');
};

subtest 'ltrim in grep' => sub {
    my @strings = ('  a', 'b', '  c', 'd');
    my @with_leading = grep { $_ ne util::ltrim($_) } @strings;
    is_deeply(\@with_leading, ['  a', '  c'], 'ltrim in grep detects leading spaces');
};

subtest 'rtrim in grep' => sub {
    my @strings = ('a  ', 'b', 'c  ', 'd');
    my @with_trailing = grep { $_ ne util::rtrim($_) } @strings;
    is_deeply(\@with_trailing, ['a  ', 'c  '], 'rtrim in grep detects trailing spaces');
};

# ============================================
# sign in map/grep
# ============================================
subtest 'sign in map' => sub {
    my @nums = (-100, -1, 0, 1, 100);
    my @signs = map { util::sign($_) } @nums;
    is_deeply(\@signs, [-1, -1, 0, 1, 1], 'sign in map');
};

subtest 'sign in grep' => sub {
    my @nums = (-5, -3, 0, 2, 4);
    my @positive = grep { util::sign($_) > 0 } @nums;
    is_deeply(\@positive, [2, 4], 'sign in grep finds positive');
    
    my @negative = grep { util::sign($_) < 0 } @nums;
    is_deeply(\@negative, [-5, -3], 'sign in grep finds negative');
};

# ============================================
# min/max in map
# ============================================
subtest 'min2 in map' => sub {
    my @pairs = ([1, 5], [10, 3], [7, 7], [-1, 0]);
    my @mins = map { util::min2($_->[0], $_->[1]) } @pairs;
    is_deeply(\@mins, [1, 3, 7, -1], 'min2 in map');
};

subtest 'max2 in map' => sub {
    my @pairs = ([1, 5], [10, 3], [7, 7], [-1, 0]);
    my @maxs = map { util::max2($_->[0], $_->[1]) } @pairs;
    is_deeply(\@maxs, [5, 10, 7, 0], 'max2 in map');
};

subtest 'min2/max2 with $_ in map' => sub {
    my @nums = (5, 10, 15, 20);
    my @capped = map { util::min2($_, 12) } @nums;
    is_deeply(\@capped, [5, 10, 12, 12], 'min2 caps values in map');
    
    my @floored = map { util::max2($_, 8) } @nums;
    is_deeply(\@floored, [8, 10, 15, 20], 'max2 floors values in map');
};

# ============================================
# nvl in map/grep
# ============================================
subtest 'nvl in map' => sub {
    my @vals = (1, undef, 3, undef, 5);
    my @filled = map { util::nvl($_, 0) } @vals;
    is_deeply(\@filled, [1, 0, 3, 0, 5], 'nvl replaces undef in map');
};

subtest 'nvl in grep' => sub {
    my @vals = (undef, 0, '', undef, 1);
    # nvl returns default only for undef, not for 0 or ''
    # 0, '' and 1 are defined so nvl returns them; undef returns default
    # So we get: 'default', 0, '', 'default', 1 - 3 truthy values (default x2, 1)
    my @truthy = grep { util::nvl($_, 'default') } @vals;
    is(scalar(@truthy), 3, 'nvl in grep - undef gets default, others pass through');
};

subtest 'nvl chained' => sub {
    my @nested = ([1], [undef], [3]);
    my @result = map { util::nvl($_->[0], -1) } @nested;
    is_deeply(\@result, [1, -1, 3], 'nvl with nested access in map');
};

# ============================================
# maybe in map/grep - maybe($value, $then) returns $then if defined, else undef
# ============================================
subtest 'maybe in map' => sub {
    my @vals = (1, undef, 3, undef, 5);
    # maybe returns the callback if defined, undef otherwise
    # We need to call the callback if it's returned
    my @result = map { 
        my $cb = util::maybe($_, sub { $_[0] * 2 }); 
        defined $cb ? $cb->($_) : 'NONE'
    } @vals;
    is_deeply(\@result, [2, 'NONE', 6, 'NONE', 10], 'maybe in map returns callback when defined');
};

subtest 'maybe in grep' => sub {
    my @vals = (1, undef, 2, undef, 3);
    my @defined = grep { defined util::maybe($_, sub { 1 }) } @vals;
    is_deeply(\@defined, [1, 2, 3], 'maybe in grep filters undef');
};

# ============================================
# noop in map/grep
# ============================================
subtest 'noop in map' => sub {
    my @vals = (1, 2, 3);
    my @result = map { util::noop(); $_ * 2 } @vals;
    is_deeply(\@result, [2, 4, 6], 'noop does nothing, rest of block works');
};

subtest 'noop returns undef' => sub {
    my @vals = (1, 2, 3);
    my @result = map { util::noop() } @vals;
    is_deeply(\@result, [undef, undef, undef], 'noop returns undef in map');
};

# ============================================
# always in map/grep
# ============================================
subtest 'always in map' => sub {
    my $const = util::always(42);
    my @vals = (1, 2, 3, 4, 5);
    my @result = map { $const->() } @vals;
    is_deeply(\@result, [42, 42, 42, 42, 42], 'always returns constant in map');
};

subtest 'always with different values' => sub {
    my @constants = map { util::always($_) } (10, 20, 30);
    my @result = map { $_->() } @constants;
    is_deeply(\@result, [10, 20, 30], 'always captures different values');
};

subtest 'always in grep' => sub {
    my $true_fn = util::always(1);
    my $false_fn = util::always(0);
    
    my @vals = (1, 2, 3);
    my @all = grep { $true_fn->() } @vals;
    is_deeply(\@all, [1, 2, 3], 'always(1) keeps all in grep');
    
    my @none = grep { $false_fn->() } @vals;
    is_deeply(\@none, [], 'always(0) keeps none in grep');
};

# ============================================
# while loop with lexical variable
# ============================================
subtest 'while loop with lexical $val' => sub {
    my @data = (1, 5, 10, -3, 100);
    my @result;
    my $idx = 0;
    while ($idx < @data) {
        my $val = $data[$idx];
        push @result, util::clamp($val, 2, 50);
        $idx++;
    }
    is_deeply(\@result, [2, 5, 10, 2, 50], 'clamp works in while with lexical $val');
};

subtest 'while with lexical and is_positive' => sub {
    my @nums = (-3, -1, 0, 1, 5);
    my @positive;
    my $i = 0;
    while ($i < @nums) {
        my $n = $nums[$i];
        push @positive, $n if util::is_positive($n);
        $i++;
    }
    is_deeply(\@positive, [1, 5], 'is_positive in while with lexical $n');
};

subtest 'while with lexical and trim' => sub {
    my @strings = ('  a  ', '  b  ', '  c  ');
    my @trimmed;
    my $j = 0;
    while ($j < @strings) {
        my $s = $strings[$j];
        push @trimmed, util::trim($s);
        $j++;
    }
    is_deeply(\@trimmed, ['a', 'b', 'c'], 'trim in while with lexical $s');
};

done_testing();

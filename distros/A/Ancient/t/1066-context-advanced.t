#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use util;

# Advanced context tests for custom ops
# Tests edge cases beyond basic map/grep/for

# ============================================
# While loop with $_
# ============================================
subtest 'while loop with $_' => sub {
    my @data = (1, 5, 10, -3, 100);
    my @result;
    my $i = 0;
    while ($i < @data) {
        local $_ = $data[$i];
        push @result, util::clamp($_, 2, 50);
        $i++;
    }
    is_deeply(\@result, [2, 5, 10, 2, 50], 'clamp works in while with local $_');
};

# ============================================
# Chained map/grep
# ============================================
subtest 'chained map grep' => sub {
    my @nums = (0, 5, 10, -3, 100, undef, 50);
    my @result = map { util::clamp($_, 10, 80) } 
                 grep { util::is_defined($_) } @nums;
    is_deeply(\@result, [10, 10, 10, 10, 80, 50], 'chained grep->map with $_');
};

subtest 'chained grep map' => sub {
    my @mixed = (1, 'two', [1,2,3], {a=>1}, undef);
    my @result = grep { util::is_defined($_) }
                 map { util::is_ref($_) ? $_ : undef } @mixed;
    is_deeply(\@result, [[1,2,3], {a=>1}], 'chained map->grep with $_');
};

# ============================================
# Multiple function calls in same expression
# ============================================
subtest 'multiple functions same expression' => sub {
    my @nums = (1, 5, 10);
    my @result = map { 
        my $clamped = util::clamp($_, 3, 8);
        my $is_ref = util::is_ref($_) ? 1 : 0;
        "$clamped:$is_ref"
    } @nums;
    is_deeply(\@result, ['3:0', '5:0', '8:0'], 'multiple functions in map block');
};

# ============================================
# Ternary with $_
# ============================================
subtest 'ternary with $_' => sub {
    my @mixed = (1, 'hello', [1,2], undef, {a=>1});
    my @result = map { 
        util::is_ref($_) ? 'ref' : (util::is_defined($_) ? 'scalar' : 'undef')
    } @mixed;
    is_deeply(\@result, ['scalar', 'scalar', 'ref', 'undef', 'ref'], 'ternary with $_');
};

# ============================================
# Nested structures with $_
# ============================================
subtest 'nested array processing' => sub {
    my @matrix = ([1, 5, 10], [20, 30], [100]);
    my @result = map {
        my $row = $_;
        my @clamped = map { util::clamp($_, 5, 25) } @$row;
        \@clamped;
    } @matrix;
    is_deeply($result[0], [5, 5, 10], 'first row clamped');
    is_deeply($result[1], [20, 25], 'second row clamped');
    is_deeply($result[2], [25], 'third row clamped');
};

# ============================================
# Empty list edge cases
# ============================================
subtest 'empty list in map' => sub {
    my @empty = ();
    my @result = map { util::clamp($_, 0, 10) } @empty;
    is_deeply(\@result, [], 'map over empty list');
};

subtest 'empty list in grep' => sub {
    my @empty = ();
    my @result = grep { util::is_defined($_) } @empty;
    is_deeply(\@result, [], 'grep over empty list');
};

# ============================================
# Single element list
# ============================================
subtest 'single element map' => sub {
    my @result = map { util::clamp($_, 5, 15) } (10);
    is_deeply(\@result, [10], 'map over single element');
};

subtest 'single element grep pass' => sub {
    my @result = grep { util::is_defined($_) } (42);
    is_deeply(\@result, [42], 'grep passes single element');
};

subtest 'single element grep fail' => sub {
    my @result = grep { util::is_defined($_) } (undef);
    is_deeply(\@result, [], 'grep filters single undef');
};

# ============================================
# Sort with transformation
# ============================================
subtest 'sort with map transform' => sub {
    my @nums = (100, 5, 50, 1);
    my @clamped = map { util::clamp($_, 10, 60) } sort { $a <=> $b } @nums;
    is_deeply(\@clamped, [10, 10, 50, 60], 'sort then map clamp');
};

# ============================================
# Reverse with map
# ============================================
subtest 'reverse with map' => sub {
    my @nums = (1, 5, 10);
    my @result = map { util::clamp($_, 3, 8) } reverse @nums;
    is_deeply(\@result, [8, 5, 3], 'reverse then map clamp');
};

# ============================================
# Return from map block
# ============================================
subtest 'conditional return in map' => sub {
    my @nums = (1, 5, 10, 15, 20);
    my @result = map { 
        if (util::is_even($_)) {
            util::clamp($_, 0, 12);
        } else {
            $_;
        }
    } @nums;
    is_deeply(\@result, [1, 5, 10, 15, 12], 'conditional return in map block');
};

# ============================================
# List context vs scalar context
# ============================================
subtest 'scalar context in map' => sub {
    my @arrays = ([1,2,3], [4,5], [6,7,8,9]);
    my @sizes = map { 
        my @arr = @$_;
        # Use identity to ensure we're testing the custom op
        util::identity(scalar @arr);
    } @arrays;
    is_deeply(\@sizes, [3, 2, 4], 'scalar context inside map');
};

# ============================================
# Grep with complex conditions
# ============================================
subtest 'grep with and/or' => sub {
    my @nums = (0, 5, 10, 15, 20, 25, 30);
    my @result = grep { 
        util::is_defined($_) && util::clamp($_, 10, 20) == $_
    } @nums;
    is_deeply(\@result, [10, 15, 20], 'grep with && condition using custom ops');
};

# ============================================
# Wantarray detection
# ============================================
subtest 'list vs scalar grep' => sub {
    my @data = (1, 2, 3, 4, 5);
    
    my @list_result = grep { util::is_even($_) } @data;
    is_deeply(\@list_result, [2, 4], 'grep in list context');
    
    my $scalar_result = grep { util::is_even($_) } @data;
    is($scalar_result, 2, 'grep in scalar context');
};

# ============================================
# Deeply nested loops
# ============================================
subtest 'triple nested loops' => sub {
    my @cubes = (
        [[1, 2], [3, 4]],
        [[5, 6], [7, 8]]
    );
    my @result;
    for my $cube (@cubes) {
        for my $plane (@$cube) {
            for (@$plane) {
                push @result, util::clamp($_, 3, 6);
            }
        }
    }
    is_deeply(\@result, [3, 3, 3, 4, 5, 6, 6, 6], 'triple nested for with $_');
};

# ============================================
# Mixed explicit and implicit $_
# ============================================
subtest 'mixed explicit and implicit' => sub {
    my @nums = (1, 5, 10);
    my @result = map {
        my $n = $_;                            # capture $_ first
        my $explicit = util::clamp($_, 3, 8);  # uses $_
        my $also = util::clamp($n, 2, 9);      # uses explicit $n
        "$explicit:$also"
    } @nums;
    # clamp(1,3,8)=3, clamp(1,2,9)=2; clamp(5,3,8)=5, clamp(5,2,9)=5; clamp(10,3,8)=8, clamp(10,2,9)=9
    is_deeply(\@result, ['3:2', '5:5', '8:9'], 'mixed $_ and explicit in same block');
};

# ============================================
# Explicit lexical loop variable (for my $i)
# ============================================
subtest 'for my $i with clamp' => sub {
    my @nums = (0, 5, 10, -3, 100);
    my @result;
    for my $i (@nums) {
        my $clamped = util::clamp($i, 2, 50);
        push @result, $clamped;
    }
    is_deeply(\@result, [2, 5, 10, 2, 50], 'clamp works with explicit $i');
};

subtest 'for my $n with is_ref' => sub {
    my @mixed = (1, 'two', [1,2,3], {a=>1});
    my $count = 0;
    for my $n (@mixed) {
        $count++ if util::is_ref($n);
    }
    is($count, 2, 'is_ref works with explicit $n');
};

subtest 'for my $val with is_defined' => sub {
    my @vals = (1, undef, 'a', undef, 0);
    my @defined;
    for my $val (@vals) {
        push @defined, $val if util::is_defined($val);
    }
    is_deeply(\@defined, [1, 'a', 0], 'is_defined works with explicit $val');
};

subtest 'for my $s with trim' => sub {
    my @strings = ('  a  ', ' b ', '  c  ');
    my @trimmed;
    for my $s (@strings) {
        push @trimmed, util::trim($s);
    }
    is_deeply(\@trimmed, ['a', 'b', 'c'], 'trim works with explicit $s');
};

subtest 'nested for my loops' => sub {
    my @matrix = ([0, 50, 100], [10, 20, 30]);
    my @result;
    for my $row (@matrix) {
        my @clamped;
        for my $cell (@$row) {
            my $v = util::clamp($cell, 15, 75);
            push @clamped, $v;
        }
        push @result, \@clamped;
    }
    is_deeply(\@result, [[15, 50, 75], [15, 20, 30]], 'nested for my with clamp');
};

done_testing();

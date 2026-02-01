#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use util;

# Test all custom-op functions work correctly in map/grep context
# This ensures the call checkers properly fall back to XS when $_ is used

my @nums = (0, 5, 10, -3, 100);
my @strings = ('hello', 'world', '', 'test', 'a');
my $scalar_ref;
my @mixed = (1, 'two', undef, [1,2,3], {a=>1}, sub{1}, \$scalar_ref, qr/foo/);
# @mixed contains: num, string, undef, arrayref, hashref, coderef, scalarref, regex
# Refs are: arrayref, hashref, coderef, scalarref, regex = 5 refs

# ============================================
# clamp - the original problematic function
# ============================================
subtest 'clamp in map' => sub {
    my @result = map { util::clamp($_, 2, 50) } @nums;
    is_deeply(\@result, [2, 5, 10, 2, 50], 'clamp works in map');
    
    @result = map { util::clamp($_, 0, 10) } (1, 5, 15, -1);
    is_deeply(\@result, [1, 5, 10, 0], 'clamp with different bounds');
};

# ============================================
# Type predicates - single arg functions
# ============================================
subtest 'is_ref in map/grep' => sub {
    my @refs = grep { util::is_ref($_) } @mixed;
    is(scalar(@refs), 5, 'is_ref in grep finds 5 refs');
    
    my @results = map { util::is_ref($_) ? 1 : 0 } @mixed;
    is_deeply(\@results, [0, 0, 0, 1, 1, 1, 1, 1], 'is_ref in map');
};

subtest 'is_array in map/grep' => sub {
    my @arrays = grep { util::is_array($_) } @mixed;
    is(scalar(@arrays), 1, 'is_array in grep finds 1 array');
};

subtest 'is_hash in map/grep' => sub {
    my @hashes = grep { util::is_hash($_) } @mixed;
    is(scalar(@hashes), 1, 'is_hash in grep finds 1 hash');
};

subtest 'is_code in map/grep' => sub {
    my @codes = grep { util::is_code($_) } @mixed;
    is(scalar(@codes), 1, 'is_code in grep finds 1 coderef');
};

subtest 'is_defined in map/grep' => sub {
    my @defined = grep { util::is_defined($_) } @mixed;
    is(scalar(@defined), 7, 'is_defined in grep finds 7 defined values');
    
    my @results = map { util::is_defined($_) ? 1 : 0 } (1, undef, 'a', undef);
    is_deeply(\@results, [1, 0, 1, 0], 'is_defined in map');
};

subtest 'is_empty in map/grep' => sub {
    my @empties = grep { util::is_empty($_) } @strings;
    is(scalar(@empties), 1, 'is_empty in grep finds 1 empty string');
};

subtest 'is_true in map/grep' => sub {
    my @trues = grep { util::is_true($_) } @nums;
    is(scalar(@trues), 4, 'is_true in grep finds 4 true values');
};

subtest 'is_false in map/grep' => sub {
    my @falses = grep { util::is_false($_) } @nums;
    is(scalar(@falses), 1, 'is_false in grep finds 1 false value (0)');
};

subtest 'bool in map' => sub {
    my @results = map { util::bool($_) ? 1 : 0 } (0, 1, '', 'a', undef);
    is_deeply(\@results, [0, 1, 0, 1, 0], 'bool in map');
};

subtest 'is_num in map/grep' => sub {
    my @numbers = grep { util::is_num($_) } @mixed;
    is(scalar(@numbers), 1, 'is_num in grep finds 1 number');
};

subtest 'is_int in map/grep' => sub {
    my @ints = grep { util::is_int($_) } (1, 1.5, 2, 2.5, 3);
    is(scalar(@ints), 3, 'is_int in grep finds 3 integers');
};

subtest 'is_blessed in map/grep' => sub {
    my $obj = bless {}, 'Foo';
    my @items = ($obj, {}, [], 'str');
    my @blessed = grep { util::is_blessed($_) } @items;
    is(scalar(@blessed), 1, 'is_blessed in grep finds 1 blessed ref');
};

subtest 'is_scalar_ref in map/grep' => sub {
    # Note: is_scalar_ref checks SvTYPE < SVt_PVAV, which includes regex (SVt_REGEXP)
    # So both \$scalar_ref and qr/foo/ are counted as scalar refs
    my @scalars = grep { util::is_scalar_ref($_) } @mixed;
    is(scalar(@scalars), 2, 'is_scalar_ref in grep finds 2 scalar refs (includes regex)');
};

subtest 'is_regex in map/grep' => sub {
    my @regexes = grep { util::is_regex($_) } @mixed;
    is(scalar(@regexes), 1, 'is_regex in grep finds 1 regex');
};

subtest 'is_glob in map/grep' => sub {
    my @items = (*STDOUT, 'str', 1);
    my @globs = grep { util::is_glob($_) } @items;
    is(scalar(@globs), 1, 'is_glob in grep finds 1 glob');
};

# ============================================
# Numeric predicates
# ============================================
subtest 'is_positive in map/grep' => sub {
    my @pos = grep { util::is_positive($_) } @nums;
    is(scalar(@pos), 3, 'is_positive in grep finds 3 positive nums');
};

subtest 'is_negative in map/grep' => sub {
    my @neg = grep { util::is_negative($_) } @nums;
    is(scalar(@neg), 1, 'is_negative in grep finds 1 negative num');
};

subtest 'is_zero in map/grep' => sub {
    my @zeros = grep { util::is_zero($_) } @nums;
    is(scalar(@zeros), 1, 'is_zero in grep finds 1 zero');
};

subtest 'is_even in map/grep' => sub {
    my @evens = grep { util::is_even($_) } (1, 2, 3, 4, 5, 6);
    is(scalar(@evens), 3, 'is_even in grep finds 3 even nums');
};

subtest 'is_odd in map/grep' => sub {
    my @odds = grep { util::is_odd($_) } (1, 2, 3, 4, 5, 6);
    is(scalar(@odds), 3, 'is_odd in grep finds 3 odd nums');
};

# ============================================
# Two-arg string functions
# ============================================
subtest 'starts_with in map/grep' => sub {
    my @starts = grep { util::starts_with($_, 'he') } @strings;
    is(scalar(@starts), 1, 'starts_with in grep finds 1 match');
    
    my @results = map { util::starts_with($_, 'wo') ? 1 : 0 } @strings;
    is_deeply(\@results, [0, 1, 0, 0, 0], 'starts_with in map');
};

subtest 'ends_with in map/grep' => sub {
    my @ends = grep { util::ends_with($_, 'ld') } @strings;
    is(scalar(@ends), 1, 'ends_with in grep finds 1 match');
    
    my @results = map { util::ends_with($_, 'o') ? 1 : 0 } @strings;
    is_deeply(\@results, [1, 0, 0, 0, 0], 'ends_with in map');
};

# ============================================
# Collection functions
# ============================================
subtest 'array_len in map' => sub {
    my @arrays = ([1,2], [1,2,3], [], [1]);
    my @lens = map { util::array_len($_) } @arrays;
    is_deeply(\@lens, [2, 3, 0, 1], 'array_len in map');
};

subtest 'hash_size in map' => sub {
    my @hashes = ({a=>1}, {a=>1,b=>2}, {});
    my @sizes = map { util::hash_size($_) } @hashes;
    is_deeply(\@sizes, [1, 2, 0], 'hash_size in map');
};

subtest 'is_empty_array in map/grep' => sub {
    my @arrays = ([1,2], [], [3], []);
    my @empties = grep { util::is_empty_array($_) } @arrays;
    is(scalar(@empties), 2, 'is_empty_array in grep finds 2 empty arrays');
};

subtest 'is_empty_hash in map/grep' => sub {
    my @hashes = ({a=>1}, {}, {b=>2}, {});
    my @empties = grep { util::is_empty_hash($_) } @hashes;
    is(scalar(@empties), 2, 'is_empty_hash in grep finds 2 empty hashes');
};

subtest 'array_first in map' => sub {
    my @arrays = ([10, 20], [30, 40], [50]);
    my @firsts = map { util::array_first($_) } @arrays;
    is_deeply(\@firsts, [10, 30, 50], 'array_first in map');
};

subtest 'array_last in map' => sub {
    my @arrays = ([10, 20], [30, 40], [50]);
    my @lasts = map { util::array_last($_) } @arrays;
    is_deeply(\@lasts, [20, 40, 50], 'array_last in map');
};

# ============================================
# identity function
# ============================================
subtest 'identity in map' => sub {
    my @result = map { util::identity($_) } @nums;
    is_deeply(\@result, \@nums, 'identity in map returns same values');
};

# ============================================
# Nested map/grep
# ============================================
subtest 'nested map with clamp' => sub {
    my @matrix = ([0, 50, 100], [10, 20, 30]);
    my @result = map {
        my $row = $_;
        [ map { util::clamp($_, 15, 75) } @$row ]
    } @matrix;
    is_deeply(\@result, [[15, 50, 75], [15, 20, 30]], 'nested map with clamp');
};

subtest 'grep inside map' => sub {
    my @data = ([1, undef, 2], [undef, 3], [4, 5, undef]);
    my @result = map {
        my @defined = grep { util::is_defined($_) } @$_;
        scalar(@defined);
    } @data;
    is_deeply(\@result, [2, 1, 2], 'grep with is_defined inside map');
};

# ============================================
# for/foreach loops - also use $_ implicitly
# ============================================
subtest 'clamp in foreach loop' => sub {
    my @result;
    for (@nums) {
        push @result, util::clamp($_, 2, 50);
    }
    is_deeply(\@result, [2, 5, 10, 2, 50], 'clamp works in foreach with implicit $_');
};

subtest 'is_ref in for loop' => sub {
    my $count = 0;
    for (@mixed) {
        $count++ if util::is_ref($_);
    }
    is($count, 5, 'is_ref works in for loop with $_');
};

subtest 'is_defined in foreach with explicit variable' => sub {
    my @result;
    foreach my $val (1, undef, 'a', undef) {
        push @result, util::is_defined($val) ? 1 : 0;
    }
    is_deeply(\@result, [1, 0, 1, 0], 'is_defined in foreach with explicit $val');
};

subtest 'trim in for loop' => sub {
    my @result;
    for ('  hello  ', ' world ', '  test  ') {
        push @result, util::trim($_);
    }
    is_deeply(\@result, ['hello', 'world', 'test'], 'trim in for loop with $_');
};

subtest 'trim in C-style for loop' => sub {
    my @strings = ('  a  ', ' b ', '  c');
    my @result;
    for (my $i = 0; $i < @strings; $i++) {
        # This uses $strings[$i], not $_
        push @result, util::trim($strings[$i]);
    }
    is_deeply(\@result, ['a', 'b', 'c'], 'trim in C-style for loop');
};

subtest 'nested for loops with $_' => sub {
    my @matrix = ([0, 50, 100], [10, 20, 30]);
    my @result;
    for my $row (@matrix) {
        my @clamped;
        for (@$row) {
            push @clamped, util::clamp($_, 15, 75);
        }
        push @result, \@clamped;
    }
    is_deeply(\@result, [[15, 50, 75], [15, 20, 30]], 'nested for with inner $_ clamp');
};

done_testing();

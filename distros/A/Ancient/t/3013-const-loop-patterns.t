#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use const;

# Test const functions with various loop variable patterns

subtest 'for with $val' => sub {
    my @values = (1, 2, 3);
    my @consts;
    for my $val (@values) {
        push @consts, const::c($val);
    }
    is_deeply(\@consts, [1, 2, 3], 'const::c with $val');
};

subtest 'map with $_' => sub {
    my @nums = (10, 20, 30);
    my @frozen = map { const::c($_) } @nums;
    is_deeply(\@frozen, [10, 20, 30], 'const::c with $_ in map');
};

subtest 'for with $item hashref' => sub {
    my @data = (
        { name => 'a', value => 1 },
        { name => 'b', value => 2 },
    );

    my @frozen;
    for my $item (@data) {
        push @frozen, const::c($item);
    }
    is($frozen[0]->{name}, 'a', 'const::c hashref name');
    is($frozen[1]->{value}, 2, 'const::c hashref value');
};

subtest 'for with $x' => sub {
    my @values = ('hello', 'world', 'test');
    my @result;
    for my $x (@values) {
        push @result, const::c($x);
    }
    is_deeply(\@result, ['hello', 'world', 'test'], 'const::c strings with $x');
};

subtest 'nested for with $outer/$inner' => sub {
    my @result;
    for my $outer (1..2) {
        for my $inner ('a', 'b') {
            push @result, const::c("$outer$inner");
        }
    }
    is_deeply(\@result, ['1a', '1b', '2a', '2b'], 'nested const::c');
};

subtest 'for with $n numbers' => sub {
    my @nums = (3.14, 2.71, 1.41);
    my @consts;
    for my $n (@nums) {
        push @consts, const::c($n);
    }
    is($consts[0], 3.14, 'const::c float with $n');
    is($consts[1], 2.71, 'const::c float with $n');
    is($consts[2], 1.41, 'const::c float with $n');
};

subtest 'for with $ref arrays' => sub {
    my @arrays = ([1,2], [3,4], [5,6]);
    my @frozen;
    for my $ref (@arrays) {
        push @frozen, const::c($ref);
    }
    is_deeply($frozen[0], [1,2], 'const::c array with $ref');
    is_deeply($frozen[1], [3,4], 'const::c array with $ref');
    is_deeply($frozen[2], [5,6], 'const::c array with $ref');
};

subtest 'map with interpolated "val$_"' => sub {
    my @indices = (1, 2, 3);
    my @result = map { const::c("val$_") } @indices;
    is_deeply(\@result, ['val1', 'val2', 'val3'], 'const::c interpolated');
};

done_testing();

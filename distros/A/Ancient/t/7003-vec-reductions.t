#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('nvec');

# Helper for float comparison (quadmath-safe)
sub is_float {
    my ($got, $expected, $name, $tol) = @_;
    $tol //= 1e-10;
    ok(abs($got - $expected) < $tol, $name)
        or diag("got: $got, expected: $expected");
}

subtest 'sum' => sub {
    is(nvec::new([1, 2, 3, 4, 5])->sum, 15, 'sum of 1..5');
    is(nvec::new([-1, 1, -1, 1])->sum, 0, 'sum with negatives');
    is(nvec::zeros(100)->sum, 0, 'sum of zeros');
    is(nvec::ones(100)->sum, 100, 'sum of ones');
    is_float(nvec::new([0.1, 0.2, 0.3])->sum, 0.6, 'sum of floats');
};

subtest 'product' => sub {
    is(nvec::new([1, 2, 3, 4])->product, 24, 'product of 1..4');
    is(nvec::new([2, 2, 2, 2])->product, 16, '2^4');
    is(nvec::new([1, 2, 0, 4])->product, 0, 'product with zero');
    is(nvec::new([-1, 2, -3])->product, 6, 'product with negatives');
    is(nvec::ones(10)->product, 1, 'product of ones');
};

subtest 'mean' => sub {
    is(nvec::new([2, 4, 6, 8])->mean, 5, 'mean of evens');
    is(nvec::ones(100)->mean, 1, 'mean of ones');
    is(nvec::new([0, 10])->mean, 5, 'mean of two values');
    is(nvec::new([-10, 10])->mean, 0, 'mean of opposite values');
};

subtest 'min' => sub {
    is(nvec::new([5, 3, 8, 1, 9])->min, 1, 'min basic');
    is(nvec::new([-5, -3, -8, -1])->min, -8, 'min with negatives');
    is(nvec::new([7, 7, 7])->min, 7, 'min of same values');
    is(nvec::new([42])->min, 42, 'min of single value');
};

subtest 'max' => sub {
    is(nvec::new([5, 3, 8, 1, 9])->max, 9, 'max basic');
    is(nvec::new([-5, -3, -8, -1])->max, -1, 'max with negatives');
    is(nvec::new([7, 7, 7])->max, 7, 'max of same values');
    is(nvec::new([42])->max, 42, 'max of single value');
};

subtest 'argmin' => sub {
    is(nvec::new([5, 3, 8, 1, 9])->argmin, 3, 'argmin basic');
    is(nvec::new([1, 2, 3, 4, 5])->argmin, 0, 'argmin at start');
    is(nvec::new([5, 4, 3, 2, 1])->argmin, 4, 'argmin at end');
    is(nvec::new([1, 1, 1])->argmin, 0, 'argmin first occurrence');
};

subtest 'argmax' => sub {
    is(nvec::new([5, 3, 8, 1, 9])->argmax, 4, 'argmax basic');
    is(nvec::new([9, 2, 3, 4, 5])->argmax, 0, 'argmax at start');
    is(nvec::new([1, 2, 3, 4, 9])->argmax, 4, 'argmax at end');
    is(nvec::new([5, 5, 5])->argmax, 0, 'argmax first occurrence');
};

subtest 'dot product' => sub {
    is(nvec::new([1, 2, 3])->dot(nvec::new([4, 5, 6])), 32, 'dot 1*4+2*5+3*6');
    is(nvec::new([1, 0, 0])->dot(nvec::new([0, 1, 0])), 0, 'perpendicular dot = 0');
    is(nvec::new([2, 3])->dot(nvec::new([2, 3])), 13, 'dot with self');
    
    my $a = nvec::ones(1000);
    my $b = nvec::fill(1000, 2);
    is($a->dot($b), 2000, 'large dot product');
};

subtest 'norm (L2)' => sub {
    is(nvec::new([3, 4])->norm, 5, 'norm of 3-4-5 triangle');
    is(nvec::new([1, 0, 0])->norm, 1, 'unit vector norm');
    ok(abs(nvec::new([1, 1])->norm - sqrt(2)) < 1e-10, 'norm of [1,1]');
    ok(abs(nvec::new([1, 1, 1])->norm - sqrt(3)) < 1e-10, 'norm of [1,1,1]');
};

subtest 'empty vector reductions' => sub {
    my $empty = nvec::new([]);
    is($empty->sum, 0, 'sum of empty');
    is($empty->product, 1, 'product of empty');
    is($empty->mean, 0, 'mean of empty');
};

subtest 'large vector reductions' => sub {
    my $n = 100000;
    my $ones = nvec::ones($n);
    
    is($ones->sum, $n, "sum of $n ones");
    is($ones->product, 1, "product of $n ones");
    is($ones->mean, 1, "mean of $n ones");
    is($ones->min, 1, "min of $n ones");
    is($ones->max, 1, "max of $n ones");
};

subtest 'reduction accuracy' => sub {
    # Test that SIMD reductions are accurate
    my @vals = map { $_ * 0.1 } 1..100;  # 0.1, 0.2, ..., 10.0
    my $v = nvec::new(\@vals);
    
    my $expected_sum = 0;
    $expected_sum += $_ for @vals;
    
    ok(abs($v->sum - $expected_sum) < 1e-10, 'float sum accuracy');
};

done_testing;

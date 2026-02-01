#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('nvec');

my $eps = 1e-10;

sub approx_eq {
    my ($a, $b, $msg) = @_;
    ok(abs($a - $b) < $eps, $msg // "approx equal: $a ≈ $b");
}

# ============================================
# New in-place operations
# ============================================

subtest 'sub_inplace' => sub {
    my $a = nvec::new([10, 20, 30]);
    my $b = nvec::new([1, 2, 3]);
    
    my $ret = $a->sub_inplace($b);
    is($ret, $a, 'returns self');
    is_deeply($a->to_array, [9, 18, 27], 'subtraction correct');
};

subtest 'mul_inplace' => sub {
    my $a = nvec::new([2, 3, 4]);
    my $b = nvec::new([5, 6, 7]);
    
    $a->mul_inplace($b);
    is_deeply($a->to_array, [10, 18, 28], 'multiplication correct');
};

subtest 'div_inplace' => sub {
    my $a = nvec::new([10, 20, 30]);
    my $b = nvec::new([2, 4, 5]);
    
    $a->div_inplace($b);
    is_deeply($a->to_array, [5, 5, 6], 'division correct');
};

# ============================================
# Slicing and Copy
# ============================================

subtest 'slice' => sub {
    my $v = nvec::new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    
    my $s = $v->slice(2, 5);
    is_deeply($s->to_array, [2, 3, 4, 5, 6], 'slice middle');
    is($s->len, 5, 'slice length');
    
    my $s2 = $v->slice(0, 3);
    is_deeply($s2->to_array, [0, 1, 2], 'slice from start');
    
    my $s3 = $v->slice(7, 3);
    is_deeply($s3->to_array, [7, 8, 9], 'slice to end');
};

subtest 'slice negative index' => sub {
    my $v = nvec::new([0, 1, 2, 3, 4]);
    
    my $s = $v->slice(-3, 2);
    is_deeply($s->to_array, [2, 3], 'negative start index');
};

subtest 'copy' => sub {
    my $a = nvec::new([1, 2, 3, 4, 5]);
    my $b = $a->copy;
    
    # Use refaddr to compare object identity, not stringification (due to overload)
    use Scalar::Util 'refaddr';
    isnt(refaddr($a), refaddr($b), 'copy is different object');
    is_deeply($a->to_array, $b->to_array, 'copy has same values');
    
    $b->set(0, 999);
    is($a->get(0), 1, 'modifying copy does not affect original');
};

# ============================================
# FMA and AXPY
# ============================================

subtest 'fma_inplace' => sub {
    # c = a * b + c
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([4, 5, 6]);
    my $c = nvec::new([10, 10, 10]);
    
    $c->fma_inplace($a, $b);
    # c = [1*4+10, 2*5+10, 3*6+10] = [14, 20, 28]
    is_deeply($c->to_array, [14, 20, 28], 'fma correct');
};

subtest 'axpy' => sub {
    # y = a*x + y
    my $x = nvec::new([1, 2, 3, 4]);
    my $y = nvec::new([10, 10, 10, 10]);
    
    $y->axpy(2, $x);
    # y = [2*1+10, 2*2+10, 2*3+10, 2*4+10] = [12, 14, 16, 18]
    is_deeply($y->to_array, [12, 14, 16, 18], 'axpy correct');
};

subtest 'axpy large SIMD' => sub {
    my $n = 1000;
    my $x = nvec::ones($n);
    my $y = nvec::zeros($n);
    
    $y->axpy(3.0, $x);
    is($y->sum, 3000, 'axpy on large vector');
    
    $y->axpy(2.0, $x);
    is($y->sum, 5000, 'second axpy');
};

# ============================================
# Statistics
# ============================================

subtest 'variance' => sub {
    # Sample variance: sum((x - mean)^2) / (n-1)
    my $v = nvec::new([2, 4, 4, 4, 5, 5, 7, 9]);
    # mean = 5, deviations: -3,-1,-1,-1,0,0,2,4
    # sum of sq: 9+1+1+1+0+0+4+16 = 32
    # variance = 32/7 = 4.571...
    approx_eq($v->variance, 32/7, 'variance calculation');
};

subtest 'std' => sub {
    my $v = nvec::new([2, 4, 4, 4, 5, 5, 7, 9]);
    approx_eq($v->std, sqrt(32/7), 'std calculation');
};

subtest 'variance of constant' => sub {
    my $v = nvec::fill(100, 42);
    is($v->variance, 0, 'variance of constant is 0');
    is($v->std, 0, 'std of constant is 0');
};

subtest 'variance edge cases' => sub {
    my $one = nvec::new([5]);
    is($one->variance, 0, 'variance of single element');
    
    my $empty = nvec::new([]);
    is($empty->variance, 0, 'variance of empty');
};

# ============================================
# SIMD-optimized min/max
# ============================================

subtest 'min SIMD correctness' => sub {
    for my $size (1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 100, 1000) {
        my @vals = map { rand() * 100 } 1..$size;
        my $expected_min = $vals[0];
        $expected_min = $_ < $expected_min ? $_ : $expected_min for @vals;
        
        my $v = nvec::new(\@vals);
        approx_eq($v->min, $expected_min, "min for size $size");
    }
};

subtest 'max SIMD correctness' => sub {
    for my $size (1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 100, 1000) {
        my @vals = map { rand() * 100 } 1..$size;
        my $expected_max = $vals[0];
        $expected_max = $_ > $expected_max ? $_ : $expected_max for @vals;
        
        my $v = nvec::new(\@vals);
        approx_eq($v->max, $expected_max, "max for size $size");
    }
};

done_testing;

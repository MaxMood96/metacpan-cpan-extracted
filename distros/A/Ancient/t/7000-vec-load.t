#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

BEGIN { use_ok('nvec') }

# Helper for float comparison (quadmath-safe)
sub is_float {
    my ($got, $expected, $name, $tol) = @_;
    $tol //= 1e-10;
    ok(abs($got - $expected) < $tol, $name)
        or diag("got: $got, expected: $expected");
}

# Test SIMD detection
my $simd = nvec::simd_info();
diag("SIMD implementation: $simd");
ok($simd =~ /^(NEON|AVX2|AVX|SSE2|Scalar)$/, "Valid SIMD: $simd");

# ============================================
# Constructors
# ============================================

subtest 'nvec::new' => sub {
    my $v = nvec::new([1.0, 2.0, 3.0, 4.0]);
    isa_ok($v, 'nvec');
    is($v->len(), 4, 'length is 4');
    is($v->get(0), 1.0, 'element 0');
    is($v->get(3), 4.0, 'element 3');
};

subtest 'nvec::zeros' => sub {
    my $v = nvec::zeros(100);
    is($v->len(), 100, 'length is 100');
    is($v->get(0), 0, 'element 0 is 0');
    is($v->get(99), 0, 'element 99 is 0');
    is($v->sum(), 0, 'sum is 0');
};

subtest 'nvec::ones' => sub {
    my $v = nvec::ones(50);
    is($v->len(), 50, 'length is 50');
    is($v->get(0), 1, 'element 0 is 1');
    is($v->sum(), 50, 'sum is 50');
};

subtest 'nvec::fill' => sub {
    my $v = nvec::fill(10, 3.14);
    is($v->len(), 10, 'length is 10');
    is_float($v->get(5), 3.14, 'element 5 is 3.14');
};

subtest 'nvec::range' => sub {
    my $v = nvec::range(0, 10);
    is($v->len(), 10, 'length is 10');
    is($v->get(0), 0, 'element 0 is 0');
    is($v->get(9), 9, 'element 9 is 9');
};

subtest 'nvec::linspace' => sub {
    my $v = nvec::linspace(0, 1, 5);
    is($v->len(), 5, 'length is 5');
    is($v->get(0), 0, 'first is 0');
    is($v->get(4), 1, 'last is 1');
    is($v->get(2), 0.5, 'middle is 0.5');
};

# ============================================
# Element Access
# ============================================

subtest 'get/set' => sub {
    my $v = nvec::zeros(10);
    $v->set(5, 42.0);
    is($v->get(5), 42.0, 'set and get work');
    
    eval { $v->get(100) };
    like($@, qr/out of bounds/, 'get out of bounds croaks');
    
    eval { $v->set(100, 1) };
    like($@, qr/out of bounds/, 'set out of bounds croaks');
};

subtest 'to_array' => sub {
    my $v = nvec::new([1, 2, 3]);
    my $arr = $v->to_array();
    is_deeply($arr, [1, 2, 3], 'to_array returns correct arrayref');
};

# ============================================
# Arithmetic
# ============================================

subtest 'add' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([4, 3, 2, 1]);
    my $c = $a->add($b);
    is_deeply($c->to_array(), [5, 5, 5, 5], 'add works');
    
    # Original unchanged
    is_deeply($a->to_array(), [1, 2, 3, 4], 'a unchanged');
};

subtest 'sub' => sub {
    my $a = nvec::new([5, 5, 5, 5]);
    my $b = nvec::new([1, 2, 3, 4]);
    my $c = $a->sub($b);
    is_deeply($c->to_array(), [4, 3, 2, 1], 'sub works');
};

subtest 'mul' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([2, 2, 2, 2]);
    my $c = $a->mul($b);
    is_deeply($c->to_array(), [2, 4, 6, 8], 'mul works');
};

subtest 'div' => sub {
    my $a = nvec::new([10, 20, 30, 40]);
    my $b = nvec::new([2, 4, 5, 8]);
    my $c = $a->div($b);
    is_deeply($c->to_array(), [5, 5, 6, 5], 'div works');
};

subtest 'scale' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = $a->scale(2.5);
    is_deeply($b->to_array(), [2.5, 5, 7.5, 10], 'scale works');
};

subtest 'add_scalar' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = $a->add_scalar(10);
    is_deeply($b->to_array(), [11, 12, 13, 14], 'add_scalar works');
};

subtest 'neg' => sub {
    my $a = nvec::new([1, -2, 3, -4]);
    my $b = $a->neg();
    is_deeply($b->to_array(), [-1, 2, -3, 4], 'neg works');
};

subtest 'abs' => sub {
    my $a = nvec::new([-1, 2, -3, 4]);
    my $b = $a->abs();
    is_deeply($b->to_array(), [1, 2, 3, 4], 'abs works');
};

subtest 'sqrt' => sub {
    my $a = nvec::new([1, 4, 9, 16]);
    my $b = $a->sqrt();
    is_deeply($b->to_array(), [1, 2, 3, 4], 'sqrt works');
};

# ============================================
# In-place Operations
# ============================================

subtest 'add_inplace' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([1, 1, 1, 1]);
    my $ret = $a->add_inplace($b);
    is($ret, $a, 'returns self');
    is_deeply($a->to_array(), [2, 3, 4, 5], 'add_inplace modifies');
};

subtest 'scale_inplace' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    $a->scale_inplace(2);
    is_deeply($a->to_array(), [2, 4, 6, 8], 'scale_inplace works');
};

subtest 'clamp_inplace' => sub {
    my $a = nvec::new([-5, 0, 5, 10, 15]);
    $a->clamp_inplace(0, 10);
    is_deeply($a->to_array(), [0, 0, 5, 10, 10], 'clamp_inplace works');
};

# ============================================
# Reductions
# ============================================

subtest 'sum' => sub {
    my $v = nvec::new([1, 2, 3, 4, 5]);
    is($v->sum(), 15, 'sum of 1..5 = 15');
    
    my $big = nvec::ones(10000);
    is($big->sum(), 10000, 'sum of 10000 ones');
};

subtest 'product' => sub {
    my $v = nvec::new([1, 2, 3, 4]);
    is($v->product(), 24, 'product of 1..4 = 24');
};

subtest 'mean' => sub {
    my $v = nvec::new([2, 4, 6, 8]);
    is($v->mean(), 5, 'mean of [2,4,6,8] = 5');
};

subtest 'min/max' => sub {
    my $v = nvec::new([3, 1, 4, 1, 5, 9, 2, 6]);
    is($v->min(), 1, 'min = 1');
    is($v->max(), 9, 'max = 9');
};

subtest 'argmin/argmax' => sub {
    my $v = nvec::new([3, 1, 4, 1, 5, 9, 2, 6]);
    is($v->argmin(), 1, 'argmin = 1 (first occurrence)');
    is($v->argmax(), 5, 'argmax = 5');
};

subtest 'dot' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([4, 5, 6]);
    is($a->dot($b), 32, 'dot product = 1*4 + 2*5 + 3*6 = 32');
    
    # Large vectors
    my $big_a = nvec::ones(10000);
    my $big_b = nvec::fill(10000, 2);
    is($big_a->dot($big_b), 20000, 'dot of 10000 elements');
};

subtest 'norm' => sub {
    my $v = nvec::new([3, 4]);
    is($v->norm(), 5, 'norm of [3,4] = 5');
};

# ============================================
# Linear Algebra
# ============================================

subtest 'normalize' => sub {
    my $v = nvec::new([3, 4]);
    my $u = $v->normalize();
    is_float($u->get(0), 0.6, 'normalized x = 0.6');
    is_float($u->get(1), 0.8, 'normalized y = 0.8');

    # Verify norm is 1
    my $norm = $u->norm();
    ok(abs($norm - 1.0) < 1e-10, "norm of normalized vector is 1 (got $norm)");
};

subtest 'distance' => sub {
    my $a = nvec::new([0, 0]);
    my $b = nvec::new([3, 4]);
    is($a->distance($b), 5, 'distance = 5');
};

subtest 'cosine_similarity' => sub {
    my $a = nvec::new([1, 0]);
    my $b = nvec::new([0, 1]);
    is($a->cosine_similarity($b), 0, 'perpendicular = 0');
    
    my $c = nvec::new([1, 1]);
    my $d = nvec::new([1, 1]);
    ok(abs($c->cosine_similarity($d) - 1.0) < 1e-10, 'same direction = 1');
};

# ============================================
# Edge Cases
# ============================================

subtest 'empty vector' => sub {
    my $v = nvec::zeros(0);
    is($v->len(), 0, 'empty vec has len 0');
    is($v->sum(), 0, 'sum of empty = 0');
    is($v->mean(), 0, 'mean of empty = 0');
};

subtest 'length mismatch' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([1, 2]);
    
    eval { $a->add($b) };
    like($@, qr/same length/, 'add with length mismatch croaks');
    
    eval { $a->dot($b) };
    like($@, qr/same length/, 'dot with length mismatch croaks');
};

# ============================================
# SIMD correctness with larger arrays
# ============================================

subtest 'SIMD correctness' => sub {
    # Test with sizes that exercise SIMD lanes and tails
    for my $size (1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 100, 1000) {
        my $a = nvec::fill($size, 2.0);
        my $b = nvec::fill($size, 3.0);
        
        my $sum = $a->add($b);
        is($sum->get(0), 5.0, "add[$size] element 0");
        is($sum->get($size-1), 5.0, "add[$size] last element");
        
        my $total = $a->sum();
        is($total, 2.0 * $size, "sum[$size] = " . (2.0 * $size));
        
        my $dot = $a->dot($b);
        is($dot, 6.0 * $size, "dot[$size] = " . (6.0 * $size));
    }
};

done_testing();

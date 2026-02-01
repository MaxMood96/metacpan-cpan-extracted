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

sub vec_approx_eq {
    my ($v, $expected, $msg) = @_;
    my $arr = $v->to_array;
    is(scalar @$arr, scalar @$expected, "$msg: length matches");
    for my $i (0 .. $#$expected) {
        ok(abs($arr->[$i] - $expected->[$i]) < $eps, "$msg: element $i");
    }
}

subtest 'normalize 2D' => sub {
    my $v = nvec::new([3, 4]);
    my $n = $v->normalize;
    
    approx_eq($n->get(0), 0.6, 'x component');
    approx_eq($n->get(1), 0.8, 'y component');
    approx_eq($n->norm, 1.0, 'normalized has unit length');
};

subtest 'normalize 3D' => sub {
    my $v = nvec::new([1, 2, 2]);
    my $n = $v->normalize;
    
    approx_eq($n->norm, 1.0, 'normalized has unit length');
    
    # Original should be (1/3, 2/3, 2/3)
    approx_eq($n->get(0), 1/3, 'x component');
    approx_eq($n->get(1), 2/3, 'y component');
    approx_eq($n->get(2), 2/3, 'z component');
};

subtest 'normalize unit vector' => sub {
    my $v = nvec::new([1, 0, 0]);
    my $n = $v->normalize;
    
    is_deeply($n->to_array, [1, 0, 0], 'unit vector unchanged');
};

subtest 'normalize preserves direction' => sub {
    my $v = nvec::new([10, 20, 30]);
    my $n = $v->normalize;
    
    # Ratios should be preserved
    approx_eq($n->get(1) / $n->get(0), 2.0, 'y/x ratio preserved');
    approx_eq($n->get(2) / $n->get(0), 3.0, 'z/x ratio preserved');
};

subtest 'distance 2D' => sub {
    my $a = nvec::new([0, 0]);
    my $b = nvec::new([3, 4]);
    
    is($a->distance($b), 5, 'origin to (3,4)');
    is($b->distance($a), 5, 'symmetric');
    is($a->distance($a), 0, 'distance to self is 0');
};

subtest 'distance 3D' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([4, 6, 3]);  # diff is (3, 4, 0)
    
    is($a->distance($b), 5, '3D distance');
};

subtest 'distance large vectors' => sub {
    my $a = nvec::zeros(1000);
    my $b = nvec::ones(1000);
    
    approx_eq($a->distance($b), sqrt(1000), 'distance in 1000D');
};

subtest 'cosine_similarity parallel' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([2, 4, 6]);  # same direction
    
    approx_eq($a->cosine_similarity($b), 1.0, 'parallel vectors');
};

subtest 'cosine_similarity antiparallel' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([-1, -2, -3]);  # opposite direction
    
    approx_eq($a->cosine_similarity($b), -1.0, 'antiparallel vectors');
};

subtest 'cosine_similarity perpendicular' => sub {
    my $a = nvec::new([1, 0]);
    my $b = nvec::new([0, 1]);
    
    approx_eq($a->cosine_similarity($b), 0.0, 'perpendicular 2D');
    
    my $c = nvec::new([1, 0, 0]);
    my $d = nvec::new([0, 1, 0]);
    
    approx_eq($c->cosine_similarity($d), 0.0, 'perpendicular 3D');
};

subtest 'cosine_similarity 45 degrees' => sub {
    my $a = nvec::new([1, 0]);
    my $b = nvec::new([1, 1]);
    
    # cos(45°) = 1/sqrt(2)
    approx_eq($a->cosine_similarity($b), 1/sqrt(2), '45 degree angle');
};

subtest 'cosine_similarity is symmetric' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([5, 6, 7, 8]);
    
    approx_eq($a->cosine_similarity($b), $b->cosine_similarity($a), 'symmetric');
};

subtest 'cosine_similarity with self' => sub {
    my $a = nvec::new([3, 4, 5]);
    
    approx_eq($a->cosine_similarity($a), 1.0, 'similarity with self = 1');
};

subtest 'linear algebra workflow' => sub {
    # Find angle between two vectors
    my $a = nvec::new([1, 0, 0]);
    my $b = nvec::new([1, 1, 0]);
    
    my $cos_theta = $a->cosine_similarity($b);
    my $theta = atan2(sqrt(1 - $cos_theta**2), $cos_theta);  # radians
    
    approx_eq($theta, 3.14159265358979/4, 'angle is 45 degrees (pi/4)');
};

subtest 'projection' => sub {
    # Project b onto a: proj = (a·b / a·a) * a
    my $a = nvec::new([2, 0]);
    my $b = nvec::new([3, 4]);
    
    my $scalar = $a->dot($b) / $a->dot($a);
    my $proj = $a->scale($scalar);
    
    is_deeply($proj->to_array, [3, 0], 'projection of (3,4) onto x-axis');
};

subtest 'gram-schmidt first step' => sub {
    # Orthogonalize b with respect to a
    my $a = nvec::new([1, 1])->normalize;
    my $b = nvec::new([1, 0]);
    
    # b_orth = b - (a·b)*a
    my $proj_scalar = $a->dot($b);
    my $proj = $a->scale($proj_scalar);
    my $b_orth = $b->sub($proj);
    
    # Check orthogonality
    approx_eq($a->dot($b_orth), 0, 'orthogonalized vector is perpendicular');
};

done_testing;

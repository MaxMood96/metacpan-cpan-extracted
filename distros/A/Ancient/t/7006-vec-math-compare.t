#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('nvec');

my $eps = 1e-10;
my $PI = 3.14159265358979;

sub approx_eq {
    my ($a, $b, $msg) = @_;
    ok(abs($a - $b) < $eps, $msg // "approx equal: $a ≈ $b");
}

# ============================================
# Math Functions
# ============================================

subtest 'pow' => sub {
    my $v = nvec::new([1, 2, 3, 4]);
    my $sq = $v->pow(2);
    is_deeply($sq->to_array, [1, 4, 9, 16], 'square');
    
    my $cube = $v->pow(3);
    is_deeply($cube->to_array, [1, 8, 27, 64], 'cube');
    
    my $sqrt = nvec::new([4, 9, 16])->pow(0.5);
    is_deeply($sqrt->to_array, [2, 3, 4], 'sqrt via pow');
};

subtest 'exp' => sub {
    my $v = nvec::new([0, 1, 2]);
    my $e = $v->exp;
    approx_eq($e->get(0), 1, 'exp(0) = 1');
    approx_eq($e->get(1), exp(1), 'exp(1)');
    approx_eq($e->get(2), exp(2), 'exp(2)');
};

subtest 'log' => sub {
    my $v = nvec::new([1, exp(1), exp(2)]);
    my $l = $v->log;
    approx_eq($l->get(0), 0, 'log(1) = 0');
    approx_eq($l->get(1), 1, 'log(e) = 1');
    approx_eq($l->get(2), 2, 'log(e^2) = 2');
};

subtest 'sin' => sub {
    my $v = nvec::new([0, $PI/6, $PI/2, $PI]);
    my $s = $v->sin;
    approx_eq($s->get(0), 0, 'sin(0)');
    approx_eq($s->get(1), 0.5, 'sin(pi/6)');
    approx_eq($s->get(2), 1, 'sin(pi/2)');
    ok(abs($s->get(3)) < 1e-10, 'sin(pi) ≈ 0');
};

subtest 'cos' => sub {
    my $v = nvec::new([0, $PI/3, $PI/2, $PI]);
    my $c = $v->cos;
    approx_eq($c->get(0), 1, 'cos(0)');
    approx_eq($c->get(1), 0.5, 'cos(pi/3)');
    ok(abs($c->get(2)) < 1e-10, 'cos(pi/2) ≈ 0');
    approx_eq($c->get(3), -1, 'cos(pi)');
};

subtest 'tan' => sub {
    my $v = nvec::new([0, $PI/4]);
    my $t = $v->tan;
    approx_eq($t->get(0), 0, 'tan(0)');
    approx_eq($t->get(1), 1, 'tan(pi/4)');
};

subtest 'floor' => sub {
    my $v = nvec::new([1.1, 2.9, -1.1, -2.9]);
    is_deeply($v->floor->to_array, [1, 2, -2, -3], 'floor');
};

subtest 'ceil' => sub {
    my $v = nvec::new([1.1, 2.9, -1.1, -2.9]);
    is_deeply($v->ceil->to_array, [2, 3, -1, -2], 'ceil');
};

subtest 'round' => sub {
    my $v = nvec::new([1.4, 1.5, 2.5, -1.5]);
    my $r = $v->round;
    is($r->get(0), 1, 'round(1.4)');
    is($r->get(1), 2, 'round(1.5)');
    is($r->get(2), 3, 'round(2.5) - banker rounds to even');
};

# ============================================
# Comparison
# ============================================

subtest 'eq' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([1, 0, 3, 0]);
    is_deeply($a->eq($b)->to_array, [1, 0, 1, 0], 'eq');
};

subtest 'ne' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([1, 0, 3, 0]);
    is_deeply($a->ne($b)->to_array, [0, 1, 0, 1], 'ne');
};

subtest 'lt' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([2, 2, 2, 2]);
    is_deeply($a->lt($b)->to_array, [1, 0, 0, 0], 'lt');
};

subtest 'le' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([2, 2, 2, 2]);
    is_deeply($a->le($b)->to_array, [1, 1, 0, 0], 'le');
};

subtest 'gt' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([2, 2, 2, 2]);
    is_deeply($a->gt($b)->to_array, [0, 0, 1, 1], 'gt');
};

subtest 'ge' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    my $b = nvec::new([2, 2, 2, 2]);
    is_deeply($a->ge($b)->to_array, [0, 1, 1, 1], 'ge');
};

# ============================================
# Selection and Utility
# ============================================

subtest 'reverse' => sub {
    my $v = nvec::new([1, 2, 3, 4, 5]);
    is_deeply($v->reverse->to_array, [5, 4, 3, 2, 1], 'reverse');
    
    my $single = nvec::new([42]);
    is_deeply($single->reverse->to_array, [42], 'reverse single');
};

subtest 'concat' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([4, 5, 6]);
    is_deeply($a->concat($b)->to_array, [1, 2, 3, 4, 5, 6], 'concat');
    
    my $empty = nvec::new([]);
    is_deeply($a->concat($empty)->to_array, [1, 2, 3], 'concat with empty');
};

subtest 'any' => sub {
    ok(nvec::new([0, 0, 1, 0])->any, 'any with one nonzero');
    ok(!nvec::new([0, 0, 0, 0])->any, 'any with all zero');
    ok(nvec::new([1, 1, 1])->any, 'any with all nonzero');
    ok(!nvec::new([])->any, 'any empty');
};

subtest 'all' => sub {
    ok(nvec::new([1, 2, 3, 4])->all, 'all nonzero');
    ok(!nvec::new([1, 0, 3, 4])->all, 'all with one zero');
    ok(!nvec::new([0, 0, 0])->all, 'all zeros');
    ok(nvec::new([])->all, 'all empty is true');
};

subtest 'count' => sub {
    is(nvec::new([0, 1, 0, 2, 0, 3])->count, 3, 'count nonzero');
    is(nvec::new([0, 0, 0])->count, 0, 'count all zeros');
    is(nvec::new([1, 1, 1])->count, 3, 'count all nonzero');
};

subtest 'where' => sub {
    my $v = nvec::new([10, 20, 30, 40, 50]);
    my $mask = nvec::new([1, 0, 1, 0, 1]);
    is_deeply($v->where($mask)->to_array, [10, 30, 50], 'where with mask');
    
    # Combine with comparison
    my $threshold = nvec::fill(5, 25);
    my $above = $v->gt($threshold);
    is_deeply($v->where($above)->to_array, [30, 40, 50], 'where with comparison');
};

subtest 'random' => sub {
    my $r = nvec::random(100);
    is($r->len, 100, 'random length');
    ok($r->min >= 0, 'random min >= 0');
    ok($r->max < 1, 'random max < 1');
};

# ============================================
# Combined workflows
# ============================================

subtest 'numpy-style workflow' => sub {
    # Filter values > 0.5 and apply log
    my $data = nvec::new([0.1, 0.6, 0.3, 0.8, 0.2, 0.9]);
    my $threshold = nvec::fill(6, 0.5);
    my $mask = $data->gt($threshold);
    my $filtered = $data->where($mask);
    is($filtered->len, 3, 'filtered length');
    
    my $log_vals = $filtered->log;
    ok($log_vals->get(0) < 0, 'log of < 1 is negative');
};

subtest 'signal processing' => sub {
    # Create sine wave
    my $n = 100;
    my $t = nvec::linspace(0, 2 * $PI, $n);
    my $wave = $t->sin;
    
    ok($wave->max <= 1.001, 'sin max');
    ok($wave->min >= -1.001, 'sin min');
    
    # Find zero crossings (approximately)
    my $zeros = $wave->abs->lt(nvec::fill($n, 0.1));
    ok($zeros->count > 0, 'found zero crossings');
};

done_testing;

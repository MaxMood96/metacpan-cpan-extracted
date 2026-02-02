#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('nvec');

subtest 'add variations' => sub {
    my $a = nvec::new([1, 2, 3, 4, 5]);
    my $b = nvec::new([10, 20, 30, 40, 50]);
    
    my $c = $a->add($b);
    is_deeply($c->to_array, [11, 22, 33, 44, 55], 'basic add');
    is_deeply($a->to_array, [1, 2, 3, 4, 5], 'a unchanged after add');
    is_deeply($b->to_array, [10, 20, 30, 40, 50], 'b unchanged after add');
};

subtest 'sub variations' => sub {
    my $a = nvec::new([10, 20, 30]);
    my $b = nvec::new([1, 2, 3]);
    
    my $c = $a->sub($b);
    is_deeply($c->to_array, [9, 18, 27], 'basic sub');
    
    my $d = $b->sub($a);
    is_deeply($d->to_array, [-9, -18, -27], 'negative sub');
};

subtest 'mul variations' => sub {
    my $a = nvec::new([2, 3, 4]);
    my $b = nvec::new([5, 6, 7]);
    
    my $c = $a->mul($b);
    is_deeply($c->to_array, [10, 18, 28], 'element-wise mul');
    
    my $zeros = nvec::zeros(3);
    my $d = $a->mul($zeros);
    is_deeply($d->to_array, [0, 0, 0], 'mul by zeros');
};

subtest 'div variations' => sub {
    my $a = nvec::new([10, 20, 30]);
    my $b = nvec::new([2, 4, 5]);
    
    my $c = $a->div($b);
    is_deeply($c->to_array, [5, 5, 6], 'element-wise div');
    
    my $ones = nvec::ones(3);
    my $d = $a->div($ones);
    is_deeply($d->to_array, [10, 20, 30], 'div by ones');
};

subtest 'scale' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    
    my $b = $a->scale(2);
    is_deeply($b->to_array, [2, 4, 6, 8], 'scale by 2');
    
    my $c = $a->scale(0);
    is_deeply($c->to_array, [0, 0, 0, 0], 'scale by 0');
    
    my $d = $a->scale(-1);
    is_deeply($d->to_array, [-1, -2, -3, -4], 'scale by -1');
    
    my $e = $a->scale(0.5);
    is_deeply($e->to_array, [0.5, 1, 1.5, 2], 'scale by 0.5');
};

subtest 'add_scalar' => sub {
    my $a = nvec::new([1, 2, 3]);
    
    my $b = $a->add_scalar(10);
    is_deeply($b->to_array, [11, 12, 13], 'add_scalar positive');
    
    my $c = $a->add_scalar(-5);
    is_deeply($c->to_array, [-4, -3, -2], 'add_scalar negative');
};

subtest 'neg' => sub {
    # Use vectors without 0 to avoid -0 vs 0 comparison issues
    my $a = nvec::new([1, -2, 3, -4, 5]);
    my $b = $a->neg;
    is_deeply($b->to_array, [-1, 2, -3, 4, -5], 'neg flips signs');

    my $c = $b->neg;
    is_deeply($c->to_array, [1, -2, 3, -4, 5], 'double neg returns original');

    # Test zero separately with numeric comparison (handles -0 == 0)
    my $z = nvec::new([0]);
    my $nz = $z->neg;
    ok($nz->get(0) == 0, 'neg of zero is zero');
};

subtest 'abs' => sub {
    my $a = nvec::new([-1, 2, -3, 4, -5]);
    my $b = $a->abs;
    is_deeply($b->to_array, [1, 2, 3, 4, 5], 'abs makes all positive');
    
    my $c = nvec::new([0, 0, 0]);
    is_deeply($c->abs->to_array, [0, 0, 0], 'abs of zeros');
};

subtest 'sqrt' => sub {
    my $a = nvec::new([0, 1, 4, 9, 16, 25]);
    my $b = $a->sqrt;
    is_deeply($b->to_array, [0, 1, 2, 3, 4, 5], 'sqrt of perfect squares');
    
    my $c = nvec::new([2]);
    my $d = $c->sqrt;
    ok(abs($d->get(0) - sqrt(2)) < 1e-10, 'sqrt of 2');
};

subtest 'chained operations' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([4, 5, 6]);
    
    # (a + b) * 2
    my $c = $a->add($b)->scale(2);
    is_deeply($c->to_array, [10, 14, 18], 'add then scale');
    
    # sqrt(a * a + b * b) - Pythagorean
    my $d = $a->mul($a)->add($b->mul($b))->sqrt;
    ok(abs($d->get(0) - sqrt(17)) < 1e-10, 'sqrt(1+16)');
    ok(abs($d->get(1) - sqrt(29)) < 1e-10, 'sqrt(4+25)');
    ok(abs($d->get(2) - sqrt(45)) < 1e-10, 'sqrt(9+36)');
};

subtest 'large vector arithmetic' => sub {
    my $size = 10000;
    my $a = nvec::ones($size);
    my $b = nvec::fill($size, 2);
    
    my $c = $a->add($b);
    is($c->sum, 30000, 'sum of 10000 threes');
    
    my $d = $b->mul($b);
    is($d->sum, 40000, 'sum of 10000 fours');
};

done_testing;

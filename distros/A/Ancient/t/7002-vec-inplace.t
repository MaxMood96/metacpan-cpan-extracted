#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('nvec');

subtest 'add_inplace basic' => sub {
    my $a = nvec::new([1, 2, 3]);
    my $b = nvec::new([10, 20, 30]);
    
    my $ret = $a->add_inplace($b);
    is($ret, $a, 'add_inplace returns self');
    is_deeply($a->to_array, [11, 22, 33], 'a modified in place');
    is_deeply($b->to_array, [10, 20, 30], 'b unchanged');
};

subtest 'add_inplace chained' => sub {
    my $a = nvec::new([1, 1, 1]);
    my $b = nvec::new([2, 2, 2]);
    my $c = nvec::new([3, 3, 3]);
    
    $a->add_inplace($b)->add_inplace($c);
    is_deeply($a->to_array, [6, 6, 6], 'chained add_inplace');
};

subtest 'scale_inplace basic' => sub {
    my $a = nvec::new([1, 2, 3, 4]);
    
    my $ret = $a->scale_inplace(2);
    is($ret, $a, 'scale_inplace returns self');
    is_deeply($a->to_array, [2, 4, 6, 8], 'a scaled in place');
};

subtest 'scale_inplace by zero' => sub {
    my $a = nvec::new([1, 2, 3]);
    $a->scale_inplace(0);
    is_deeply($a->to_array, [0, 0, 0], 'scale by zero');
};

subtest 'scale_inplace by negative' => sub {
    my $a = nvec::new([1, 2, 3]);
    $a->scale_inplace(-1);
    is_deeply($a->to_array, [-1, -2, -3], 'scale by -1');
};

subtest 'clamp_inplace basic' => sub {
    my $a = nvec::new([-5, 0, 5, 10, 15]);
    
    my $ret = $a->clamp_inplace(0, 10);
    is($ret, $a, 'clamp_inplace returns self');
    is_deeply($a->to_array, [0, 0, 5, 10, 10], 'values clamped');
};

subtest 'clamp_inplace edge cases' => sub {
    my $a = nvec::new([1, 2, 3, 4, 5]);
    
    # Clamp where all values are in range
    $a->clamp_inplace(0, 10);
    is_deeply($a->to_array, [1, 2, 3, 4, 5], 'all in range unchanged');
    
    # Clamp to single value
    my $b = nvec::new([1, 2, 3, 4, 5]);
    $b->clamp_inplace(3, 3);
    is_deeply($b->to_array, [3, 3, 3, 3, 3], 'clamp to single value');
};

subtest 'clamp_inplace with negative range' => sub {
    my $a = nvec::new([-10, -5, 0, 5, 10]);
    $a->clamp_inplace(-3, 3);
    is_deeply($a->to_array, [-3, -3, 0, 3, 3], 'clamp with negative bounds');
};

subtest 'combined inplace operations' => sub {
    my $a = nvec::new([1, 2, 3, 4, 5]);
    my $b = nvec::ones(5);
    
    # (a + 1) * 2, clamped to [0, 8]
    $a->add_inplace($b)->scale_inplace(2)->clamp_inplace(0, 8);
    is_deeply($a->to_array, [4, 6, 8, 8, 8], 'combined operations');
};

subtest 'inplace with large vectors' => sub {
    my $size = 10000;
    my $a = nvec::range(0, $size);  # 0..9999
    my $ones = nvec::ones($size);
    
    $a->add_inplace($ones);
    is($a->get(0), 1, 'first element incremented');
    is($a->get($size - 1), 10000, 'last element incremented');
    
    $a->scale_inplace(0.5);
    is($a->get(0), 0.5, 'first element scaled');
    is($a->get($size - 1), 5000, 'last element scaled');
};

subtest 'inplace vs copy comparison' => sub {
    my @values = (1, 2, 3, 4, 5);
    
    # Copy version
    my $a = nvec::new(\@values);
    my $b = nvec::new([10, 10, 10, 10, 10]);
    my $copy_result = $a->add($b);
    
    # Inplace version
    my $c = nvec::new(\@values);
    my $d = nvec::new([10, 10, 10, 10, 10]);
    $c->add_inplace($d);
    
    is_deeply($copy_result->to_array, $c->to_array, 'copy and inplace give same result');
    is_deeply($a->to_array, \@values, 'copy version leaves original unchanged');
};

done_testing;

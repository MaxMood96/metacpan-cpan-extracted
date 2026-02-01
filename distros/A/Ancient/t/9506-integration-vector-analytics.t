#!/usr/bin/env perl
# Integration test: nvec + util + const for vector-based analytics
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use nvec;
use util;
use const;

subtest 'basic statistics' => sub {
    my $data = nvec::new([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
    
    is($data->len, 10, 'length is 10');
    is($data->sum, 550, 'sum is 550');
    is($data->mean, 55, 'mean is 55');
    is($data->min, 10, 'min is 10');
    is($data->max, 100, 'max is 100');
};

subtest 'normalization' => sub {
    my $data = nvec::new([10, 20, 30, 40, 50]);
    
    my $mean = $data->mean;
    my $normalized = $data->scale(1 / $mean);
    
    ok(abs($normalized->mean - 1) < 0.001, 'normalized mean is ~1');
};

subtest 'threshold filtering' => sub {
    my @raw = (5, 15, 25, 35, 45, 55, 65, 75, 85, 95);
    
    my @above = grep { $_ > 50 } @raw;
    
    my $high_values = nvec::new(\@above);
    is($high_values->len, 5, '5 values above threshold');
    is($high_values->min, 55, 'min of filtered is 55');
};

subtest 'range clamping' => sub {
    my @raw = (0, 25, 50, 75, 100, 125, 150);
    
    # Use explicit scalar to avoid clamp context issues
    my @clamped = map { my $v = util::clamp($_, 20, 80); $v } @raw;
    my $clamped_vec = nvec::new(\@clamped);
    
    is($clamped_vec->min, 20, 'clamped min is 20');
    is($clamped_vec->max, 80, 'clamped max is 80');
    is($clamped[1], 25, 'value 25 unchanged');
    is($clamped[2], 50, 'value 50 unchanged');
    is($clamped[3], 75, 'value 75 unchanged');
};

subtest 'immutable results' => sub {
    my $data = nvec::new([1, 2, 3, 4, 5]);
    
    my $stats = const::c({
        sum  => $data->sum,
        mean => $data->mean,
        len  => $data->len,
    });
    
    ok(const::is_readonly($stats->{sum}), 'stats values are frozen');
    is($stats->{sum}, 15, 'frozen sum value correct');
    is($stats->{mean}, 3, 'frozen mean value correct');
    is($stats->{len}, 5, 'frozen len value correct');
};

subtest 'chained transformations' => sub {
    my $original = nvec::new([1, 2, 3, 4, 5]);
    my $result = $original->scale(10)->add_scalar(5);
    
    is_deeply($result->to_array, [15, 25, 35, 45, 55], 'chained operations correct');
    is_deeply($original->to_array, [1, 2, 3, 4, 5], 'original unchanged');
};

subtest 'dot product and norm' => sub {
    my $v1 = nvec::new([1, 0, 0]);
    my $v2 = nvec::new([0, 1, 0]);
    my $v3 = nvec::new([1, 1, 0]);
    
    is($v1->dot($v2), 0, 'orthogonal vectors dot = 0');
    ok($v1->dot($v3) > 0, 'same direction has positive dot');
    
    my $unit = nvec::new([1, 0, 0]);
    ok(abs($unit->norm - 1) < 0.001, 'unit vector norm is 1');
    
    my $v345 = nvec::new([3, 4, 0]);
    ok(abs($v345->norm - 5) < 0.001, '3-4-5 triangle norm is 5');
};

subtest 'partition analysis' => sub {
    my @values = (10, 20, 30, 40, 50, 60, 70, 80, 90, 100);
    
    my $parts = util::partition(sub { $_ < 55 }, @values);
    my ($below, $above) = @$parts;
    
    my $below_vec = nvec::new($below);
    my $above_vec = nvec::new($above);
    
    is($below_vec->len, 5, '5 values below median');
    is($above_vec->len, 5, '5 values above median');
    ok($below_vec->mean < $above_vec->mean, 'below group has lower mean');
};

done_testing();

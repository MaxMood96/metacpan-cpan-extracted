#!/usr/bin/env perl
# Integration test: nvec + util + const for data processing pipelines
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use nvec;
use util;
use const;

subtest 'filter and transform' => sub {
    my @raw_data = (1, -2, 3, -4, 5, -6, 7, -8, 9, -10);
    
    my @positives = grep { util::is_positive($_) } @raw_data;
    is_deeply(\@positives, [1, 3, 5, 7, 9], 'util::is_positive filters correctly');
    
    my $v = nvec::new(\@positives);
    is($v->len, 5, 'nvec created with correct length');
    
    my $scaled = $v->scale(2);
    is_deeply($scaled->to_array, [2, 6, 10, 14, 18], 'nvec scale works');
    
    my $frozen = const::c($scaled->to_array);
    ok(const::is_readonly(@{$frozen}), 'result arrayref is frozen');
};

subtest 'statistics with predicates' => sub {
    my $data = nvec::new([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
    
    my $mean = $data->mean;
    my $sum = $data->sum;
    
    ok(util::is_positive($mean), 'mean is positive');
    ok(util::is_between($mean, 50, 60), 'mean is between 50 and 60');
    is($sum, 550, 'sum is correct');
    
    my $clamped = util::clamp($mean, 0, 50);
    is($clamped, 50, 'mean clamped to max 50');
};

subtest 'chained vector operations' => sub {
    my $v = nvec::new([1, 2, 3, 4, 5]);
    my $result = $v->scale(10)->add_scalar(5);
    is_deeply($result->to_array, [15, 25, 35, 45, 55], 'chained transforms correctly');
};

subtest 'partition and aggregate' => sub {
    my @numbers = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    
    my $parts = util::partition(sub { $_ % 2 == 0 }, @numbers);
    my ($evens, $odds) = @$parts;
    
    my $even_vec = nvec::new($evens);
    my $odd_vec = nvec::new($odds);
    
    ok($even_vec->mean > $odd_vec->mean, 'even mean > odd mean');
    is($even_vec->sum, 30, 'even sum = 30');
    is($odd_vec->sum, 25, 'odd sum = 25');
};

done_testing();

package Integration::DataPipeline;
# Integration test: nvec + util + const for data processing pipelines
use strict;
use warnings;
use Test::More;
use Exporter 'import';

our @EXPORT_OK = qw(run_tests);

use nvec;
use util;
use const;

sub run_tests {
    subtest 'data pipeline: filter and transform' => sub {
        # Create sample data
        my @raw_data = (1, -2, 3, -4, 5, -6, 7, -8, 9, -10);
        
        # Use util to filter positive values
        my @positives = grep { util::is_positive($_) } @raw_data;
        is_deeply(\@positives, [1, 3, 5, 7, 9], 'util::is_positive filters correctly');
        
        # Create nvec from filtered data
        my $v = nvec::new(\@positives);
        is($v->len, 5, 'nvec created with correct length');
        
        # Transform with nvec operations (returns new vector)
        my $scaled = $v->scale(2);
        my $arr = $scaled->to_array;
        is_deeply($arr, [2, 6, 10, 14, 18], 'nvec scale works');
        
        # Make result immutable with const::c (works with references)
        my $frozen = const::c($arr);
        ok(const::is_readonly($frozen), 'result arrayref is frozen');
    };

    subtest 'data pipeline: statistics with predicates' => sub {
        my $data = nvec::new([10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);
        
        # Get statistics
        my $mean = $data->mean;
        my $sum = $data->sum;
        
        # Use util predicates on results
        ok(util::is_positive($mean), 'mean is positive');
        ok(util::is_between($mean, 50, 60), 'mean is between 50 and 60');
        is($sum, 550, 'sum is correct');
        
        # Use util::clamp on computed values
        my $clamped = util::clamp($mean, 0, 50);
        is($clamped, 50, 'mean clamped to max 50');
    };

    subtest 'data pipeline: chained vector operations' => sub {
        my $v = nvec::new([1, 2, 3, 4, 5]);
        
        # Chain operations (each returns new vector)
        my $result = $v->scale(10)->add_scalar(5);
        
        is_deeply($result->to_array, [15, 25, 35, 45, 55], 'chained transforms correctly');
    };

    subtest 'data pipeline: partition and aggregate' => sub {
        my @numbers = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
        
        # Partition into evens and odds
        my $parts = util::partition(sub { $_ % 2 == 0 }, @numbers);
        my ($evens, $odds) = @$parts;
        
        # Create nvecs for each partition
        my $even_vec = nvec::new($evens);
        my $odd_vec = nvec::new($odds);
        
        # Compare statistics
        ok($even_vec->mean > $odd_vec->mean, 'even mean > odd mean');
        is($even_vec->sum, 30, 'even sum = 30');
        is($odd_vec->sum, 25, 'odd sum = 25');
    };
}

1;

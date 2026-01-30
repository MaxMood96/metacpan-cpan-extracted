#!/usr/bin/env perl
#
# Basic usage example of the Algorithm::TimelinePacking module
#
use strict;
use warnings;
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Algorithm::TimelinePacking;
use Data::Dumper;

# Create timeline with minimum spacing of 5 units between jobs
my $timeline = Algorithm::TimelinePacking->new(space => 5);

# Sample job data: [start, end, jobid, user, maps, reduces]
my @slices = (
    [1000, 1200, 'job_001', 'alice', 100, 10],
    [1100, 1300, 'job_002', 'bob',   200, 20],  # overlaps with job_001
    [1150, 1400, 'job_003', 'carol', 150, 15],  # overlaps with both
    [1500, 1600, 'job_004', 'alice', 300, 30],  # no overlap
    [1550, 1700, 'job_005', 'dave',  250, 25],  # overlaps with job_004
);

print "Input slices:\n";
for my $s (@slices) {
    printf "  [%4d - %4d] %-8s %s\n", $s->[0], $s->[1], $s->[2], $s->[3];
}

# Arrange slices into non-overlapping lines
my ($lines, $latest) = $timeline->arrange_slices(\@slices);

print "\nArranged into ", scalar(@$lines), " lines:\n";
print "Latest timestamp (normalized): $latest\n\n";

for my $i (0 .. $#$lines) {
    print "Line $i:\n";
    for my $slice (@{$lines->[$i]}) {
        printf "  [%4d - %4d] %-8s %s (maps: %d)\n",
            $slice->[0], $slice->[1], $slice->[2], $slice->[3], $slice->[4];
    }
}

#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Algorithm::TimelinePacking;

subtest 'single slice' => sub {
    my $t = Algorithm::TimelinePacking->new;
    my $slices = [[100, 200, 'job1', 'alice', 500, 10]];
    my ($lines, $latest) = $t->arrange_slices($slices);

    is($latest, 100, 'latest is normalized end time');
    is(scalar @$lines, 1, 'single slice produces one line');
    is(scalar @{$lines->[0]}, 1, 'line contains one slice');
    is($lines->[0][0][0], 0, 'start normalized to 0');
    is($lines->[0][0][1], 100, 'end normalized correctly');
};

subtest 'non-overlapping slices' => sub {
    my $t = Algorithm::TimelinePacking->new;
    my $slices = [
        [100, 200, 'job1', 'alice', 500, 10],
        [300, 400, 'job2', 'bob', 600, 20],
        [500, 600, 'job3', 'carol', 700, 30],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    is($latest, 500, 'latest is max normalized end time');

    # All slices should fit on one line (after shuffle, count total slices)
    my $total_slices = 0;
    $total_slices += scalar @$_ for @$lines;
    is($total_slices, 3, 'all slices accounted for');

    # With no overlap, should fit on single line
    is(scalar @$lines, 1, 'non-overlapping slices fit on one line');
};

subtest 'overlapping slices need multiple lines' => sub {
    my $t = Algorithm::TimelinePacking->new;
    my $slices = [
        [100, 300, 'job1', 'alice', 500, 10],
        [200, 400, 'job2', 'bob', 600, 20],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    is($latest, 300, 'latest is normalized end time');
    is(scalar @$lines, 2, 'overlapping slices need two lines');

    my $total_slices = 0;
    $total_slices += scalar @$_ for @$lines;
    is($total_slices, 2, 'all slices accounted for');
};

subtest 'three overlapping slices' => sub {
    my $t = Algorithm::TimelinePacking->new;
    my $slices = [
        [100, 400, 'job1', 'alice', 500, 10],
        [200, 500, 'job2', 'bob', 600, 20],
        [300, 600, 'job3', 'carol', 700, 30],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    is(scalar @$lines, 3, 'three overlapping slices need three lines');
};

subtest 'space parameter prevents close placement' => sub {
    my $t = Algorithm::TimelinePacking->new(space => 50);
    my $slices = [
        [100, 200, 'job1', 'alice', 500, 10],
        [210, 300, 'job2', 'bob', 600, 20],  # starts 10 after job1 ends
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    # With space=50, job2 can't be on same line as job1
    # (job1 ends at 100, job2 starts at 110, gap is only 10)
    is(scalar @$lines, 2, 'space parameter forces separate lines');
};

subtest 'space parameter allows distant placement' => sub {
    my $t = Algorithm::TimelinePacking->new(space => 50);
    my $slices = [
        [100, 200, 'job1', 'alice', 500, 10],
        [300, 400, 'job2', 'bob', 600, 20],  # starts 100 after job1 ends
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    # With space=50, job2 can be on same line (gap is 100)
    is(scalar @$lines, 1, 'sufficient gap allows same line');
};

subtest 'width normalization' => sub {
    my $t = Algorithm::TimelinePacking->new(width => 1000);
    my $slices = [
        [0, 500, 'job1', 'alice', 500, 10],
        [500, 1000, 'job2', 'bob', 600, 20],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    # Original span is 1000, width is 1000, so no scaling needed
    # But slices are floored, check they fit in width
    my $max_end = 0;
    for my $line (@$lines) {
        for my $slice (@$line) {
            $max_end = $slice->[1] if $slice->[1] > $max_end;
        }
    }
    ok($max_end <= 1000, 'all slices fit within width');
};

subtest 'width scaling' => sub {
    my $t = Algorithm::TimelinePacking->new(width => 500);
    my $slices = [
        [0, 500, 'job1', 'alice', 500, 10],
        [500, 1000, 'job2', 'bob', 600, 20],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    my $max_end = 0;
    for my $line (@$lines) {
        for my $slice (@$line) {
            $max_end = $slice->[1] if $slice->[1] > $max_end;
        }
    }
    ok($max_end <= 500, 'slices scaled to fit width');
};

subtest 'zero-duration slices get minimum width' => sub {
    my $t = Algorithm::TimelinePacking->new(width => 100);
    my $slices = [
        [0, 0, 'job1', 'alice', 500, 10],  # zero duration
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    my $slice = $lines->[0][0];
    ok($slice->[1] > $slice->[0], 'zero-duration slice gets minimum width');
};

subtest 'preserves metadata' => sub {
    my $t = Algorithm::TimelinePacking->new;
    my $slices = [
        [100, 200, 'job1', 'alice', 500, 10],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    my $slice = $lines->[0][0];
    is($slice->[2], 'job1', 'jobid preserved');
    is($slice->[3], 'alice', 'user preserved');
    is($slice->[4], 500, 'maps preserved');
    is($slice->[5], 10, 'reduces preserved');
};

subtest 'sorting by start time' => sub {
    my $t = Algorithm::TimelinePacking->new;
    my $slices = [
        [300, 400, 'job3', 'carol', 700, 30],
        [100, 200, 'job1', 'alice', 500, 10],
        [200, 300, 'job2', 'bob', 600, 20],
    ];
    my ($lines, $latest) = $t->arrange_slices($slices);

    # All should fit on one line in order
    is(scalar @$lines, 1, 'non-overlapping slices on one line');
    is(scalar @{$lines->[0]}, 3, 'all three slices present');
};

done_testing;

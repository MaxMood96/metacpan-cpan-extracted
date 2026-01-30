package Algorithm::TimelinePacking;

use strict;
use warnings;

use Moo;
use Types::Standard qw(Int Maybe);
use POSIX qw(floor);
use List::Util qw(max shuffle);

our $VERSION = '0.01';

# minimum space (in units, i.e. most frequently pixels) between 2 consecutive
# items on a line
has space => (
    is      => 'rw',
    isa     => Int->where('$_ >= 0'),
    default => 0,
);

# convert all epochs to end at this maximum. undef means no constraint
has width => (
    is      => 'rw',
    isa     => Maybe[ Int->where('$_ >= 0') ],
    default => undef,
);

sub arrange_slices {
    my $self   = shift;
    my $slices = shift;

    # sort the slices by ascending start timestamp, i.e leftmost slice will be
    # on the highest line. Also make the whole series start at 0, not the
    # actual timestamp.
    @$slices = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @$slices;
    my $earliest = $slices->[0][0];
    @$slices = map { $_->[0] -= $earliest, $_->[1] -= $earliest; $_ } @$slices;
    my $latest = max map { $_->[1] } @$slices;

    if ($self->width && $latest > 0) {
        my $factor = $self->width / $latest;
        # rework the epochs so they fit within width
        for (@$slices) {
            $_->[0] = floor($_->[0] *= $factor);
            $_->[1] = floor($_->[1] *= $factor);
            $_->[1]++ if $_->[1] == $_->[0]; # no invisibles
        }
    }
    elsif ($self->width && $latest == 0) {
        # all slices are zero-duration points; give them minimum width
        $_->[1] = 1 for @$slices;
    }

    my $lines = [ [] ];

    # Track where each line ends. Initialize line 0 with a negative value
    # so the first slice always fits. Without this, if space=10 and first
    # slice starts at 0, the check (0 + 10 <= 0) would fail and create an
    # unnecessary extra line. The -space value makes (−10 + 10 <= 0) pass.
    my $ends = { 0 => -$self->space };

    # for every slice, try to put it in on the line that has the leftmost end
    while ( my $slice = shift @$slices ) {

        # find which line has the leftmost end that allows placement of our
        # slice (line must end before slice starts, with required spacing)
        my ($line_index) = grep { $ends->{$_} + $self->space <= $slice->[0] }
            sort { $ends->{$a} <=> $ends->{$b} } keys %$ends;

        # if no suitable line was found, create a new one
        $line_index //= $#$lines + 1;

        # add the slice to the right line, and update the end point for that
        # one
        push @{ $lines->[$line_index] }, $slice;
        $ends->{$line_index} = $slice->[1];
    }
    # randomizing the ordering gives a more balanced look
    @$lines = shuffle @$lines;
    return $lines, $latest;
}

1;

__END__

=encoding UTF-8

=head1 NAME

Algorithm::TimelinePacking - Arrange time intervals into non-overlapping lines

=begin markdown

## Example Output

The module arranges overlapping time intervals into non-overlapping rows,
perfect for Gantt-style visualizations:

![Hadoop jobs timeline](images/hadoop-jobs-example.png)

*75 Hadoop MapReduce jobs arranged into 11 parallel execution lanes.
See `examples/hadoop-jobs.html` for the full demo.*

=end markdown

=head1 SYNOPSIS

    use Algorithm::TimelinePacking;

    my $packer = Algorithm::TimelinePacking->new(
        space => 5,      # minimum gap between intervals on same line
        width => 1000,   # optional: scale output to fit this width
    );

    # Each slice: [start, end, ...metadata]
    my @slices = (
        [1000, 1200, 'job1', 'alice'],
        [1100, 1300, 'job2', 'bob'],    # overlaps with job1
        [1500, 1600, 'job3', 'carol'],
    );

    my ($lines, $latest) = $packer->arrange_slices(\@slices);

    # $lines is an arrayref of arrayrefs, each containing non-overlapping slices
    # $latest is the normalized end timestamp

=head1 DESCRIPTION

Algorithm::TimelinePacking solves the interval graph coloring problem: given a
set of potentially overlapping time intervals, it assigns them to the minimum
number of "lines" (rows) such that no two intervals on the same line overlap.

Originally developed to visualize Hadoop MapReduce job execution timelines,
the algorithm is completely generic and works for any Gantt-style visualization:
conference schedules, meeting room allocation, project timelines, TV programming,
resource booking systems, or any scenario with overlapping time ranges.

The algorithm uses a greedy first-fit approach, placing each interval on the
first available line where it fits without overlap.

=head1 EXAMPLES

=head2 Conference Schedule

Arrange talks into rooms so no two talks overlap in the same room:

    use Algorithm::TimelinePacking;

    my $packer = Algorithm::TimelinePacking->new(space => 15);  # 15 min between talks

    # Talks: [start_minutes, end_minutes, title, speaker, track]
    my @talks = (
        [540,  600, 'Opening Keynote',       'Margot Tenenbaum', 'keynote'],
        [600,  645, 'GopherScript for Beginners', 'Kevin McCallister', 'beginner'],
        [600,  645, 'Advanced Burrow Patterns',   'Ferris Mueller', 'advanced'],
        [600,  690, 'Workshop: Testing',     'Beatrix Bourbon', 'workshop'],
        [660,  705, 'Database Wrangling',    'Chester Copperpot', 'beginner'],
        [660,  705, 'Unsafe Memory Access',  'Wanda Maximoff', 'advanced'],
        [720,  780, 'Lunch',                 '',        'break'],
        [780,  825, 'Async/Await Deep Dive', 'Inigo Montoya', 'advanced'],
        [780,  870, 'Workshop: Web Apps',    'Rufus Firefly', 'workshop'],
        [840,  900, 'Closing Panel',         'Various', 'keynote'],
    );

    my ($rooms, $end) = $packer->arrange_slices(\@talks);

    for my $i (0 .. $#$rooms) {
        print "Room ", $i + 1, ":\n";
        for my $talk (@{$rooms->[$i]}) {
            printf "  %02d:%02d - %s (%s)\n",
                int($talk->[0] / 60), $talk->[0] % 60,
                $talk->[2], $talk->[3];
        }
    }

    # Output shows minimum rooms needed, with no scheduling conflicts

=head2 Hadoop Job Timeline

The original use case - visualize MapReduce job execution:

    my @jobs = (
        [$start_epoch, $end_epoch, $job_id, $user, $map_tasks, $reduce_tasks],
        ...
    );

    my ($lines, $latest) = $packer->arrange_slices(\@jobs);
    # Feed $lines to D3.js or other visualization library

=head1 ATTRIBUTES

=head2 space

    my $packer = Algorithm::TimelinePacking->new(space => 10);

Minimum space (in the same units as your timestamps) required between
consecutive intervals on the same line. Default: 0.

=head2 width

    my $packer = Algorithm::TimelinePacking->new(width => 800);

If set, all intervals will be scaled to fit within this width. The scaling
preserves relative positions and durations. Default: undef (no scaling).

=head1 METHODS

=head2 arrange_slices

    my ($lines, $latest) = $packer->arrange_slices(\@slices);

Takes an arrayref of slices and returns:

=over 4

=item * C<$lines> - arrayref of lines, each containing non-overlapping slices

=item * C<$latest> - the normalized maximum end timestamp

=back

Each input slice must be an arrayref where the first two elements are
start and end timestamps. Additional elements (metadata) are preserved.

    [start, end, ...optional_metadata]

The slices are modified in place (normalized to start at 0, optionally scaled).

=head1 ALGORITHM

The packing uses a greedy first-fit approach:

=over 4

=item 1.

Sort intervals by start time (secondary sort by end time)

=item 2.

Normalize all timestamps to start at 0

=item 3.

Optionally scale to fit within specified width

=item 4.

For each interval, place it on the first line where it fits

=item 5.

If no line has room, create a new line

=item 6.

Shuffle the final line order for visual balance

=back

Time complexity: O(n² log n) where n is the number of intervals.

=head1 AUTHOR

David Morel <david.morel@amakuru.net>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

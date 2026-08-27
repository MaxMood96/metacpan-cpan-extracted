package Punk::Observe::Retain;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Retain - compaction, rollups and deletion

=head1 SYNOPSIS

    use Punk::Observe::Retain;

    my $s = Punk::Observe::Retain::sweep(\@segment_paths, $cutoff_ns);
    printf "freed %s bytes from %d segments\n",
        $s->{bytes_freed}, $s->{unlinked};

    my $r = Punk::Observe::Retain::rollup(
        [ map { { t => $_ * 1_000_000_000, v => $_ + 0.0 } } 1 .. 3600 ], 3);
    printf "avg over the hour: %s\n", $r->{value_1h};

=head1 DESCRIPTION

Data is deleted by whole B<block> - two hours - and never by record. Deleting
one line would mean rewriting a compressed block, which would make a segment
mutable and remove the property every reader depends on.

So "delete this one log line" is not supported, and the granularity is the
answer to why.

=head2 Deletion cannot break a reader

The deletion primitive is C<unlink(2)>, never C<ftruncate(2)>.

A reader holding a memory map of an B<unlinked> file keeps reading it
correctly: the name is gone, the data lives until the last mapping drops. A
reader holding a map of a B<truncated> file takes C<SIGBUS> on the next touch -
not an error return, a signal, killing the worker mid-request for every
connection it was holding.

L</sweep> reports C<truncate_calls>, and it must be zero.

=head2 A deleted file that is still mapped is still on the disk

A large segment unlinked an hour ago occupies its space until the last worker
drops its mapping, so the space a retention policy promises and the space the
filesystem reports can differ with no visible explanation. That is what the
generation table is for: a segment is removable when no reader holds its
generation.

=head2 Downsampling refuses percentiles

Two tiers, at five minutes and one hour, each point carrying
C<{count, sum, min, max, last}>. That set is closed under merging, so an hourly
point is built from twelve five-minute points without returning to the raw
data. It answers C<count>, C<sum>, C<avg>, C<min>, C<max> and C<rate> exactly.

B<It cannot answer a percentile, and it refuses to.> There is no function of
those five numbers that yields a p95, and every approximation that looks close
is wrong in the tail - which is the only part of a latency chart anybody reads.
L</rollup> returns a refusal naming the alternative rather than a plausible
wrong number.

Where the series is a histogram the percentile merges exactly from the bucket
counts, and that is the supported path for a long-range percentile.

Counter resets are carried into the rollup, because the raw points that would
reveal one are dropped afterwards.

=head1 AGGREGATE CODES

Passed as an integer to L</rollup>:

    1  count      4  min       7  p90
    2  sum        5  max       8  p95
    3  avg        6  p50       9  p99
                                10 distinct

Codes 6 to 9 are refused over a downsampled range.

=head1 FUNCTIONS

=head2 merge

    my $out = Punk::Observe::Retain::merge([ \@run_a, \@run_b ]);

Merges sorted runs into one ordered stream and collapses duplicates. Each
record is a hashref taking C<t>, C<series> and C<kind>.

    { records => [ { t, series }, ... ], emitted => 240, duplicates => 12 }

The merge is deterministic: the same runs in the same order always produce the
same output, which is what makes re-compaction idempotent rather than a source
of duplicate points.

C<duplicates> counts records collapsed because an earlier compaction had
already emitted them.

=head2 rollup

    my $out = Punk::Observe::Retain::rollup(\@points, $agg);

Folds raw points into the five-minute tier, promotes that to the hourly tier,
and answers C<$agg> from each. Each point is a hashref taking C<t>, C<v> and
C<reset>.

    {
      buckets_5m => [ { t, count, sum, min, max, last, resets }, ... ],
      n_5m => 12,  n_1h => 1,
      ok_5m => 1,  ok_1h => 1,
      value_5m => ..., value_1h => ...,
      resets_5m => 0,  resets_1h => 0,
    }

C<value_5m> and C<value_1h> are present only when the corresponding C<ok> is
true. When C<ok_5m> is false, C<refusal> carries the message explaining what to
do instead - the aggregate was one the tier cannot answer.

The hourly value must equal the five-minute value for every aggregate the tier
supports. That is the closure property the whole design rests on.

=head2 sweep

    my $out = Punk::Observe::Retain::sweep(\@paths, $cutoff_ns);

Marks every segment whose data ends before C<$cutoff_ns> and unlinks it.

    {
      considered => 40,  marked  => 12,
      unlinked   => 12,  kept    => 28,
      bytes_freed => 41943040,
      truncate_calls => 0,
    }

B<C<truncate_calls> must be zero.> A non-zero value means something took
C<ftruncate> to a segment, and a reader mapping it will take C<SIGBUS>.

=head2 read_through_unlink

    my $out = Punk::Observe::Retain::read_through_unlink($path);

Opens a segment, keeps the mapping, unlinks the path underneath it, and reads
every record again through the same mapping.

    {
      opened => 1,  unlinked => 1,  records => 600,
      sum_before => ..., sum_after => ..., same => 1,
    }

C<same> is the property: the data read identically after its name was removed.
This is why deletion is C<unlink> and not C<ftruncate>.

=head2 generations

    my $busy = Punk::Observe::Retain::generations(
        [ acquire => 1, busy => 1, release => 1, busy => 1 ]);

Drives the generation table with a flat list of (operation, generation) pairs
and returns an arrayref holding the result of each C<busy> query, in order.
Operations are C<acquire>, C<release> and C<busy>.

A generation is busy while any reader holds it. Segments belonging to a busy
generation are not removable, which is what stops a sweep pulling the ground
from under a query already running.

=head2 block_removable

    my $bool = Punk::Observe::Retain::block_removable($segments, $expired_all);

Whether a block can be removed: it must have no segments still referencing it,
and every segment that did must have expired. Both conditions, because removing
a block that one segment still points at turns a query into a hole.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Segment>, L<Punk::Observe::Metric>

=cut

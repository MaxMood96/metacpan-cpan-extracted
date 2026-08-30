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

=head2 adopt_orphans

    my $out = Punk::Observe::Retain::adopt_orphans(
        store => $store, grace_s => 600, dry_run => 0);

Seals the logs of workers that are no longer running, so they enter the
ordinary lifecycle. Returns C<seen>, C<adopted>, C<bytes>, C<skipped_live>,
C<skipped_recent> and C<failed>.

Retention considers B<sealed> segments, and the live log is deliberately never
touched. A log left behind by a worker that died is neither: not live, because
nobody is writing it; not sealed, because its owner died first. So it was
never indexed, never expired and never counted against a byte budget, and
every restart left another one behind - a store running for a day accumulated
261MB across 127 such files, none of which C<keep> could reach.

B<Sealed, not deleted.> Its records are usually inside the retention window,
and deleting them would be retention destroying the data C<keep> promised to
hold. Sealing gives the log a sidecar, so queries prune it and the next sweep
expires it on the same C<t_max> rule as everything else.

Adoption needs B<two independent proofs> that nobody owns the file, because
sealing a log somebody is still appending to renames it under their descriptor
and lets them write records past the seal trailer:

=over 4

=item * B<the owning process is gone.> The pid is in the file name. C<EPERM>
from C<kill 0> means the process B<exists> and belongs to somebody else, which
counts as alive - the mistake to avoid is reading "not mine" as "dead".

=item * B<the file is stale.> A live worker appends constantly, so a log
untouched for C<grace_s> (ten minutes by default) is unowned. This covers what
a pid check cannot: a pid that has been recycled and now belongs to something
unrelated.

=back

Both must hold. A recycled pid makes this B<skip> a log it could have
reclaimed, which costs disk; the reverse would cost data.

This assumes the store is local to the host writing it, which is what the
storage design commits to everywhere else - a pid from another machine would
be meaningless here, and so would the log.

=head2 pass

    my $out = Punk::Observe::Retain::pass(
        store => $store, keep_ns => $ns, dry_run => 0);

One retention pass. L</adopt_orphans> runs first, so a log reclaimed now can
be expired by this same pass rather than waiting for the next; then every
sealed segment whose B<newest> record is older than C<now - keep_ns> is
unlinked, its index sidecar with it, and any sidecar left orphaned by an
earlier crash is cleaned up. Returns C<considered>, C<marked>, C<unlinked>,
C<kept>, C<bytes_freed>, C<orphan_idx_removed>, C<unknown_kept>, C<adopted>,
C<adopted_bytes> and the C<cutoff> it used.

Expiry is decided from the sidecar summaries - the same C<t_min>/C<t_max> a
query prunes on - and keyed on C<t_max>: keying on C<t_min> would delete a
segment still holding data inside the window. A segment whose sidecar cannot
be read is B<kept> and counted in C<unknown_kept>, because deleting on an
unknown age is deletion.

There is no default window and no code path that shortens a file. A truncated
segment is C<SIGBUS> for every reader mapping it; an unlinked one keeps
reading to the end for anyone already holding it, which L</read_through_unlink>
proves rather than assumes.

C<bytes> adds a budget over and above the window: after the time sweep, if
the sealed segments still total more than that many bytes, the oldest are
deleted - sidecars in pairs - until the store fits. The window answers "how
far back must I be able to look"; the budget answers "how much disk may that
cost", and when they disagree the budget wins, because a full disk loses
everything rather than the oldest hour. The result gains C<budget_deleted>,
C<budget_freed> and C<bytes> (the sealed total after). Under C<dry_run> the
budget stage is skipped entirely and says so in C<budget_skipped> - it has
no rehearsal mode, and a dry run must not delete.

C<dry_run> takes every decision and skips only the unlink, so the numbers it
reports are the numbers the real run would act on.

=head2 parse_keep

    my $ns = Punk::Observe::Retain::parse_keep('30d');   # undef if not a window

An operator-written window into nanoseconds, using the query language's own
unit table so the two cannot disagree about what a week is. There is no month,
for the reason the lexer gives: C<1m> meaning a month somewhere would be a
trap nobody recovers from.

Years are units here - C<7y> is the window a production store keeps - and
C<y> is B<exactly 365 days>, which L<Punk::Observe::Query/Durations>
explains.

A window B<too large to represent> is refused, and this is the refusal that
matters: the cutoff is C<now - keep> in unsigned nanoseconds, so a keep past
the last representable instant comes back round as a cutoff of I<now>, which
marks every segment in the store for deletion. Under that ceiling nothing
needs clamping - the subtraction floors at zero, so a century-long window on
a store a week old keeps all of it.

=head2 cron_task

    my $code = Punk::Observe::Retain::cron_task(
        store => $store, keep_ns => $ns, owner => $$);
    # cron '17 * * * *' => sub { $code->($queue) };

The scheduled shape, identical to L<Punk::Observe::Health/cron_task> so that
wiring the second one feels like the first: a coderef taking a L<Punk::Queue>,
running one pass under the C<leader> lease. Losing the lease race is the
normal case on a worker pool, not an error - another worker is doing the
pass. C<owner> must be an integer and defaults to the pid.

=head2 retain_job

The cron target L<Punk::Plugin::Observe> registers when it is given
C<< retain => { keep => '7d' } >>. Runs one L</pass> under the
C<observe.retain> lease and reports what it removed. Not called by hand;
F<punk-queue> calls it.

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

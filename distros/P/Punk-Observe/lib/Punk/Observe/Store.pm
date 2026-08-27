package Punk::Observe::Store;

use 5.010;
use strict;
use warnings;

# WAL::seal and Exec::run are called BY NAME from the XS, so they have to be
# loaded even though nothing in this file mentions them.
use Punk::Observe ();
use Punk::Observe::WAL ();
use Punk::Observe::Exec ();

our $VERSION = $Punk::Observe::VERSION;

use constant { KIND_METRIC => 1, KIND_LOG => 2, KIND_SPAN => 3 };

my %KIND_NAME = (KIND_METRIC, 'metric', KIND_LOG, 'log', KIND_SPAN, 'span');

my %SOURCE_KIND = (
    metric => KIND_METRIC,
    log    => KIND_LOG,
    trace  => KIND_SPAN,
    spans  => KIND_SPAN,
);




1;

__END__

=head1 NAME

Punk::Observe::Store - sealing, and the read path over what is sealed

=head1 SYNOPSIS

    use Punk::Observe::Store;

    my $store = Punk::Observe::Store->new(
        dir => '/var/lib/observe', tenant => 'acme');

    $store->seal;                      # this worker's log, closed and indexed

    my $r = $store->query('log | where severity >= error', from => $t0);
    printf "%d rows, %d scanned\n",
        scalar @{ $r->{rows} }, $r->{meta}{scanned_rows};

    my $g = $store->graph;             # the service map
    my $t = $store->trace($hi, $lo);   # one trace, assembled

=head1 DESCRIPTION

Ingest appends to a per-worker log and answers. This is everything that
happens afterwards: closing a log so it stops moving, summarising it so a
query can skip it, and reading records back out of what is left.

=head2 A sealed log is the unit of the read side

The live log is being appended to by the worker that owns it, so a reader gets
whatever complete frames exist at the instant it looks. That is correct and it
is not stable, and an index over a file that is still growing is an index that
is already wrong.

Sealing writes the trailer, renames the file, and computes the summary beside
it in one pass. After that the file never changes again, so its summary can
never go stale - which is what lets a range query decide to skip a segment
from a hundred bytes instead of by opening it.

A live log has no summary and is therefore always read. That is bounded by the
seal threshold rather than by hope.

=head2 The summary is the index

Every figure in a sidecar is one a query would otherwise scan a whole segment
to learn: the time span, the counts per signal, the severity histogram, the
services seen, and the service graph.

The graph especially. Accumulating it at seal is what makes the service map a
read of a few hundred bytes per segment; deriving it at read time would mean
walking every span in the retention window to draw one picture, and a picture
nobody waits for is a picture nobody looks at.

=head2 Nanosecond arithmetic is not double arithmetic

A unix nanosecond timestamp passed 2^53 in 2255, and a duration added to one
overflows a double long before that. Timestamps arrive as decimal strings
wherever a C<UV> cannot hold them, and the comparisons and the two sums this
module needs are done on the strings.

Getting this wrong does not raise anything. It sorts an hour of an incident
into the wrong place.

=head1 CONSTRUCTOR

=head2 new

    my $store = Punk::Observe::Store->new(%opt);

C<dir> is the store root and C<tenant> selects the subtree beneath it,
defaulting to C<default>. C<seal_bytes> is the size at which a live log is
sealed, and C<max_rows> the ceiling on a single read.

=head1 METHODS

=head2 wal_path

The live log this worker appends to, creating the directory if it is absent.

=head2 seal

    my $path = $store->seal;

Seals this worker's live log, renames it to a segment, and writes its summary.
Returns the segment path, or undef when there was nothing to seal.

=head2 seal_if_full

    $store->seal_if_full($bytes_just_written);

Tracks the live log's size and seals it once it passes C<seal_bytes>. The size
is read from disk once per worker and tracked from there, so this costs
nothing per batch.

=head2 segments

    my $segs = $store->segments;

Every file the read side can see: sealed segments with their summaries, and
live logs without. Each carries C<path>, C<name>, C<sealed>, C<bytes> and
C<index>.

=head2 records

    my ($recs, $meta) = $store->records(from => $t0, to => $t1);

Records in the range, newest first, in the shape
L<Punk::Observe::Decode/decode> produces. C<%meta> reports C<scanned>,
C<skipped> (segments the range excluded without opening), C<files>,
C<degraded> and C<truncated>.

=head2 rows

The same, mapped into the executor's row shape.

=head2 row

    my $row = Punk::Observe::Store->row($record);

One record as a row. The two differ in exactly two places, and both are
load-bearing: the kind is a name rather than a number, and C<service> is
lifted out of the attributes because every query filters on it and no query
should have to know where it lives.

=head2 query

    my $r = $store->query($source, from => $t0, to => $t1);

Parses, plans and runs a query over the range. The result is
L<Punk::Observe::Exec/run>'s, plus C<store> describing what was read.

B<Read the metadata.> A caller that renders C<rows> without checking
C<< meta->{truncated} >> renders a partial answer as a complete one.

=head2 graph

    my $g = $store->graph(from => $t0);

The merged service graph: C<edges>, each with C<caller>, C<callee>, C<count>,
C<errors> and C<dur_max>, and C<services> with a record count each. C<caller>
is C<*> for the synthetic root, which is where traffic from something
uninstrumented arrives.

=head2 traces

    my $r = $store->traces(min_duration => 500_000_000, errors_only => 1);

Trace summaries in the range, slowest first. This is the search; C<trace>
assembles one.

=head2 trace

    my $t = $store->trace($trace_hi, $trace_lo);

One trace, assembled: every span in tree order with C<depth>, C<offset> from
the trace's start, C<duration>, C<service>, C<name> and C<attrs>, plus
C<roots>, C<cycles> and C<orphans>.

A trace whose parent chain loops still returns. Broken instrumentation is a
thing to show, not a thing to refuse.

=head2 retain

    my $r = $store->retain(bytes => 2 * 1024 ** 3);

Deletes whole segments, oldest first, until the store fits the budget.
Returns C<< { deleted, freed, kept, bytes } >>.

Deletion is by C<unlink> and never by truncating a file a reader may have
open: a reader mid-query keeps its copy until it lets go.

=head2 stats

What the status screen shows, read from the sidecars rather than from a scan.

C<unindexed> counts sealed segments with no summary and C<orphan_index>
counts summaries with no segment. Both are halves of something that was
interrupted, and both are worth saying out loud rather than quietly
under-reporting.

C<mapped_deleted> is bytes unlinked while a reader still holds them open,
which is disk that is occupied and invisible to C<du>. This store cannot
accumulate any: a read copies a segment and lets go of it inside the call, so
a retention pass never runs against a live mapping. It is reported because a
design property nothing displays is one nobody can check.

=head2 dir

=head2 tenant

=head2 wal_dir

The store root, the tenant subtree beneath it, and the directory the logs and
segments for that tenant live in.

=head1 PRIMITIVES

The pieces the methods above are built from, useful on their own and
documented because they are callable.

=head2 ncmp

=head2 nadd

=head2 nsub

    my $order = Punk::Observe::Store::ncmp($a, $b);
    my $sum   = Punk::Observe::Store::nadd($t, $duration);

Compare, add and subtract nanosecond instants. C<ncmp> compares digits rather
than parsing, so it keeps working on values too wide for a C<uint64> - which
is what stops a future timestamp format sorting into the wrong century.
C<nadd> saturates and C<nsub> clamps at zero, because a horizon that wrapped
to zero would delete everything.

=head2 scan

    my ($recs, $meta) = Punk::Observe::Store::scan($bytes, \%filter);

Replays one log image, filters it by C<from>, C<to> and C<kind>, orders it
newest first and caps it at C<limit>. C<%meta> carries C<scanned>, C<kept>,
C<truncated> and the replay's C<reason>.

=head2 scan_dir

    my $segs = Punk::Observe::Store::scan_dir($dir);

Lists a store directory: every segment and live log in it, with its size and
its parsed summary.

=head2 summarise

    my $s = Punk::Observe::Store::summarise($bytes);

The counts of one log image - records, time span, and the tallies per signal
and severity. B<Counts only>: it builds no service graph and counts no
traces, which is why C<seal> does not use it.

=head2 read_index

=head2 write_index

The sidecar beside a sealed segment, read and written.

=head2 wal_dir

    my $dir = $store->wal_dir;

Where this store's logs live: C<dir/tenant/wal>. Every path the store builds
is rooted there, which is what makes a tenant a directory rather than a
column.

=head2 row

    my $row = Punk::Observe::Store->row($record);

One record in the shape the executor reads. C<records> and C<rows> build this
during the scan and never call here; this is for a caller that already has a
record and wants the other shape without going back to the log.

=head2 slurp

=head2 file_size

=head2 mkpath

=head2 rename_file

File operations, named so they cannot be confused with perl's own. In
particular C<rename_file> is not C<rename>: a subroutine of that name in this
package would shadow the builtin for every caller in it.

=head2 retain_dir

    my $out = retain_dir($dir, $budget_bytes, $keep_min);

The whole of retention against one directory: list, size, order by name, and
unlink oldest first until the total is under budget. Returns C<deleted>,
C<freed>, C<kept> and C<bytes>.

C<$keep_min> is a B<floor>, and it is what stops a misconfigured budget
emptying a store: a budget of one byte would otherwise delete everything.

The sidecar is unlinked with its segment. One left behind is the other half
of an interrupted pass, and L</stats_dir> counts those.

=head2 stats_dir

    my $s = stats_dir($dir);

Every figure the status screen shows, read from the sidecars rather than by
scanning. Returns the counters, C<service> as a merged name-to-count table,
and three numbers that are about the store's own health rather than its
contents: C<wal_depth>, C<unindexed> and C<orphan_index>.

A sealed segment with no sidecar is C<unindexed> - a seal that was
interrupted. It is still readable and still counted, because a number that is
low is different from a number that is wrong.

=head1 CONSTANTS

=head2 KIND_METRIC

=head2 KIND_LOG

=head2 KIND_SPAN

The three record kinds, as the record carries them: 1, 2 and 3. A record is
one shape and the signals are three views of it, so these select a view
rather than a type.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::WAL>, L<Punk::Observe::Exec>,
L<Punk::Observe::Trace>, L<Punk::Plugin::Observe>

=cut

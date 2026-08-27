package Punk::Observe::Segment;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Segment - immutable segments, series ids and the symbol table

=head1 SYNOPSIS

    use Punk::Observe::Segment;

    my $ids = Punk::Observe::Segment::intern_series(
        [ 'http.route=/pay,service=api', 'http.route=/cart,service=api' ]);

    Punk::Observe::Segment::write('seg.po', \@records, 'acme', 0);
    my $out = Punk::Observe::Segment::read('seg.po');

    my $shm = Punk::Observe::Segment::shm_new(100_000);
    warn 'at the cardinality cap'
        unless Punk::Observe::Segment::shm_admit($shm);

=head1 DESCRIPTION

A segment is the unit of storage: written once, never modified, and read
through a memory mapping. Records go in sorted, the strings they reference are
interned into a per-segment symbol table, and a footer written last carries the
statistics a query prunes on.

Written last is what makes it safe. A segment whose footer is present is a
segment that finished being written, so a reader never has to reason about a
partial one.

=head2 Series ids are derived from content

A series id is a 128-bit hash of the canonical label block, not a counter. Two
workers seeing the same labels produce the same id without exchanging a
message, which is what allows several workers to write segments in parallel and
have a reader treat them as one series afterwards.

The canonical order is the decoder's attribute sort. A different order over the
same labels must give the same id, or a series silently splits in half and
presents as data simply being missing.

=head2 The cardinality cap

Distinct series are admitted through a counter in an arena shared across forked
workers, so the cap is the process group's and not each worker's. Over it,
further series are B<refused> and counted rather than admitted, and the refusal
is visible in L</shm_stats>.

A cap that each worker counted separately would be a cap in name only: eight
workers with a limit of 100,000 would admit 800,000.

=head1 FUNCTIONS

=head2 murmur128

    my ($hi, $lo) = Punk::Observe::Segment::murmur128($bytes, $seed);

The 128-bit MurmurHash3 of a string, as two 64-bit halves. This is the hash
series ids are built from.

=head2 intern_series

    my $out = Punk::Observe::Segment::intern_series(\@label_blocks);

Interns canonical label blocks and reports what each got.

    {
      slots      => [ 0, 1, 0 ],
      ids        => [ '3f2a...', '91cc...', '3f2a...' ],
      count      => 2,
      collisions => 0,
    }

C<slots> is the per-segment slot each block was assigned, positionally matching
the input. C<ids> is the same, as 32 hex characters of the full 128-bit id.
C<count> is the number of distinct series, and C<collisions> counts hash
collisions resolved during probing.

The same block appearing twice gets the same slot and the same id. The same set
of blocks presented in a different order gets the same B<ids>, though not
necessarily the same slots, because a slot is per-segment and an id is not.

=head2 intern_strings

    my $out = Punk::Observe::Segment::intern_strings(\@strings);

Interns strings into a symbol table, serialises it, and reads it back through
the same view a reader gets out of a mapping.

    {
      ids     => [ 0, 1, 0 ],
      count   => 2,
      decoded => [ 'api', 'checkout' ],
      bytes   => 40,
    }

C<ids> are the symbol numbers assigned, positionally matching the input, and
C<decoded> is the table as it reads back, indexed by symbol number. C<bytes> is
the serialised size.

=head2 write

    my $path = Punk::Observe::Segment::write($path, \@specs, $tenant, $slot);

Builds a segment from record specs and writes it, returning the path on success
and undef on failure. Each spec is a hashref taking C<t> (unix nanoseconds),
C<body> and C<labels>. C<$slot> is the worker slot the segment is attributed
to, which is what keeps parallel writers from colliding on a name.

=head2 parse

    my $out = Punk::Observe::Segment::parse($bytes);

Parses a segment image already in memory, with no filesystem involved, so that
a deliberately damaged buffer can be handed to it. Returns undef when the image
is not a valid segment.

    {
      records => 600,
      t_min   => '1774224000000000000',
      t_max   => '1774224007200000000',
      signal  => 1,
      slot    => 0,
      symbols => 12,
    }

C<signal> is 0 mixed, 1 traces, 2 metrics, 3 logs.

=head2 read

    my $out = Punk::Observe::Segment::read($path);

Maps a segment and reads its records back, resolving bodies through the symbol
table. Returns undef when the file will not open.

    {
      records => [ { t => ..., series => ..., body => ... }, ... ],
      t_min   => ...,
      t_max   => ...,
    }

=head2 overlaps

    my $bool = Punk::Observe::Segment::overlaps($path, $from, $to);

Whether a segment's time span meets the range, from the footer. This is the
test that keeps a query over one hour from opening a week of segments. Returns
undef if the file will not open.

=head2 shm_new

    my $shm = Punk::Observe::Segment::shm_new($series_cap);

Creates the fork-shared arena holding the cardinality counters, returning a
handle. A cap of zero means unlimited. The handle must be passed to
L</shm_free>; it is not garbage collected.

Create it B<before> forking. Workers forked afterwards share the counters;
a worker that creates its own does not.

=head2 shm_admit

    my $ok = Punk::Observe::Segment::shm_admit($shm);

Asks to create one more distinct series. Returns true if the cap allows it, and
false if the series must be refused.

=head2 shm_stats

    my $s = Punk::Observe::Segment::shm_stats($shm);

    { series => 412, series_cap => 1_000_000, rejected => 0, overflow => 0,
      records => 91_204, bytes => 8_140_112,
      rate_window_start => 1774224000000000000, rate_records => 3_140,
      rate_bytes => 210_004, rate_rejected => 0, shared => 1 }

C<series> is how many have been admitted, C<series_cap> the configured ceiling
(0 for none), C<rejected> how many the cap refused, and C<overflow> how many
were folded into the overflow series that says so in the data rather than
vanishing from it.

C<records> and C<bytes> are what was B<accepted>, which is not what the store
holds: the store counts what survived retention, and this counts what arrived.
A receiver refusing everything and a receiver being sent nothing are
indistinguishable in the store and different here.

C<rate_records>, C<rate_bytes> and C<rate_rejected> are the current rate
window, which began at C<rate_window_start>. They reset when the window rolls,
so a reader wanting a rate takes two samples rather than a difference against
a total.

B<Check C<shared>.> It is false when the arena could not be mapped shared, in
which case the counters are per-process and the cap is not being enforced
across workers. An operator finding the cap did not hold, with no explanation
available, is the failure this flag exists to prevent.

=head2 shm_free

    Punk::Observe::Segment::shm_free($shm);

Releases the arena. Calling it twice on the same handle is not safe.

=head2 manifest_append

    my $ok = Punk::Observe::Segment::manifest_append($path, $generation, \@names);

Appends one generation to the manifest: the list of segment names that make up
the store at that point. The manifest is append-only, so a reader that has read
generation C<n> is never invalidated by a writer producing C<n+1>.

=head2 manifest_latest

    my $out = Punk::Observe::Segment::manifest_latest($bytes);

Reads the newest complete generation out of a manifest image.

    { generation => 3, names => [ 'a.po', 'b.po' ], count => 2 }

A generation still being appended is ignored rather than half-read, so this
returns the last one that was written completely. C<generation> is 0 when there
is none.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::SegIO>, L<Punk::Observe::Retain>

=cut

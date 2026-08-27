package Punk::Observe::Log;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Log - compressed log blocks and the trigram filter

=head1 SYNOPSIS

    use Punk::Observe::Log;

    my $b = Punk::Observe::Log::block_roundtrip(
        [ { t => 1, severity => 9, body => 'connection refused' } ], 1);
    printf "%d raw, %d compressed\n", $b->{raw_len}, $b->{comp_len};

    my @labels = Punk::Observe::Log::default_labels();

    my $p = Punk::Observe::Log::prune(\@blocks, $from, $to, 'refused');
    printf "opened %d of %d blocks\n", $p->{candidates}, $p->{considered};

=head1 DESCRIPTION

Log lines are grouped into streams by their label set and stored in
raw-deflated blocks of up to a megabyte. A block is the unit of decompression,
which is what sets its size: smaller means more directory and worse ratios,
larger means a query for one minute inflates ten.

On 3,000 lines of structured request logs a block compressed 27 times, to 3.7
bytes per line.

Raw deflate rather than gzip: an eighteen-byte header and trailer on every
block is pure overhead when the directory already carries the length and a
checksum.

=head2 Search never opens every block

Three tests run in increasing cost order, and only a block surviving all three
is decompressed:

=over 4

=item 1. the stream, an integer comparison

=item 2. the time span, from the block directory, B<without inflating it>

=item 3. the per-block trigram filter

=back

The filter stores no text. It answers only "can this block possibly contain
that substring", and a block that survives it is decompressed and matched
exactly. A false positive costs one wasted decompression; a false negative
would lose a log line silently, and there is no acceptable rate of the second.
So the filter is sized from each block's measured distinct-trigram count rather
than from a fixed guess.

Measured over 200 blocks: zero false negatives across 175,837 trigrams actually
present. False positives depend on the term - none of 2,000 absent
twelve-character terms, but 2 of 495 absent three-character ones, which is the
case to expect since a short term carries fewer trigrams to disagree on.

=head2 A search under three characters cannot use the filter

It has no trigrams. Such a search falls through to scanning every block the
label filter and time range leave, rather than silently matching nothing. Ask
L</query_usable> before pruning on a term.

=head1 FUNCTIONS

=head2 have_zlib

    my $bool = Punk::Observe::Log::have_zlib();

Whether this build compresses blocks. Without zlib, blocks are B<stored>
uncompressed and say so in a flag - a real degradation, and a visible one. A
block that claimed to be compressed and was not would inflate to nothing.

=head2 default_labels

    my @keys = Punk::Observe::Log::default_labels();

The attribute keys that become part of a stream's label set:
C<service.name>, C<severity>, C<host.name>, C<deployment.environment>.

Everything else stays in the record, searchable but not indexed. B<This limit
is what keeps the store alive.> A stream is a label set, so a label set
containing a request id is one stream per request - the same cardinality
explosion that kills a metric store, wearing different clothes.

=head2 is_label

    my $bool = Punk::Observe::Log::is_label($key);

Whether an attribute key is on the allowlist.

=head2 query_usable

    my $bool = Punk::Observe::Log::query_usable($term);

Whether a search term is long enough for the filter to say anything about it.
False for anything under three bytes.

=head2 contains

    my $bool = Punk::Observe::Log::contains($haystack, $needle);

The exact, case-folded substring match that runs after the filter says a block
is possible. Folding is identical when a block is written and when it is
searched, so a match found one way is found the other.

=head2 bloom_probe

    my $out = Punk::Observe::Log::bloom_probe($corpus, \@terms);

Builds a filter over C<$corpus>, then asks it about each term.

    { possible => [ 1, 0, 1 ], bits => 65536, distinct => 3478, added => 3478 }

C<possible> is positional and holds 1 where the filter says the term may be
present. A 1 for a term that is genuinely absent is a false positive and costs
a wasted decompression; a 0 for a term that is present is a false negative and
must never happen.

C<distinct> is the corpus's measured distinct-trigram count, which is what
C<bits> was sized from.

=head2 block_roundtrip

    my $out = Punk::Observe::Log::block_roundtrip(\@lines, $stream);

Builds a block, seals it, inflates it and reads the lines back, so what came
out can be compared with what went in rather than trusting an intermediate.
Each line is a hashref taking C<t>, C<severity>, C<body>, C<trace_hi>,
C<trace_lo> and C<span_id>.

    {
      lines    => [ { t, severity, body, trace_hi, trace_lo, span_id }, ... ],
      raw_len  => 303120,
      comp_len => 11116,
      count    => 3000,
      stored   => 0,
      t_min    => ...,
      t_max    => ...,
    }

C<stored> is true when the block was kept uncompressed, either because deflate
did not help or because the build has no zlib.

C<trace_id> and C<span_id> are first-class columns rather than text, which is
what makes correlating a trace to its log lines a lookup instead of a search
for a hex string.

=head2 block_corrupt_detected

    my $bool = Punk::Observe::Log::block_corrupt_detected(\@bodies, $offset);

Builds a block from a list of line bodies, flips the byte at C<$offset> of the
compressed image, and returns true if inflating it was refused. The CRC is over
the raw bytes, so corruption is caught before a single line is handed on.

=head2 prune

    my $out = Punk::Observe::Log::prune(\@blocks, $from, $to, $term);

Runs the pruning tests over block descriptions and reports which survived. Each
block is a hashref taking C<t_min>, C<t_max> and C<text>.

    {
      kept          => [ 0, 3 ],
      considered    => 12,
      skipped_time  => 7,
      skipped_bloom => 3,
      candidates    => 2,
    }

C<kept> holds the indexes that survived. The three counts are the assertion
that pruning actually prunes: C<candidates> is how many blocks would be
decompressed, and it should be far below C<considered>.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::SegIO>, L<Punk::Observe::Query>

=cut

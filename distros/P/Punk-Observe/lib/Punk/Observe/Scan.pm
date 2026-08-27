package Punk::Observe::Scan;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Scan - what a query can decide without reading

=head1 SYNOPSIS

    use Punk::Observe::Scan;

    my $pd = Punk::Observe::Scan::pushdown(
        'log {service="api"} | where t > 1774224000000000000
                             | search "connection refused"');
    printf "term %s, bounded %d\n", $pd->{search}, $pd->{bounded};

    my $s = Punk::Observe::Scan::prune('seg.po', $query, {});
    printf "read %d of %d blocks\n",
        $s->{considered} - $s->{skipped_bloom}, $s->{considered};

=head1 DESCRIPTION

The seam between a query and the bytes on disk. A plan carries more than the
scan needs, so what is B<pushed down> is extracted first: the time range the
query proves, the term a filter can be probed with, the first equality a
directory can answer, and a minimum duration.

Everything that follows is subtraction. A segment whose footer falls outside
the range is never opened; a block whose directory entry falls outside it is
never inflated; a block whose filter cannot hold the term is never inflated
either.

=head2 Pushdown is what the query proves, not what it asks

Only a predicate that must hold for every matching row is pushed down. C<t >
X and t < Y> bounds the range; the same two joined by C<or> does not, and a
scan that treated it as though it did would skip segments holding matches.

Where the predicates prove nothing can match at all - a range whose end
precedes its start - the pushdown is B<empty> and no segment is opened.

=head2 The skip counts are the evidence

C<prune> reports what it did not read, per test. Those numbers are how pruning
is shown to be working: a query over one minute that considered four hundred
blocks and skipped three hundred and ninety is doing its job, and the same
query reporting no skips is reading a day to answer a minute.

=head1 FUNCTIONS

=head2 pushdown

    my $pd = Punk::Observe::Scan::pushdown($query);

Parses and plans a query, then reports what can be decided before any data is
read.

On failure:

    { ok => 0, error => "..." }

On success:

    {
      ok       => 1,
      from     => '1774224000000000000',
      to       => '1774224007200000000',
      bounded  => 1,
      empty    => 0,
      search   => 'connection refused',
      eq_field => 'service',
      eq_value => 'api',
      min_duration => '500000000',
    }

C<bounded> is false when the query proved no time range, in which case C<from>
and C<to> are the widest possible and every segment is a candidate.

C<empty> is true when the predicates cannot be satisfied by anything. Nothing
should be opened.

C<search>, C<eq_field> and C<eq_value> are empty strings where the query has
none, and C<min_duration> is 0. An empty search term is not a term matching
everything: it means the filter cannot be consulted, so see
L<Punk::Observe::Log/query_usable>.

=head2 prune

    my $s = Punk::Observe::Scan::prune($path, $query, \%opts);

Opens a real segment, applies a real query's pushdown to it, and reports what
was skipped. C<%opts> takes C<stream>, which restricts log blocks to one
stream.

On failure - a query that will not parse or plan, or a segment that will not
open - returns C<< { ok => 0, error => "..." } >>.

    {
      ok             => 1,
      segment_wanted => 1,
      blocks         => 12,
      blocks_skipped => 388,
      metric_chunks  => 4,
      log_blocks     => 8,
      traces         => 0,
      considered     => 400,
      skipped_stream => 240,
      skipped_time   => 120,
      skipped_bloom  => 28,
    }

C<segment_wanted> is the first decision, from the footer alone. When it is
false nothing else was read and every count is zero.

C<metric_chunks>, C<log_blocks> and C<traces> are how many of each survived to
be read, capped at 256 apiece. The four C<skipped_> counts break down what the
log-block pruning rejected and at which test, in the order the tests run:
stream, then time, then the filter.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Query>, L<Punk::Observe::Exec>,
L<Punk::Observe::Log>, L<Punk::Observe::Segment>

=cut

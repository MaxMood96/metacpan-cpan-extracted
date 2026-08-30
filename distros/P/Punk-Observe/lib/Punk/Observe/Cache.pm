package Punk::Observe::Cache;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

# All of it is C: po_chunk.h and xs/chunk.xs. The arithmetic is unsigned
# 64-bit and the query is parsed by the same parser that will run it, so
# neither lives here.

1;

__END__

=head1 NAME

Punk::Observe::Cache - the settled part of a window, computed once

=head1 SYNOPSIS

    my $r = Punk::Observe::Cache::query($store, $query,
                from => $t0, to => $t1, cache => $c);

=head1 DESCRIPTION

A dashboard over twenty-four hours re-scans twenty-four hours on every load,
of which all but the last few minutes is settled data that will answer the
same way for ever. This splits the window into aligned chunks, serves the
settled ones from a L<Punk::Cache> store, and computes only the live tail.

=head2 Why concatenating chunks is not an approximation

A bucket is computed from the records inside it and nothing else, and bucket
indices are B<absolute> - C<t / bucket_ns>, not an offset from the query's
start. So the buckets two adjacent windows produce are exactly the buckets one
window over both would have produced. F<t/0930-query-cache.t> asserts that
against a real store rather than assuming it.

Chunks are a whole number of buckets, or a bucket would be split across two
entries and each half would be a count of part of it.

=head2 What cannot be chunked

A stage that ranks rows against each other - C<limit>, C<top>, C<slowest>,
C<sort> - cannot be split, because the top five of each half is not the top
five of the whole. Neither can the cross-signal stages, which re-key against a
set collected across the whole pipeline. Any of these turns chunking off and
the query runs whole, which is why this has the same contract as
C<< $store->query >> and a caller never has to ask which it got.

=head2 The settled edge

Telemetry arrives late - an exporter batches, a network stalls - so a bucket
that has only just closed can still gain records. Only chunks that ended more
than C<lag_ns> ago (two minutes by default) are cached; everything after that
is computed on every call.

That leaves two honest limitations, both bounded by the entry's TTL: data
B<backfilled> with old timestamps will not appear in a chunk already cached,
and data B<deleted by retention> may still appear in one. Neither is a
correctness problem for a dashboard, and both resolve within the hour.

=head2 It also makes the answer more complete

Not the point, but worth knowing. A query has a row ceiling, and a
twenty-four-hour scan on the demo store hit it: C<truncated> set and nine
buckets returned out of the twenty-three the data covers. Each chunk stays
well under the ceiling, so the chunked answer is the whole one.

=head1 FUNCTIONS

=head2 query

    my $r = Punk::Observe::Cache::query($store, $q,
                from => $ns, to => $ns, cache => $c,
                lag_ns => $ns, ttl => 3600, now => $ns);

The same shape C<< $store->query >> returns, plus C<cached_chunks>. Falls back
to one plain query whenever chunking would not be sound. A cache that throws -
an unwritable directory, a full disk - is a slow query rather than a failed
one.

=head2 bucket_ns

    my $ns = Punk::Observe::Cache::bucket_ns($query);

The bucket width the query asked for, or C<undef> when the query must be run
whole.

=head2 chunk_ns

    my $ns = Punk::Observe::Cache::chunk_ns($bucket_ns);

The chunk width for a bucket width: about an hour, rounded to a whole number
of buckets, never less than one bucket.

=head1 SEE ALSO

L<Punk::Cache> - the store this uses.

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut

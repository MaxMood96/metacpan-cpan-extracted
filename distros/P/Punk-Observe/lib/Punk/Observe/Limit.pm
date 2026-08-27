package Punk::Observe::Limit;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Limit - three limits, failing three different ways

=head1 SYNOPSIS

    use Punk::Observe::Limit;

    my $r = Punk::Observe::Limit::rate(
        { records => 50_000 },
        [ { at => $t, records => 900, bytes => 90_000 } ]);
    my $accepted = $r->{batches}[0]{accepted};

=head1 DESCRIPTION

Treating these as one limit is the mistake. Each has a wrong answer that is
worse than the limit itself, and the wrong answers are different, so one
mechanism cannot serve all three.

All three matter on a single-tenant box: they are what stops one
misconfigured service taking down the machine whose job is to tell you why
things fell over.

=head2 Ingest rate: a partial success, not a 429

A 429 makes the exporter re-send the whole batch, forever, at the moment the
server is already under pressure - the limit becomes an amplifier. OTLP has
C<partial_success> for exactly this: accept what fits, say how much did not,
and the exporter drops the rest.

The window lives in the fork-shared arena, so the limit is per pool. A
per-worker window on a four-worker box is four times what was configured.

=head2 Cardinality: the new series is dropped

Never an eviction. Evicting an existing series to admit a new one turns a
cardinality problem into data loss on the exact series somebody has open in a
dashboard, which is the one they are watching because it matters.

Admission only ever increments, so that property is structural rather than a
rule somebody has to remember.

=head2 Storage bytes: retention shortens

Writes are never refused. A store over its byte budget should lose old data;
it must not lose the incident happening now, which is when it is most needed
and least replaceable.

The newest block is always kept. A budget smaller than one block is a
misconfiguration, and answering it by deleting the incident in progress would
be the limiter doing more damage than the thing it limits.

=head2 The allowlist matters more than any of the numbers

Only the configured attributes become index dimensions; the rest stay in the
record and are reachable by a residual filter, so nothing is lost - it is
just slower to find.

The overflow counter B<names the attribute>, because the person who hits this
first is a self-hoster with no support contract and no dashboard telling them
which one did it.

=head1 FUNCTIONS

=head2 rate

    my $r = Punk::Observe::Limit::rate(\%cfg, \@batches);

C<%cfg> takes C<records> and C<bytes> per second; zero or absent means off.
Each batch takes C<at>, C<records> and C<bytes>. Returns per-batch
C<< { offered, accepted, rejected } >> - a count rather than a boolean,
because the caller turns the difference into an OTLP partial success.

=head2 storage

    my $r = Punk::Observe::Limit::storage(\@blocks, $budget);

Blocks are C<< { age, bytes } >>, oldest first. Returns
C<< { keep, bytes, horizon } >>: how many of the newest blocks fit, what they
occupy, and the age the retention job should cut at.

=head2 attrs

    my $r = Punk::Observe::Limit::attrs(\@allowlist, \@keys);

Returns C<< { indexed, residual, overflow, other, worst } >>. C<residual> is
what stays in the record without an index entry; C<overflow> names each
unlisted attribute with a count, and C<other> counts those past the naming
cap - counted rather than dropped.

Passing C<undef> for the allowlist uses the default set.

=head2 cardinality_forked

    my $r = Punk::Observe::Limit::cardinality_forked($cap, $workers, $each);

Maps the shared arena, forks, and has each worker admit C<$each> series.
Returns C<< { shared, admitted, rejected, offered } >>. Exists so the
fork-shared property can be asserted rather than assumed.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Plugin::Observe>

=cut

package Punk::Observe::Route;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Route - grouping, silences, and the outbox key

=head1 SYNOPSIS

    use Punk::Observe::Route;

    my $r = Punk::Observe::Route::run(
        { group_wait => 30e9, repeat_interval => 300e9 },
        [ { at => $t, group => 'prod', series => 'api',
            rule => 1, fired_at => $t } ]);

    printf "sent %d messages\n", scalar @{ $r->{sent} };

=head1 DESCRIPTION

A deploy breaks forty services at once. Forty firing series is one event, and
delivering it as forty messages is how a channel gets muted.

Notifications are therefore grouped by a configured label set and held for
C<group_wait> before the first send: one message listing forty services
rather than forty messages. A series arriving after the group was sent opens
a new group, so the forty-first is a second notification rather than a lost
one.

C<group_wait> delays the first notification. That is the intent and it has to
be stated in the interface, because thirty seconds of latency on a page is
something an operator needs to know in advance rather than discover during an
incident.

=head2 A silence suppresses notification, not state

A silenced rule still reaches C<firing> and still renders red. It just does
not page.

A silence that hid the state would be how an incident is forgotten: somebody
silences an alert to get through a deploy and the dashboard shows green for
the rest of the week. The state machine in L<Punk::Observe::Alert> is a
different module and knows nothing about silences, which is what enforces it.

Silences expire. One set for a deploy and forgotten is how a real page goes
unsent for a month.

=head2 The outbox key

C<(rule, series, fired_at)>. A retried send job recomputes the same key and
is refused, so a delivery can never happen twice however many times the job
runs.

C<fired_at> is in the key rather than the time of the send, because a series
that resolves and fires again is a B<new> notification and must not be
deduplicated against the old one.

A claimed row is not claimable by a second sender. The database does that
with C<FOR UPDATE SKIP LOCKED>; the invariant is the same either way.

=head1 FUNCTIONS

=head2 run

    my $r = Punk::Observe::Route::run(\%opts, \@events);

C<%opts> takes C<group_wait> and C<repeat_interval> in nanoseconds, and
C<silences> as an arrayref of C<< { pattern, prefix, until } >>.

Each event takes C<at>, and optionally C<group>, C<series>, C<rule> and
C<fired_at>. An event with no C<series> is the sender waking up to see what
is due, which is how C<group_wait> is observed at all.

Returns:

    {
      sent          => [ { group, members, count, overflow, at }, ... ],
      enqueued      => how many reached the outbox
      deduped       => how many were refused as duplicates
      pending       => how many were queued
      claimed       => how many a sender took
      reclaimed     => how many a SECOND sender took - always 0
      pending_after => what is left once they are claimed
    }

C<overflow> counts members past the per-message cap. They are counted rather
than dropped: a message saying "and 40 more" is an answer, one silently
listing 256 of 296 is a lie.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Alert>, L<Punk::Observe::Target>

=cut

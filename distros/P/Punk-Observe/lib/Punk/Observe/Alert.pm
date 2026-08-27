package Punk::Observe::Alert;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Alert - rule evaluation, and the two states everybody forgets

=head1 SYNOPSIS

    use Punk::Observe::Alert;

    my $ticks = Punk::Observe::Alert::run(
        { op => '>', threshold => 100, for => 60e9, every => 30e9 },
        [ { at => $t0,        rows => [ 'api' => 150 ] },
          { at => $t0 + 60e9, rows => [ 'api' => 150 ] } ]);

    for my $n (@{ $ticks->[-1]{notes} }) {
        printf "%s went %s -> %s\n", $n->{series}, $n->{from}, $n->{to};
    }

=head1 DESCRIPTION

A rule is an OQL string executed on the same path the dashboard uses, so an
alert cannot fire on a different answer than the graph shows. This module is
what happens to the answer.

=head2 State is per series

A rule grouped C<by service> produces many series and each carries its own
state. One state per rule is the bug that makes an alert resolve because a
B<different> service recovered, and it is easy to write because a rule feels
like one thing.

The states are C<ok>, C<pending>, C<firing>, C<stale> and C<error>.

=head2 The transition that sends nothing

C<pending> back to C<ok> notifies nobody. That is the entire purpose of
C<for>: an implementation that notifies there produces exactly the flapping
the setting exists to prevent.

C<for> is measured on the condition holding B<continuously>. A breach that
clears inside the window resets it, so a rule that spikes for one second a
minute does not fire after C<for> of wall time.

=head2 A vanished series must not stay firing

A pod is deleted, its series stops being reported, and a naive implementation
leaves it red for ever. A permanently red dashboard is how alerting loses its
audience, and once it has, the real alert is not read either.

A series absent from a result goes C<stale>, and leaves C<firing> for C<ok>
after two evaluation intervals. If it was firing, that emits a resolution
saying the series stopped existing - a different event from the condition
clearing, and one worth telling apart.

=head2 An evaluation error is not "ok"

A rule whose query fails - a store error, a budget refusal, a bad threshold -
goes to C<error> and notifies. It does not report healthy.

This is the failure mode most likely to be written by accident, because the
natural code path treats "no rows" and "no answer" identically, and the
result is a system that reports green because it could not look. So the
evaluation carries a status alongside its rows and the two are never
collapsed.

An error notifies B<once>, not every tick: a rule that pages every thirty
seconds while a store is down is a rule that gets silenced, which is the same
as not having it. A successful evaluation re-arms it.

=head1 FUNCTIONS

=head2 run

    my $ticks = Punk::Observe::Alert::run(\%rule, \@ticks);

Drives a rule through a sequence of evaluations. The rule takes C<op> (one of
C<< > >>, C<< >= >>, C<< < >>, C<< <= >>, C<==>, C<!=>), C<threshold>,
C<for> and C<every>, the last two in nanoseconds.

Each tick takes C<at> (a nanosecond instant, which becomes the clock for that
evaluation), either C<rows> as a flat key-value list or C<fail> for an
evaluation that did not run, and returns:

    {
      notes  => [ { series, kind, from, to, at, fired_at }, ... ],
      states => [ { series, state, since, fired_at }, ... ],
    }

C<kind> is 1 firing, 2 resolved, 3 resolved because the series vanished, 4
error.

C<fired_at> is part of the outbox dedupe key. It is stable while a series
stays firing and B<new> after a resolve and re-fire, or the second page would
be deduplicated away and never delivered.

The clock is injected for the duration of the call and restored afterwards.
Nothing sleeps: every transition is a step of C<at>.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Route>, L<Punk::Observe::Query>

=cut

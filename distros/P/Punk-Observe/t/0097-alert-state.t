#!perl
# Rule evaluation: every transition, and the two that get missed.
#
# NOTHING HERE SLEEPS. Every transition is driven by moving the injected
# clock, because a test that waits and then asserts is a coin toss on a loaded
# smoker, and a flaky alerting test is one people learn to re-run.
#
# The two assertions this file exists for:
#
#   A VANISHED SERIES MUST LEAVE FIRING. A pod is deleted, its series stops
#   being reported, and a naive implementation stays red for ever. A
#   permanently red dashboard is how alerting loses its audience.
#
#   AN EVALUATION FAILURE IS NOT "OK". A rule whose query could not run must
#   go to error and notify, not report healthy. That is the failure mode
#   written by accident, because the natural code path treats "no rows" and
#   "no answer" identically.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $A = 'Punk::Observe::Alert';
sub run { $A->can('run')->($_[0], $_[1]) }

use constant SEC => 1_000_000_000;

# A nanosecond instant does not fit a 32-bit IV. Perl falls back to an NV and
# stringifies it as "1.7e+18", which the u64 parser correctly refuses - so
# every timestamp in this fixture became zero and the state machine got the
# blame. Instants are therefore built as exact decimal STRINGS.
#
# The same trap as the protobuf fixture in t/lib/POWire.pm: a test that
# constructs 64-bit values with native arithmetic tests the perl it was
# written on. See the offsets below - they are SECONDS, and `at` does the
# widening.
require Math::BigInt;
my $EPOCH = '1700000000000000000';
sub at { Math::BigInt->new($EPOCH)->badd(sprintf '%.0f', $_[0] * 1e9)->bstr }

# Notification kinds, from po_alert.h.
use constant { FIRING => 1, RESOLVED => 2, VANISHED => 3, ERROR => 4 };

sub states_of {
    my ($tick) = @_;
    return { map { $_->{series} => $_->{state} } @{ $tick->{states} } };
}
sub kinds_of { [ map { $_->{kind} } @{ $_[0]{notes} } ] }

# --- ok -> pending -> firing ------------------------------------------------

{
    my $r = run({ op => '>', threshold => 100, for => 60 * SEC, every => 30 * SEC },
        [
          { at => at(0),                rows => [ 'api', 50 ] },
          { at => at(30),  rows => [ 'api', 150 ] },
          { at => at(60),  rows => [ 'api', 150 ] },
          { at => at(90),  rows => [ 'api', 150 ] },
        ]);

    is(states_of($r->[0])->{api}, 'ok',      'under the threshold it is ok');
    is(states_of($r->[1])->{api}, 'pending', 'over it, it goes pending');
    is_deeply(kinds_of($r->[1]), [], '  and notifies NOTHING yet');
    is(states_of($r->[2])->{api}, 'pending',
       'still pending inside `for`, 30s into a 60s window');
    is_deeply(kinds_of($r->[2]), [], '  and still silent');
    is(states_of($r->[3])->{api}, 'firing', 'it fires once `for` has elapsed');
    is_deeply(kinds_of($r->[3]), [ FIRING ], '  and notifies exactly once');
}

# THE TRANSITION THAT SENDS NOTHING, which is the entire purpose of `for`.
{
    my $r = run({ op => '>', threshold => 100, for => 60 * SEC, every => 30 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(30), rows => [ 'api', 50 ] },
        ]);
    is(states_of($r->[1])->{api}, 'ok', 'pending back to ok');
    is_deeply(kinds_of($r->[1]), [],
              '  sends NOTHING - notifying here is the flapping `for` prevents');
}

# `for` is measured on the condition holding CONTINUOUSLY. A flap inside the
# window resets it, or a rule that breaches for one second every minute fires
# after `for` of wall time and nobody understands why.
{
    my $r = run({ op => '>', threshold => 100, for => 60 * SEC, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },   # pending
          { at => at(10), rows => [ 'api', 150 ] },
          { at => at(20), rows => [ 'api', 10 ] },    # FLAP -> ok
          { at => at(30), rows => [ 'api', 150 ] },   # pending again
          { at => at(70), rows => [ 'api', 150 ] },   # 40s in
        ]);
    is(states_of($r->[2])->{api}, 'ok', 'a flap drops it out of pending');
    is(states_of($r->[3])->{api}, 'pending', '  and the next breach restarts it');
    is(states_of($r->[4])->{api}, 'pending',
       'at 70s of wall time but only 40s of holding, it has NOT fired');
    is_deeply(kinds_of($r->[4]), [], '  and nothing was sent');
}

# --- firing -> ok, which DOES notify ---------------------------------------

{
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(10), rows => [ 'api', 150 ] },
          { at => at(20), rows => [ 'api', 10 ] },
        ]);
    is(states_of($r->[1])->{api}, 'firing', 'with for => 0 it fires on the second tick');
    is(states_of($r->[2])->{api}, 'ok', 'and recovers');
    is_deeply(kinds_of($r->[2]), [ RESOLVED ], '  notifying resolved');
}

# --- STATE IS PER SERIES ----------------------------------------------------
#
# One state per rule is the bug that makes an alert resolve because a
# DIFFERENT service recovered.

{
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150, 'web', 150 ] },
          { at => at(10), rows => [ 'api', 150, 'web', 150 ] },
          { at => at(20), rows => [ 'api', 150, 'web', 10 ] },
        ]);
    my $s = states_of($r->[2]);
    is($s->{api}, 'firing', 'one service recovering does NOT resolve the other');
    is($s->{web}, 'ok',     '  and the recovered one is ok');
    is(scalar @{ $r->[2]{notes} }, 1, 'exactly one notification');
    is($r->[2]{notes}[0]{series}, 'web', '  naming the series that recovered');
}

{
    # Independent `for` windows: one starts breaching later than the other.
    my $r = run({ op => '>', threshold => 100, for => 30 * SEC, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150, 'web', 10 ] },
          { at => at(20), rows => [ 'api', 150, 'web', 150 ] },
          { at => at(40), rows => [ 'api', 150, 'web', 150 ] },
        ]);
    my $s = states_of($r->[2]);
    is($s->{api}, 'firing',  'the series that breached first fires first');
    is($s->{web}, 'pending', '  while the later one is still inside its own window');
}

# --- A VANISHED SERIES MUST NOT STAY FIRING --------------------------------

{
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(10), rows => [ 'api', 150 ] },   # firing
          { at => at(20), rows => [] },               # gone
          { at => at(45), rows => [] },               # 2*every later
        ]);
    is(states_of($r->[1])->{api}, 'firing', 'it is firing');
    is(states_of($r->[2])->{api}, 'stale',
       'the series disappearing makes it stale, NOT still firing');
    is(states_of($r->[3])->{api}, 'ok',
       '  and it leaves firing entirely within 2*every');
    is_deeply(kinds_of($r->[3]), [ VANISHED ],
       '  with a resolution that says the series stopped existing');
}

# A result with NO ROWS is not a result of false. An empty result means every
# known series is absent, which is stale - and pending must not be treated as
# a recovery either.
{
    my $r = run({ op => '>', threshold => 100, for => 60 * SEC, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },   # pending
          { at => at(10), rows => [] },
        ]);
    is(states_of($r->[1])->{api}, 'stale',
       'an empty result makes a pending series stale, not recovered');
    is_deeply(kinds_of($r->[1]), [], '  and sends nothing');
}

{
    # A stale series that comes back re-enters the machine from ok, so the
    # `for` window is measured afresh rather than from a stale `since`.
    my $r = run({ op => '>', threshold => 100, for => 30 * SEC, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },   # pending
          { at => at(10), rows => [] },               # stale
          { at => at(60), rows => [ 'api', 150 ] },   # back
        ]);
    is(states_of($r->[2])->{api}, 'pending',
       'a returning series restarts its window rather than firing immediately');
    is_deeply(kinds_of($r->[2]), [], '  and does not notify on return');
}

# --- AN EVALUATION FAILURE IS NOT "OK" -------------------------------------

{
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 10 ] },    # healthy
          { at => at(10), fail => 1 },
          { at => at(20), fail => 1 },
        ]);
    is(states_of($r->[1])->{api}, 'error',
       'a failed evaluation goes to error, NOT to ok');
    is_deeply(kinds_of($r->[1]), [ ERROR ], '  and notifies');
    is_deeply(kinds_of($r->[2]), [],
       'a second failure notifies NOTHING - once, not every tick');
}

{
    # A rule with no series yet must still be able to report that it cannot
    # evaluate. Otherwise a rule that has never succeeded is silent for ever.
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [ { at => at(0), fail => 1 } ]);
    is(scalar @{ $r->[0]{notes} }, 1,
       'a rule that has never evaluated still reports its failure');
    is($r->[0]{notes}[0]{kind}, ERROR, '  as an error');
}

{
    # And a recovery re-arms the latch, so the NEXT outage notifies again.
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 10 ] },
          { at => at(10), fail => 1 },
          { at => at(20), rows => [ 'api', 10 ] },
          { at => at(30), fail => 1 },
        ]);
    is(states_of($r->[2])->{api}, 'ok', 'a successful evaluation clears error');
    is_deeply(kinds_of($r->[3]), [ ERROR ],
       '  and the NEXT failure notifies again rather than being swallowed');
}

{
    # An error must not be mistaken for a resolution of a firing alert.
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(10), rows => [ 'api', 150 ] },   # firing
          { at => at(20), fail => 1 },
        ]);
    is(states_of($r->[2])->{api}, 'error',
       'a firing alert whose query then fails goes to error');
    my @kinds = @{ kinds_of($r->[2]) };
    is_deeply(\@kinds, [ ERROR ],
       '  and does NOT send a resolution it has no evidence for');
}

# --- the operators ----------------------------------------------------------

{
    my %want = ('>' => 'firing', '>=' => 'firing', '<' => 'ok',
                '<=' => 'ok', '==' => 'ok', '!=' => 'firing');
    for my $op (sort keys %want) {
        my $r = run({ op => $op, threshold => 100, for => 0, every => 10 * SEC },
            [
              { at => at(0),               rows => [ 'api', 150 ] },
              { at => at(10), rows => [ 'api', 150 ] },
            ]);
        is(states_of($r->[1])->{api}, $want{$op}, "150 $op 100 is $want{$op}");
    }
    my $r = run({ op => '>=', threshold => 150, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(10), rows => [ 'api', 150 ] },
        ]);
    is(states_of($r->[1])->{api}, 'firing', '>= fires exactly at the threshold');
}

# --- fired_at is stable while firing, and NEW after a re-fire --------------
#
# It is part of the outbox dedupe key, so a re-fire that reused the old value
# would be deduplicated away and never delivered.

{
    my $r = run({ op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [
          { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(10), rows => [ 'api', 150 ] },   # fires
          { at => at(20), rows => [ 'api', 150 ] },   # still firing
          { at => at(30), rows => [ 'api', 10 ] },    # resolves
          { at => at(40), rows => [ 'api', 150 ] },
          { at => at(50), rows => [ 'api', 150 ] },   # fires again
        ]);
    my $first = $r->[1]{notes}[0]{fired_at};
    is("$first", at(10), 'fired_at is when it fired');
    my ($st) = grep { $_->{series} eq 'api' } @{ $r->[2]{states} };
    is("$st->{fired_at}", "$first", '  and does not move while it stays firing');
    my $again = $r->[5]{notes}[0]{fired_at};
    isnt("$again", "$first",
         'a re-fire gets a NEW fired_at, or the outbox would dedupe it away');
}

# --- the timeline the states are drawn on -----------------------------------
#
# A table of current state cannot say how long or how often, which is the pair
# of questions somebody opens the alerts screen to answer. The bands come from
# recorded transitions and never from inference.
{
    require Punk::Observe::Plot;
    require Punk::Observe::Store;
    my $T = '1787000000000000000';
    my $at = sub { Punk::Observe::Store::nadd($T, $_[0] * 1_000_000_000) };

    my $events = [
        { series => 'api', to => 'firing',  at => $at->(60)  },
        { series => 'api', to => 'ok',      at => $at->(300) },
        { series => 'api', to => 'firing',  at => $at->(600) },
        { series => 'web', to => 'pending', at => $at->(120) },
    ];
    my $fig = Punk::Observe::Plot::alert_timeline($events, to => $at->(900));
    ok($fig, 'transitions become a timeline');

    my @bands = @{ $fig->{data} };
    is(scalar @bands, 4, 'one band per transition');

    # A BAND RUNS TO THE NEXT TRANSITION, not to a fixed width. The interval
    # is the whole information content: two bands of equal width would say a
    # four-minute outage and a five-hour one were the same event.
    my %w = map { ("$_->{y}[0]/$_->{name}/$_->{base}[0]" => $_->{x}[0]) } @bands;
    is($w{'api/firing/' . Punk::Observe::Plot::ms($at->(60))}, 240_000,
       'a band ends where the next transition begins');
    is($w{'api/ok/' . Punk::Observe::Plot::ms($at->(300))}, 300_000,
       '  and the one after it does too');

    # AN ONGOING STATE RUNS TO THE EDGE. Ending it at its own transition would
    # draw an incident that is still happening as an instant that finished the
    # moment it started - on the screen somebody is looking at during it.
    is($w{'api/firing/' . Punk::Observe::Plot::ms($at->(600))}, 300_000,
       'the last band runs to the end, because that state is still in force');
    is($w{'web/pending/' . Punk::Observe::Plot::ms($at->(120))}, 780_000,
       '  including a series with only one transition');

    # One legend entry per STATE. A rule that flapped twelve times would
    # otherwise contribute twelve identical rows to the legend.
    my @shown = grep { ref $_->{showlegend} && ${ $_->{showlegend} } } @bands;
    is(scalar @shown, 3, 'the legend names each state once, not each band');

    # The bands carry the same colours as the badges in the table, by role.
    my %role = map { $_->{name} => $_->{marker}{color} } @bands;
    is($role{firing},  'err',  'firing is the error colour');
    is($role{pending}, 'warn', 'pending is the warning colour');
    is($role{ok},      'ok',   'ok is the ok colour');

    # NO TRANSITIONS MEANS NO CHART, not an empty one. An empty panel reads as
    # "nothing has happened", which is a different and unearned claim.
    ok(!defined Punk::Observe::Plot::alert_timeline([], to => $at->(900)),
       'no recorded history draws nothing at all');
    ok(!defined Punk::Observe::Plot::alert_timeline({ rules => [] }),
       '  and a seam that supplied no events does too');
}

done_testing();

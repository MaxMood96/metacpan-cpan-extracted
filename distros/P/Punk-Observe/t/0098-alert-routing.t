#!perl
# Grouping, silences, the outbox key, and where a webhook may point.
#
# A DEPLOY BREAKS FORTY SERVICES AT ONCE, and delivering that as forty
# messages is how a channel gets muted. The grouping assertions below are
# about that one event.
#
# Nothing sleeps here either: `group_wait` is observed by moving the clock.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $R = 'Punk::Observe::Route';
my $T = 'Punk::Observe::Target';
sub route { $R->can('run')->($_[0], $_[1]) }
sub tgt   { $T->can('check')->($_[0], $_[1]) }

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

# --- grouping ---------------------------------------------------------------

# FORTY SERIES IS ONE EVENT.
{
    my @ev = map {
        { at => at($_ / 10), group => 'prod', series => "svc$_",
          rule => '1', fired_at => at(0) }
    } 1 .. 40;
    # The sender waking up after group_wait, carrying no series.
    push @ev, { at => at(31) };

    my $r = route({ group_wait => 30 * SEC }, \@ev);
    is(scalar @{ $r->{sent} }, 1, 'forty firing series send ONE notification');
    is($r->{sent}[0]{count}, 40, '  listing all forty');
    is($r->{sent}[0]{group}, 'prod', '  under the group key');
    is($r->{sent}[0]{overflow}, 0, '  with nothing counted as overflow');
}

# The forty-first, arriving after the group was sent, is a SECOND
# notification - not a lost one.
{
    my @ev = map {
        { at => at($_ / 10), group => 'prod', series => "svc$_",
          rule => '1', fired_at => at(0) }
    } 1 .. 40;
    push @ev, { at => at(31) };                    # first send
    push @ev, { at => at(40), group => 'prod',
                series => 'svc41', rule => '1', fired_at => at(0) };
    push @ev, { at => at(80) };                    # second send

    my $r = route({ group_wait => 30 * SEC }, \@ev);
    is(scalar @{ $r->{sent} }, 2, 'one arriving after the send opens a new group');
    is($r->{sent}[1]{count}, 1, '  carrying just that one');
    is($r->{sent}[1]{members}[0], 'svc41', '  and naming it');
}

# GROUP_WAIT DELAYS THE FIRST NOTIFICATION. That is the intent, and the test
# says so because the UI has to.
{
    my $r = route({ group_wait => 30 * SEC },
        [
          { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) },
          { at => at(29) },
        ]);
    is(scalar @{ $r->{sent} }, 0, 'nothing is sent before group_wait elapses');
}

{
    my $r = route({ group_wait => 0 },
        [ { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) } ]);
    is(scalar @{ $r->{sent} }, 1, 'group_wait of zero sends immediately');
}

# Different group keys are different messages: a break in staging must not be
# folded into the production page.
{
    my $r = route({ group_wait => 0 },
        [
          { at => at(0), group => 'prod',    series => 'api', rule => '1',
            fired_at => at(0) },
          { at => at(0), group => 'staging', series => 'api', rule => '1',
            fired_at => at(0) },
        ]);
    is(scalar @{ $r->{sent} }, 2, 'two group keys are two notifications');
    is_deeply([ sort map { $_->{group} } @{ $r->{sent} } ],
              [ 'prod', 'staging' ], '  one per group');
}

# repeat_interval re-notifies while still firing.
{
    my $r = route({ group_wait => 0, repeat_interval => 300 * SEC },
        [
          { at => at(0),                group => 'prod', series => 'api',
            rule => '1', fired_at => at(0) },
          { at => at(100) },
          { at => at(400) },
        ]);
    is(scalar @{ $r->{sent} }, 2, 'a still-firing group repeats after the interval');
}

{
    my $r = route({ group_wait => 0 },
        [
          { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) },
          { at => at(10000) },
        ]);
    is(scalar @{ $r->{sent} }, 1,
       'with no repeat_interval it is sent once and not again');
}

# --- the outbox dedupe key --------------------------------------------------
#
# (rule, series, fired_at). A retried job recomputes the same key and is
# refused, so a delivery can never happen twice however many times it runs.

{
    my $ev = { at => at(0), group => 'prod', series => 'api', rule => '1',
               fired_at => at(0) };
    my $r = route({ group_wait => 0 }, [ $ev, { %$ev }, { %$ev } ]);
    is($r->{enqueued}, 1, 'the same notification enqueues once');
    is($r->{deduped}, 2, '  and two retries are deduplicated');
}

{
    # A re-fire is a NEW notification, not a duplicate. If fired_at were left
    # out of the key, the second page would never be sent.
    my $r = route({ group_wait => 0 },
        [
          { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) },
          { at => at(600), group => 'prod', series => 'api',
            rule => '1', fired_at => at(600) },
        ]);
    is($r->{enqueued}, 2, 'a re-fire is a new notification, not a duplicate');
    is($r->{deduped}, 0, '  and nothing was deduplicated away');
}

{
    # Same series, different rule: two notifications.
    my $r = route({ group_wait => 0 },
        [
          { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) },
          { at => at(0), group => 'prod', series => 'api', rule => '2',
            fired_at => at(0) },
        ]);
    is($r->{enqueued}, 2, 'two rules on one series are two notifications');
}

# A CLAIMED ROW IS NOT CLAIMABLE BY A SECOND SENDER.
{
    my @ev = map {
        { at => at(0), group => 'prod', series => "svc$_", rule => '1',
          fired_at => at(0) }
    } 1 .. 5;
    my $r = route({ group_wait => 0 }, \@ev);
    is($r->{claimed}, 5, 'every queued notification is claimable once');
    is($r->{reclaimed}, 0, '  and a second sender claims NOTHING');
    is($r->{pending}, 5, '  five were queued to begin with');
    is($r->{pending_after}, 0, '  and none is left once they are claimed');
}

# --- silences suppress NOTIFICATION, not STATE ------------------------------

{
    my $r = route({ group_wait => 0,
                    silences => [ { pattern => 'api' } ] },
        [ { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) } ]);
    is(scalar @{ $r->{sent} }, 0, 'a silenced series does not page');
    is($r->{enqueued}, 0, '  and nothing reaches the outbox');
}

{
    # The state machine is a different file and knows nothing about silences,
    # which is the point: a silenced rule still reaches firing and still
    # renders red. Asserted where the state actually lives.
    my $a = 'Punk::Observe::Alert';
    my $s = $a->can('run')->(
        { op => '>', threshold => 100, for => 0, every => 10 * SEC },
        [ { at => at(0),               rows => [ 'api', 150 ] },
          { at => at(10), rows => [ 'api', 150 ] } ]);
    my ($st) = grep { $_->{series} eq 'api' } @{ $s->[1]{states} };
    is($st->{state}, 'firing',
       'a silence cannot reach the state machine, so the alert still shows red');
}

{
    my $r = route({ group_wait => 0,
                    silences => [ { pattern => 'db-', prefix => 1 } ] },
        [
          { at => at(0), group => 'prod', series => 'db-primary', rule => '1',
            fired_at => at(0) },
          { at => at(0), group => 'prod', series => 'api', rule => '1',
            fired_at => at(0) },
        ]);
    is($r->{enqueued}, 1, 'a prefix silence covers the matching series');
    is($r->{sent}[0]{count}, 1, '  and only the others are notified');
    is($r->{sent}[0]{members}[0], 'api', '  naming the unsilenced one');
}

# AN EXPIRED SILENCE MUST NOT KEEP SUPPRESSING. One set for a deploy and
# forgotten is how a real page goes unsent for a month.
{
    my $r = route({ group_wait => 0,
                    silences => [ { pattern => 'api',
                                    until => at(60) } ] },
        [
          { at => at(0),                group => 'p', series => 'api',
            rule => '1', fired_at => at(0) },
          { at => at(120), group => 'p', series => 'api',
            rule => '1', fired_at => at(120) },
        ]);
    is($r->{enqueued}, 1, 'an expired silence stops suppressing');
    is(scalar @{ $r->{sent} }, 1, '  and the later firing is delivered');
}

# --- WHERE A WEBHOOK MAY POINT ----------------------------------------------
#
# The server makes a request to a URL a user typed into a form. That is an
# SSRF, and the classic target is a cloud metadata service.

{
    my $r = tgt('https://hooks.example.com/services/abc', undef);
    ok($r->{ok}, 'an ordinary https webhook is allowed');
    $r = tgt('http://hooks.example.com/x', undef);
    ok($r->{ok}, '  and plain http is too');
}

{
    my @refuse = (
        [ 'http://127.0.0.1/x'          => 'loopback' ],
        [ 'http://127.1.2.3/x'          => 'loopback' ],
        [ 'http://localhost:5432/x'     => 'loopback' ],
        [ 'http://api.localhost/x'      => 'loopback' ],
        [ 'http://0.0.0.0/x'            => 'loopback' ],
        [ 'http://[::1]/x'              => 'loopback' ],
        [ 'http://169.254.169.254/latest/meta-data/' => 'link-local' ],
        [ 'http://metadata.google.internal/x'        => 'link-local' ],
        [ 'http://[fe80::1]/x'          => 'link-local' ],
        [ 'http://printer.local/x'      => 'link-local' ],
        [ 'http://10.0.0.5/x'           => 'private' ],
        [ 'http://172.16.4.1/x'         => 'private' ],
        [ 'http://172.31.255.255/x'     => 'private' ],
        [ 'http://192.168.1.1/x'        => 'private' ],
        [ 'http://100.64.0.1/x'         => 'private' ],
        [ 'http://db.internal/x'        => 'private' ],
        [ 'http://[fc00::1]/x'          => 'private' ],
    );
    for my $c (@refuse) {
        my $r = tgt($c->[0], undef);
        ok(!$r->{ok}, "$c->[0] is refused");
        like($r->{reason}, qr/\Q$c->[1]\E/, "  as $c->[1]");
    }
}

# A DECOY BEFORE THE @ IS THE CLASSIC BYPASS. A parser that stops at the
# first delimiter reads `hooks.example.com` and fetches 127.0.0.1.
{
    my $r = tgt('http://hooks.example.com@127.0.0.1/x', undef);
    ok(!$r->{ok}, 'userinfo cannot disguise a loopback host');
    like($r->{reason}, qr/loopback/, '  the real host is what is judged');
}

{
    # IPv4-mapped IPv6 is loopback wearing a hat.
    my $r = tgt('http://[::ffff:127.0.0.1]/x', undef);
    ok(!$r->{ok}, 'an IPv4-mapped loopback is refused');
}

{
    # A scheme that is not a webhook destination under any policy.
    for my $u ('file:///etc/passwd', 'gopher://x/', 'ftp://x/', '/relative',
               'javascript:alert(1)', '') {
        my $r = tgt($u, undef);
        ok(!$r->{ok}, "'$u' is refused");
    }
    my $r = tgt('file:///etc/passwd', [ 'example.com' ]);
    ok(!$r->{ok}, 'and an allowlist does NOT override the scheme');
}

# The allowlist is how an operator says an internal target is deliberate.
{
    my $r = tgt('http://10.0.0.5/hook', [ '10.0.0.5' ]);
    ok($r->{ok}, 'an allowlisted internal address is permitted');

    $r = tgt('https://hooks.slack.com/x', [ 'slack.com' ]);
    ok($r->{ok}, 'a dot-anchored suffix matches a subdomain');

    # THE ANCHOR MATTERS. `slack.com` must not admit
    # `slack.com.attacker.net`, which a plain suffix compare would.
    $r = tgt('https://slack.com.attacker.net/x', [ 'slack.com' ]);
    ok(!$r->{ok}, 'a suffix that is not dot-anchored does NOT match');

    $r = tgt('https://notslack.com/x', [ 'slack.com' ]);
    ok(!$r->{ok}, '  nor does a host that merely ends with the entry');

    # An allowlist that exists is exhaustive: falling through to the default
    # ranges would make it a suggestion rather than a policy.
    $r = tgt('https://example.org/x', [ 'slack.com' ]);
    ok(!$r->{ok}, 'an allowlist is exhaustive, not additive');
    like($r->{reason}, qr/allowlist/, '  and says so');
}

# Case is not a bypass.
{
    for my $u ('HTTP://LOCALHOST/x', 'http://LocalHost/x', 'HtTpS://127.0.0.1/') {
        my $r = tgt($u, undef);
        ok(!$r->{ok}, "'$u' is refused whatever the case");
    }
}

done_testing();

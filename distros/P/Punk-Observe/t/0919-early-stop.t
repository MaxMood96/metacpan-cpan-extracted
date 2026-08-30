#!perl
# The early stop: a limited newest-first read pays for the newest segments
# and stops, instead of decoding the whole window and throwing most of it
# away.
#
# The rule: segments are walked by their own t_max, newest first (seal-name
# order is NOT record order - a worker that fell behind seals old records
# after its neighbours sealed newer ones). Once `limit` records are in hand,
# a segment whose whole span is STRICTLY older than the limit-th newest key
# cannot change the answer, and neither can anything after it in that order.
#
# The result set must be element-for-element what the full scan would have
# produced; only the cost is allowed to differ. Every scripted branch below
# names the mutant it kills.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;

my $S  = 'Punk::Observe::Store';
my $T0 = '1774224000000000000';

sub nadd {
    my ($a, $b) = @_;
    my @a = reverse split //, "$a";
    my @b = reverse split //, "$b";
    my ($carry, @out) = (0);
    for my $i (0 .. (@a > @b ? $#a : $#b)) {
        my $d = ($a[$i] || 0) + ($b[$i] || 0) + $carry;
        $carry = $d >= 10 ? 1 : 0;
        push @out, $d % 10;
    }
    push @out, $carry if $carry;
    return join '', reverse @out;
}

sub logline {
    my (%o) = @_;
    return {
        kind => 2, t => $o{t}, body => $o{body},
        severity => 9, duration => 0,
        trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
        attrs => { 'service.name' => 'svc' },
    };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

sub age { utime($_[0], $_[0], $wdir) or die "utime: $!" }

# Five segments with disjoint known spans: segment k holds ten records at
# T0 + k*10s + i (i in 0..9). Newest segment is 4, oldest 0.
for my $k (0 .. 4) {
    my @batch = map {
        logline(t => nadd($T0, $k * 10_000_000_000 + $_ * 1_000_000_000),
                body => "s$k r$_")
    } 0 .. 9;
    Punk::Observe::WAL::append($store->wal_path, \@batch, 0, 0);
    $store->seal;
}
age(time - 60);

# --- the answer is the full scan's answer ------------------------------------
#
# Kills the stop-too-early mutant: any rule that stops before the boundary
# segment loses one of these exact bodies.
{
    my ($full)      = $store->records(limit => 1_000_000);
    my ($lim, $m)   = $store->records(limit => 12);
    is(scalar @$lim, 12, 'the limit is honoured');
    is_deeply([ map { $_->{body} } @$lim ],
              [ map { $_->{body} } @{ $full }[0 .. 11] ],
              'element for element, the limited read IS the full scan cut');

    # Kills the never-stop mutant: 12 newest records live in segments 4 and
    # 3; segments 2, 1, 0 must not be opened.
    is($m->{files}, 2, 'only the two newest segments were read');
    is($m->{truncated}, 1, '  and the answer says it is a cut');
}

# --- a boundary tie still scans the next segment -----------------------------
#
# Segment A's oldest kept key EQUALS segment B's t_max. Strictly-less must
# scan B; the <=-for-< mutant skips it and loses the tied record.
{
    my $d2 = tempdir(CLEANUP => 1);
    my $s2 = $S->new(dir => $d2, tenant => 'acme');
    my $w2 = File::Spec->catdir($d2, 'acme', 'wal');

    # B seals first (older name), holding ONE record at exactly T0+5s.
    Punk::Observe::WAL::append($s2->wal_path,
        [ logline(t => nadd($T0, 5_000_000_000), body => 'B tie') ], 0, 0);
    $s2->seal;
    # A holds two records: T0+5s (the tie) and T0+6s.
    Punk::Observe::WAL::append($s2->wal_path,
        [ logline(t => nadd($T0, 5_000_000_000), body => 'A tie'),
          logline(t => nadd($T0, 6_000_000_000), body => 'A newest') ], 0, 0);
    $s2->seal;
    utime(time - 60, time - 60, $w2) or die "utime: $!";

    # limit=2: after A, the 2nd-newest key is T0+5s; B's t_max is T0+5s.
    # Not strictly older, so B is scanned and the tie is broken by the sort,
    # not by silently never seeing B's record.
    my ($r, $m) = $s2->records(limit => 2);
    is($m->{files}, 2, 'a span ending ON the kth key is still scanned');

    # And with room for all three, everything arrives.
    my ($all) = $s2->records(limit => 10);
    is(scalar @$all, 3, '  no record was lost to the boundary');
}

# --- seal-name order is not record order -------------------------------------
#
# A late worker seals OLD records AFTER a segment full of new ones. Walking
# by name-newest would stop before reaching the newer records' segment... so
# the walk goes by t_max. The mutant that walks by name loses 'new 1'.
{
    my $d3 = tempdir(CLEANUP => 1);
    my $s3 = $S->new(dir => $d3, tenant => 'acme');
    my $w3 = File::Spec->catdir($d3, 'acme', 'wal');

    # First seal: NEW records (t = T0+100s, +101s).
    Punk::Observe::WAL::append($s3->wal_path,
        [ logline(t => nadd($T0, 100_000_000_000), body => 'new 0'),
          logline(t => nadd($T0, 101_000_000_000), body => 'new 1') ], 0, 0);
    $s3->seal;
    # Second seal, LATER NAME, older records (t = T0, +1s) - the laggard.
    Punk::Observe::WAL::append($s3->wal_path,
        [ logline(t => nadd($T0, 0), body => 'old 0'),
          logline(t => nadd($T0, 1_000_000_000), body => 'old 1') ], 0, 0);
    $s3->seal;
    utime(time - 60, time - 60, $w3) or die "utime: $!";

    my ($r, $m) = $s3->records(limit => 2);
    is_deeply([ map { $_->{body} } @$r ], [ 'new 1', 'new 0' ],
              'the newest records win although their segment sealed first');
    is($m->{files}, 1, '  and the laggard segment was never opened');
    is($m->{truncated}, 1, '  and truncated says more existed');
}

# --- live records come first and count against the limit ---------------------
{
    Punk::Observe::WAL::append($store->wal_path,
        [ map { logline(t => nadd($T0, 200_000_000_000 + $_ * 1_000_000_000),
                        body => "live $_") } 0 .. 11 ], 0, 0);
    # A DIFFERENT past second: re-aging to the same one the snapshot is
    # keyed on would hide the new wal file behind a matching key.
    age(time - 50);

    my ($r, $m) = $store->records(limit => 12);
    is_deeply([ map { $_->{body} } @$r ],
              [ map { "live " . (11 - $_) } 0 .. 11 ],
              'twelve live records fill the whole limit, newest first');
    is($m->{files}, 1, '  and no sealed segment was opened at all');
}

# --- truncated is honest in both directions ----------------------------------
{
    # Everything fits: not truncated, and the stop never fired wrongly.
    my ($all, $m1) = $store->records(limit => 1_000_000);
    is($m1->{truncated}, 0, 'a limit nothing hits reports no cut');
    is(scalar @$all, 62, '  and everything is there');

    # The stop leaves only OUT-OF-WINDOW segments behind: not truncated.
    # Window covers segment 4 and the live records; limit is filled from
    # the live records; segments 3..0 are behind the stop but outside the
    # window, so nothing more could have answered. The mutant that sets
    # truncated on "stopped at all" lies here.
    my ($r, $m2) = $store->records(from  => nadd($T0, 40_000_000_000),
                                   limit => 12);
    is($m2->{truncated}, 1, 'a cut inside the window says so');
    my ($r3, $m3) = $store->records(from  => nadd($T0, 200_000_000_000),
                                    limit => 12);
    is(scalar @$r3, 12, 'the window holds exactly the limit');
    is($m3->{truncated}, 0,
       '  and stopping over out-of-window remains is not a cut');
}

done_testing();

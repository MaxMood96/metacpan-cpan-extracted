#!perl
# bucket() and rate(), against a reference that shares no code with them.
#
# rate() PARSED AND THEN DID NOTHING for the whole of phases 8 and 9. The
# window went into the AST and the executor never read it, so `rate(5m) by
# status` was a plain count over the whole range wearing the name of something
# time-binned. The grammar advertised it, the top-level SYNOPSIS used it as
# its headline example, and no test ever executed one - every test that
# mentioned rate only ever parsed it.
#
# So the assertions here are mostly about the NUMBERS, not the shape.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use Math::BigInt;

my $E = 'Punk::Observe::Exec';
sub run { $E->can('run')->($_[0], $_[1], $_[2] // {}) }

# A 2026-ish instant, well past 2^53 nanoseconds, as a decimal string. Every
# timestamp in this file is built from it by string arithmetic: computing one
# with ordinary Perl numbers would silently round the low digits and the test
# would then be asserting against the rounding.
my $T0 = '1787000000000000000';
sub at { Math::BigInt->new($T0)->badd(Math::BigInt->new($_[0]))->bstr }

my $SEC = 1_000_000_000;
my $MIN = 60 * $SEC;

# --- the reference ----------------------------------------------------------
#
# Brute force, in big integers, with no knowledge of how the executor groups.
# The bucket of an instant is floor(t / width) - which is the whole definition,
# and stating it independently is the point.
sub ref_buckets {
    my ($rows, $width, $keyfn) = @_;
    my %out;
    for my $r (@$rows) {
        my $idx = Math::BigInt->new($r->{t})->bdiv(Math::BigInt->new($width));
        my $k = $keyfn ? $keyfn->($r) : '';
        push @{ $out{$k}{ $idx->bstr } }, $r;
    }
    return \%out;
}

sub points_of {
    my ($res, $key) = @_;
    $key = '' unless defined $key;
    for my $s (@{ $res->{series} || [] }) {
        return $s->{points} if $s->{key} eq $key;
    }
    return undef;
}

# --- a corpus with known boundaries -----------------------------------------

sub logs_every_second {
    my ($n, $svc) = @_;
    return [ map {
        { kind => 'log', t => at($_ * $SEC), severity => 9,
          service => ($svc ? $svc->($_) : 'api'), body => 'line' }
    } 0 .. $n - 1 ];
}

# --- it bins at all ---------------------------------------------------------

{
    my $rows = logs_every_second(300);
    my $r = run('log | bucket(1m)', $rows);

    ok($r->{ok}, 'a bucketed query runs');
    is($r->{shape}, 'buckets', '  and says its shape is buckets');
    is($r->{bucket_ns}, "$MIN", '  and carries the width it used');

    my $pts = points_of($r);
    ok($pts && @$pts, '  and returns points');

    # EVERY ROW IN EXACTLY ONE BUCKET. Not "about the right number" - the
    # counts must sum to the corpus, or a row is being dropped or double
    # counted and neither shows up in a spot check.
    my $total = 0;
    $total += $_->[1] for @$pts;
    is($total, 300, 'every row lands in exactly one bucket');

    # Ascending in time, because a chart handed unordered points draws a line
    # that doubles back on itself.
    my @t = map { Math::BigInt->new($_->[0]) } @$pts;
    my $sorted = 1;
    for my $i (1 .. $#t) { $sorted = 0 if $t[$i] <= $t[$i - 1] }
    ok($sorted, '  and the points come out in time order');
}

# --- against the reference --------------------------------------------------

{
    my $rows = logs_every_second(500, sub { $_[0] % 3 == 0 ? 'api' : 'web' });

    for my $w ([ '30s', 30 * $SEC ], [ '1m', $MIN ], [ '5m', 5 * $MIN ]) {
        my ($spell, $width) = @$w;
        my $r = run("log | bucket($spell) count by service", $rows);
        ok($r->{ok}, "bucket($spell) runs") or next;

        my $want = ref_buckets($rows, $width, sub { $_[0]{service} });
        my $bad = 0;
        for my $svc (sort keys %$want) {
            my $pts = points_of($r, $svc);
            unless ($pts) { $bad++; next }
            # The reference keys by bucket INDEX; the result reports the
            # instant. One is the other times the width, and asserting that
            # relationship is asserting the timestamps are right.
            my %got = map {
                Math::BigInt->new($_->[0])->bdiv($width)->bstr => $_->[1]
            } @$pts;
            for my $idx (keys %{ $want->{$svc} }) {
                my $n = scalar @{ $want->{$svc}{$idx} };
                $bad++ unless defined $got{$idx} && $got{$idx} == $n;
            }
            $bad++ unless keys(%got) == keys(%{ $want->{$svc} });
        }
        is($bad, 0, "  every bucket of bucket($spell) matches the reference");
    }
}

# --- the boundary -----------------------------------------------------------
#
# A point exactly on a boundary is the case a hand-written binning gets wrong,
# and it gets it wrong by one bucket in a way no aggregate total reveals.
{
    # Three instants: one just below a minute boundary, one exactly on it, one
    # just above. Built from a known multiple of the width so "the boundary" is
    # exact rather than approximately right.
    my $base = Math::BigInt->new($T0);
    my $b = $base->copy->bdiv($MIN)->badd(1)->bmul($MIN);   # the next boundary

    my $rows = [
        { kind => 'log', t => $b->copy->bsub(1)->bstr, severity => 9,
          service => 'api', body => 'before' },
        { kind => 'log', t => $b->bstr, severity => 9,
          service => 'api', body => 'on' },
        { kind => 'log', t => $b->copy->badd(1)->bstr, severity => 9,
          service => 'api', body => 'after' },
    ];

    my $r = run('log | bucket(1m)', $rows);
    my $pts = points_of($r);
    is(scalar @$pts, 2, 'three instants around a boundary make two buckets');
    is($pts->[0][1], 1, '  the instant below it is alone in the earlier one');
    is($pts->[1][1], 2, '  the boundary instant belongs to the LATER bucket');
    is(Math::BigInt->new($pts->[1][0])->bstr, $b->bstr,
       '  and that bucket starts exactly on the boundary');
}

# --- the boundaries do not move when the question does ----------------------
#
# Aligning bucket 0 to the start of the window is the obvious implementation.
# It means panning a chart by thirty seconds moves every boundary, so the same
# minute of traffic reports a different number before and after, and two
# panels whose ranges differ slightly disagree with nothing to explain it.
{
    my $all   = logs_every_second(600);
    my $later = [ @{$all}[ 137 .. 499 ] ];      # an arbitrary sub-range

    my $ra = run('log | bucket(1m)', $all);
    my $rb = run('log | bucket(1m)', $later);

    my %a = map { $_->[0] => $_->[1] } @{ points_of($ra) };
    my %b = map { $_->[0] => $_->[1] } @{ points_of($rb) };

    # Every bucket the narrower query fully contains must report the identical
    # number. The partial ones at each end legitimately differ.
    my @shared = grep { exists $a{$_} } keys %b;
    ok(scalar @shared >= 3, 'the two windows share several buckets');

    my $same = 0;
    for my $t (@shared) {
        # A bucket is fully inside the narrow range if the narrow range has
        # a bucket on each side of it.
        my $lo = Math::BigInt->new($t)->bsub($MIN)->bstr;
        my $hi = Math::BigInt->new($t)->badd($MIN)->bstr;
        next unless exists $b{$lo} && exists $b{$hi};
        $same++ if $a{$t} == $b{$t};
    }
    ok($same >= 1, 'a bucket asked for twice reports the same number both times')
        or diag('bucket boundaries move with the window');
}

# --- rate is the aggregate over the span ------------------------------------

{
    my $rows = logs_every_second(300);
    my $c = run('log | bucket(1m)', $rows);
    my $r = run('log | rate(1m)',   $rows);

    my @counts = map { $_->[1] } @{ points_of($c) };
    my @rates  = map { $_->[1] } @{ points_of($r) };

    is(scalar @rates, scalar @counts, 'rate and bucket produce the same points');
    my $bad = 0;
    for my $i (0 .. $#counts) {
        $bad++ if abs($rates[$i] - $counts[$i] / 60) > 1e-9;
    }
    is($bad, 0, '  and every rate is its count over the window in seconds');

    # ONE PER SECOND IS ONE PER SECOND WHATEVER THE WINDOW. That invariance is
    # the entire reason to report a rate rather than a count, so it is asserted
    # across two widths rather than assumed from the division above.
    #
    # It needs enough data to contain a COMPLETE bucket of the wider width:
    # boundaries are epoch-aligned, so 300 seconds of rows straddles two
    # five-minute buckets and fills neither.
    my $long = logs_every_second(1200);
    for my $spell (qw(1m 5m)) {
        my $res = run("log | rate($spell)", $long);
        my @full = grep { $_ > 0.99 && $_ < 1.01 }
                   map { $_->[1] } @{ points_of($res) };
        ok(scalar @full >= 1,
           "a complete $spell bucket of one-per-second reports ~1/s");
    }
}

# --- a percentile is not a rate ---------------------------------------------
#
# Dividing a p95 by the window would report a service getting faster because
# somebody widened the bucket.
{
    my $rows = [ map {
        { kind => 'span', t => at($_ * $SEC),
          duration => "" . (($_ % 100) * 1_000_000), service => 'api' }
    } 0 .. 299 ];

    my $b = run('spans | bucket(1m) p95', $rows);
    my $r = run('spans | rate(1m) p95',   $rows);

    my @bp = map { $_->[1] } @{ points_of($b) };
    my @rp = map { $_->[1] } @{ points_of($r) };
    is_deeply(\@rp, \@bp, 'a p95 under rate() is not divided by the window');
    ok((grep { $_ > 0 } @bp) > 0, '  and it is a real latency, not zero');
}

# --- the aggregate composes with the bucket ---------------------------------

{
    my $rows = [ map {
        { kind => 'span', t => at($_ * $SEC),
          duration => "" . (($_ % 60) * 1_000_000), service => 'api' }
    } 0 .. 179 ];

    my $r = run('spans | bucket(1m) max', $rows);
    my $want = ref_buckets($rows, $MIN);
    my $pts = points_of($r);

    my $bad = 0;
    for my $p (@$pts) {
        my $idx = Math::BigInt->new($p->[0])->bdiv($MIN)->bstr;
        my @d = sort { $a <=> $b } map { $_->{duration} } @{ $want->{''}{$idx} };
        $bad++ unless abs($p->[1] - $d[-1]) < 1e-6;
    }
    is($bad, 0, 'max is computed per bucket, not across the whole range');

    # The stage can also be written apart from its aggregate, and then the
    # aggregate must survive: a default applied at parse time overwrote it.
    my $split = run('spans | max | bucket(1m)', $rows);
    if ($split->{ok}) {
        my $sp = points_of($split);
        is_deeply([ map { $_->[1] } @$sp ], [ map { $_->[1] } @$pts ],
                  '  and `| max | bucket(1m)` means the same as `bucket(1m) max`');
    }
    else {
        pass('  `| max | bucket(1m)` is refused rather than silently counting');
    }
}

# --- an absent bucket is absent, and that is deliberate ---------------------
#
# Synthesising a zero for a bucket with no rows is right for a count and a
# fabrication for anything else: a p95 of no samples is undefined, not zero,
# and a chart drawn from invented zeros shows a latency cliff that never
# happened. The window is not known here anyway - only the caller knows what
# range was asked for - so gaps are left for the layer that does.
{
    my $rows = [
        { kind => 'log', t => at(0),         severity => 9, service => 'api', body => 'a' },
        { kind => 'log', t => at(600 * $SEC), severity => 9, service => 'api', body => 'b' },
    ];
    my $r = run('log | bucket(1m)', $rows);
    my $pts = points_of($r);
    is(scalar @$pts, 2, 'two rows ten minutes apart make two points, not eleven');
    ok(Math::BigInt->new($pts->[1][0])->bsub($pts->[0][0])->bstr > $MIN,
       '  and the gap between them is visible to the caller');
}

# --- it refuses rather than answering something unreadable ------------------

{
    my $rows = logs_every_second(12_000);
    my $r = run('log | bucket(1s)', $rows);
    ok(!$r->{ok}, 'a query with more buckets than anything can draw is refused');
    like($r->{error} || '', qr/wider bucket|shorter range|fewer/,
         '  and the message says what to change');
    ok($r->{meta}{scanned_rows} > 0,
       '  and it still reports how much it read before refusing');

    my $ok = run('log | bucket(1h)', $rows);
    ok($ok->{ok}, 'the same rows with a sensible width answer fine');
}

# --- the parse errors carry an example --------------------------------------

{
    my $Q = 'Punk::Observe::Query';
    for my $case (
        [ 'log | bucket'      => qr/window/,            'no window at all' ],
        [ 'log | bucket(5)'   => qr/needs a duration/,  'a bare number' ],
        [ 'log | bucket(0s)'  => qr/cannot be zero/,    'a zero window' ],
        [ 'log | bucket(1m'   => qr/\)/,                'an unclosed paren' ],
    ) {
        my ($q, $re, $why) = @$case;
        my $r = $Q->can('parse')->($q);
        ok(!$r->{ok}, "refused: $why");
        like($r->{error} || '', $re, "  and says why: $why");
    }

    # A zero window is a division by zero in rate() and an unbounded bucket
    # count in bucket(). The lexer will not make one from `5m`, but `0s` lexes
    # perfectly well.
    my $r = $Q->can('parse')->('log | rate(0s)');
    ok(!$r->{ok}, 'rate(0s) is refused too, not divided by');
}

done_testing();

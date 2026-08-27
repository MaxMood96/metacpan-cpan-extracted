#!perl
# Rollups: exact where they can be, and REFUSED where they cannot.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $R = 'Punk::Observe::Retain';
sub roll { $R->can('rollup')->($_[0], $_[1]) }

# aggregate ids, from po_query.h
use constant { COUNT => 1, SUM => 2, AVG => 3, MIN => 4, MAX => 5,
               P50 => 6, P90 => 7, P95 => 8, P99 => 9 };

my $M  = 1_000_000_000;          # one second in ns
my $FM = 300 * $M;               # five minutes

# --- bucketing --------------------------------------------------------------

{
    # 15-second points across 20 minutes: four 5m buckets, one 1h bucket.
    my @pts = map { { t => "" . ($_ * 15 * $M), v => 1 } } 0 .. 79;
    my $r = roll(\@pts, COUNT);
    is($r->{n_5m}, 4, '20 minutes of points fall into four 5m buckets');
    is($r->{n_1h}, 1, '  and promote to a single 1h bucket');
    is($r->{value_5m}, 80, 'count over the 5m tier is every point');
    is($r->{value_1h}, 80, '  and the 1h tier agrees, without the raw data');
}

{
    my $r = roll([ { t => '0', v => 1 } ], COUNT);
    is($r->{n_5m}, 1, 'a single point is one bucket');
    is($r->{buckets_5m}[0]{t}, 0, '  aligned to the tier boundary');
}

{
    # A point one nanosecond before a boundary and one after must land in
    # different buckets - an off-by-one here misattributes every edge point.
    my $r = roll([ { t => "" . ($FM - 1), v => 1 },
                   { t => "$FM",         v => 2 } ], COUNT);
    is($r->{n_5m}, 2, 'points either side of a boundary are two buckets');
    is("$r->{buckets_5m}[0]{t}", '0', '  the first at 0');
    is("$r->{buckets_5m}[1]{t}", "$FM", '  the second at the boundary');
}

# --- the aggregates a rollup CAN answer, exactly ----------------------------

{
    # values 1..100 in one bucket: known answers.
    my @pts = map { { t => "" . ($_ * $M), v => $_ } } 1 .. 100;

    my $c = roll(\@pts, COUNT);
    is($c->{value_5m}, 100, 'count is exact');

    my $s = roll(\@pts, SUM);
    is($s->{value_5m}, 5050, 'sum is exact');

    my $a = roll(\@pts, AVG);
    ok(abs($a->{value_5m} - 50.5) < 1e-9, 'avg is exact, from sum over count');

    my $mn = roll(\@pts, MIN);
    is($mn->{value_5m}, 1, 'min is exact');

    my $mx = roll(\@pts, MAX);
    is($mx->{value_5m}, 100, 'max is exact');
}

# The closure property: the 1h tier is built from the 5m tier without the raw
# points, and must give the same answer.
{
    my @pts = map { { t => "" . ($_ * 10 * $M), v => ($_ % 37) + 1 } } 0 .. 359;
    for my $agg ([COUNT,'count'], [SUM,'sum'], [AVG,'avg'],
                 [MIN,'min'], [MAX,'max']) {
        my $r = roll(\@pts, $agg->[0]);
        ok($r->{ok_5m} && $r->{ok_1h}, "$agg->[1] is answerable from both tiers");
        ok(abs($r->{value_5m} - $r->{value_1h}) < 1e-9,
           "  and the 1h tier agrees with the 5m tier for $agg->[1]");
    }
    # The agreement above would be vacuous on a corpus that fits one bucket.
    my $shape = roll(\@pts, COUNT);
    cmp_ok($shape->{n_5m}, '>', 1, 'the corpus really did span several 5m buckets');
    cmp_ok($shape->{n_5m}, '>', $shape->{n_1h},
           '  and more 5m buckets than 1h ones, so promotion did something');
}

# --- THE REFUSAL ------------------------------------------------------------

# Percentiles do not merge from {count, sum, min, max}. There is no function
# of those that yields a p95, and every approximation that looks close is
# wrong in the tail - which is the only part of a latency chart anybody reads.
{
    my @pts = map { { t => "" . ($_ * $M), v => $_ } } 1 .. 300;
    for my $p ([P50,'p50'], [P90,'p90'], [P95,'p95'], [P99,'p99']) {
        my $r = roll(\@pts, $p->[0]);
        ok(!$r->{ok_5m}, "$p->[1] is REFUSED from a rollup, not approximated");
        ok(!$r->{ok_1h}, "  at the 1h tier too");
        ok(!exists $r->{value_5m}, "  with no value offered for $p->[1]");
        like($r->{refusal}, qr/percentile cannot be computed/,
             "  and a message explaining why");
        like($r->{refusal}, qr/histogram|shorten the range/,
             "  that says what to do instead");
    }
}

# --- counter resets survive into the rollup ---------------------------------

# The raw points are dropped after this. A rate over a rolled-up range with an
# undetected reset is simply wrong, with nothing left in the data to reveal it.
{
    my @pts;
    for my $i (0 .. 99) {
        push @pts, { t => "" . ($i * 10 * $M),
                     v => ($i < 50 ? $i * 10 : ($i - 50) * 10),
                     reset => ($i == 50 ? 1 : 0) };
    }
    my $r = roll(\@pts, SUM);
    is($r->{resets_5m}, 1, 'a counter reset is recorded in the 5m tier');
    is($r->{resets_1h}, 1, '  and survives promotion to the 1h tier');

    my $none = roll([ map { { t => "" . ($_ * $M), v => $_ } } 1 .. 50 ], SUM);
    is($none->{resets_5m}, 0, 'a series with no reset records none');
}

# Two resets in different buckets both survive.
{
    my @pts;
    for my $i (0 .. 199) {
        push @pts, { t => "" . ($i * 10 * $M), v => $i,
                     reset => (($i == 40 || $i == 120) ? 1 : 0) };
    }
    my $r = roll(\@pts, SUM);
    is($r->{resets_5m}, 2, 'two resets in different buckets are both kept');
    is($r->{resets_1h}, 2, '  and both promote');
}

# --- the empty case ---------------------------------------------------------

{
    my $r = roll([], COUNT);
    is($r->{n_5m}, 0, 'no points is no buckets');
    is($r->{value_5m}, 0, '  and a count of zero');
}

done_testing();

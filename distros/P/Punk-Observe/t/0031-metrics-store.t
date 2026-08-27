#!perl
# Chunks, counter resets, and exemplars.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use POWire;

my $M = 'Punk::Observe::Metric';
sub chunk { $M->can('chunk')->(@_) }
sub d2b   { $M->can('d2b')->($_[0]) }

use constant { INT => 1, DBL => 0 };
use constant { F_CUMULATIVE => 0x02, F_MONOTONIC => 0x04, F_RESET => 0x08 };

# --- chunk bounds -----------------------------------------------------------

# A chunk closes at 120 points, because a chunk is the unit of DECOMPRESSION:
# a query for one minute must not have to inflate ten.
{
    my @t = map { $_ * 1_000_000_000 } 1 .. 200;
    my @v = map { d2b($_) } 1 .. 200;
    my $c = chunk(\@t, \@v, DBL, 0);
    is($c->{count}, 120, 'a chunk closes at 120 points');
    is(scalar @{ $c->{t} }, 120, '  and decodes exactly that many');
}

# Or at two hours, whichever comes first.
{
    my $hour = 3600 * 1_000_000_000;
    my @t = map { "" . ($_ * $hour) } 0 .. 9;      # 10 points over 9 hours
    my @v = map { d2b($_) } 0 .. 9;
    my $c = chunk(\@t, \@v, DBL, 0);
    cmp_ok($c->{count}, '<=', 3, 'a chunk closes at the two-hour span');
    cmp_ok($c->{count}, '>=', 2, '  having taken the points inside it');
}

# --- counter resets ---------------------------------------------------------

# A cumulative counter going backwards means the process restarted. Detected
# at ENCODE time, because phase 10's rollups outlive the raw points that would
# otherwise reveal it.
{
    my @t = map { $_ * 1_000_000_000 } 1 .. 10;
    my @v = map { d2b($_) } (100, 110, 120, 130, 5, 15, 25, 35, 45, 55);
    my $c = chunk(\@t, \@v, DBL, F_CUMULATIVE | F_MONOTONIC);
    is($c->{resets}, 1, 'a counter going backwards is detected');
    ok($c->{flags} & F_RESET, '  and flagged on the chunk');
    is_deeply([ map { "$_" } @{ $c->{v} } ], [ map { "$_" } @v ],
              '  while the values themselves are stored untouched');
}

# A monotonic counter that only rises has no reset.
{
    my @t = map { $_ * 1_000_000_000 } 1 .. 10;
    my @v = map { d2b($_ * 10) } 1 .. 10;
    my $c = chunk(\@t, \@v, DBL, F_CUMULATIVE | F_MONOTONIC);
    is($c->{resets}, 0, 'a rising counter has no reset');
    ok(!($c->{flags} & F_RESET), '  and is not flagged');
}

# A GAUGE going down is not a reset. Detecting one on a non-monotonic series
# would flag every ordinary gauge in the system.
{
    my @t = map { $_ * 1_000_000_000 } 1 .. 10;
    my @v = map { d2b($_) } (50, 40, 30, 20, 10, 20, 30, 40, 50, 60);
    my $c = chunk(\@t, \@v, DBL, 0);
    is($c->{resets}, 0, 'a gauge falling is not a counter reset');
}

# The integer path detects a reset on the integer value, not on a double
# reinterpretation of its bits.
{
    my @t = map { $_ * 1_000_000_000 } 1 .. 6;
    my @v = ('1000', '2000', '3000', '10', '20', '30');
    my $c = chunk(\@t, \@v, INT, F_CUMULATIVE | F_MONOTONIC);
    is($c->{resets}, 1, 'an integer counter reset is detected');
    is_deeply([ map { "$_" } @{ $c->{v} } ], [ map { "$_" } @v ],
              '  and the integers are exact');
}

# An integer above 2^53 survives, which a cast to double would round.
{
    my @t = ('1000000000', '2000000000');
    my @v = ('9007199254740993', '9007199254740995');
    my $c = chunk(\@t, \@v, INT, F_MONOTONIC);
    is_deeply([ map { "$_" } @{ $c->{v} } ], [ map { "$_" } @v ],
              'integer counters above 2^53 are exact, not rounded to a double');
    is($c->{resets}, 0, '  and are compared as integers, so no false reset');
}

# --- exemplars --------------------------------------------------------------

# The entire mechanism behind | exemplars. An exemplar without a trace id
# points nowhere, so it is refused rather than stored.
{
    my $r = $M->can('exemplars')->([
        { t => '1000', value => d2b(1.5), trace_hi => '111', trace_lo => '222',
          span_id => '333' },
        { t => '2000', value => d2b(2.5), trace_hi => '0', trace_lo => '0',
          span_id => '444' },                       # no trace id: useless
        { t => '3000', value => d2b(3.5), trace_hi => '0', trace_lo => '999',
          span_id => '555' },                       # low half only: valid
    ]);
    is(scalar @{ $r->{kept} }, 2, 'exemplars with a trace id are kept');
    is($r->{refused}, 1, '  and one without is refused');
    is("$r->{kept}[0]{trace_hi}", '111', '  trace id preserved');
    is("$r->{kept}[0]{span_id}", '333',  '  span id preserved');
    is("$r->{kept}[1]{trace_lo}", '999',
       '  a trace id that is non-zero in only one half is still valid');
}

{
    my @many = map { { t => "$_", value => d2b($_), trace_hi => "$_",
                       trace_lo => "$_", span_id => "$_" } } 1 .. 500;
    my $r = $M->can('exemplars')->(\@many);
    is(scalar @{ $r->{kept} }, 500, '500 exemplars survive the array growing');
    is("$r->{kept}[499]{trace_hi}", '500', '  with the last one intact');
}

# --- the five OTLP shapes, end to end --------------------------------------

# Sums and gauges decode to records (phase 1); histograms, exponential
# histograms and summaries are SKIPPED rather than half-decoded. Asserting the
# skip matters as much as asserting the decode: an unknown metric type must
# cost nothing and must not fail the batch beside it.
{
    my $req = POWire::metric_request(metrics => [
        POWire::metric_sum(name => 'requests.total', temporality => 2,
            monotonic => 1,
            points => [ POWire::number_point(time => '1000', as_int => '42') ]),
        POWire::metric_gauge(name => 'queue.depth',
            points => [ POWire::number_point(time => '2000', as_double => 7.5) ]),
        # a histogram (field 9) that this phase does not decode
        POWire::bytes(1, 'latency') . POWire::msg(9, POWire::vint(2, 2)),
    ]);
    my $r = Punk::Observe::Decode::decode($req, 'metrics');
    ok($r->{ok}, 'a mixed metric batch decodes');
    is(scalar @{ $r->{records} }, 2,
       '  the sum and the gauge become records');
    ok($r->{records}[0]{value_is_int}, '  the sum kept its integer form');
    is("$r->{records}[0]{value}", '42', '  with its value');
    is($r->{records}[1]{value}, 7.5, '  and the gauge its double');
    ok($r->{records}[0]{flags} & 0x08, '  cumulative temporality carried');
    ok($r->{records}[0]{flags} & 0x04, '  monotonic carried');
}

done_testing();

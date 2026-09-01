#!perl
# Histograms, which were the shape phase 5 deferred.
#
# A HISTOGRAM POINT IS NOT ONE VALUE, so it cannot be one record. It is
# exploded into series the existing model already stores:
#
#     <name>_bucket {le="0.005"}   CUMULATIVE count at or below that bound
#     <name>_bucket {le="+Inf"}    the total
#     <name>_sum                   the sum of observations
#     <name>_count                 how many there were
#
# The cumulative part is what this file is really about. A percentile is only
# exact - which is the promise the rollup tier makes - if the buckets it
# merges are cumulative counts rather than per-bucket ones, and getting that
# backwards produces percentiles that look plausible and are wrong.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use POWire;

# The record's flags, as the decoder exposes them: a bitfield rather than
# named keys. From po_rec.h.
use constant { F_MONOTONIC => 0x0004, F_CUMULATIVE => 0x0008 };

sub decode {
    my ($pb) = @_;
    return Punk::Observe::Decode::decode($pb, 'metrics');
}

# POWire has no histogram writer - it was built for the shapes that were
# implemented. These are the two encoders this test needs, written here so
# the fixture stays independent of the code under test.
sub hist_point {
    my (%a) = @_;
    my $s = '';
    $s .= POWire::fixed64(3, $a{time});
    $s .= POWire::vint(4, $a{count});
    $s .= POWire::dbl(5, $a{sum}) if defined $a{sum};
    if ($a{counts}) {
        # PACKED, which is what every real encoder emits.
        my $packed = join '', map { POWire::varint($_) } @{ $a{counts} };
        $s .= POWire::bytes(6, $packed);
    }
    if ($a{bounds}) {
        my $packed = join '', map { pack('d<', $_) } @{ $a{bounds} };
        $s .= POWire::bytes(7, $packed);
    }
    $s .= join '', map { POWire::msg(9, $_) } @{ $a{attributes} || [] };
    $s .= POWire::dbl(11, $a{min}) if defined $a{min};
    $s .= POWire::dbl(12, $a{max}) if defined $a{max};
    return $s;
}

sub metric_hist {
    my (%a) = @_;
    my $s = join '', map { POWire::msg(1, $_) } @{ $a{points} || [] };
    $s .= POWire::vint(2, $a{temporality} // 2);
    return POWire::bytes(1, $a{name}) . POWire::msg(9, $s);
}

sub req {
    my (%a) = @_;
    return POWire::metric_request(
        resource => POWire::resource(POWire::keyvalue(
            'service.name', POWire::anyvalue_string($a{service} // 'api'))),
        metrics  => $a{metrics});
}

sub by_name {
    my ($d) = @_;
    my %h;
    for my $r (@{ $d->{records} }) {
        my $le = $r->{attrs}{le};
        my $k = $r->{body} . (defined $le ? "{le=$le}" : '');
        $h{$k} = $r->{value};
    }
    return \%h;
}

# --- the shape ---------------------------------------------------------------

{
    my $pb = req(metrics => [ metric_hist(
        name   => 'http.server.duration',
        points => [ hist_point(time => '1774224000000000000',
                               count => 10, sum => 4.2,
                               bounds => [ 0.1, 0.5, 1 ],
                               counts => [ 4, 3, 2, 1 ]) ]) ]);
    my $d = decode($pb);
    ok($d->{ok}, 'a histogram decodes') or diag 'decode failed';

    my $v = by_name($d);
    is(scalar keys %$v, 6,
       'one point becomes four buckets, a sum and a count');

    # CUMULATIVE, not per-bucket. 4, then 4+3, then 4+3+2, then all ten.
    is($v->{'http.server.duration_bucket{le=0.1}'}, 4, 'the first bucket is 4');
    is($v->{'http.server.duration_bucket{le=0.5}'}, 7,
       '  the second is CUMULATIVE: 4 + 3');
    is($v->{'http.server.duration_bucket{le=1}'},   9, '  the third is 4 + 3 + 2');
    is($v->{'http.server.duration_bucket{le=+Inf}'}, 10,
       '  and +Inf carries everything');

    # The sum arrives as a protobuf double, so the NV holds the float64
    # nearest 4.2. Where the NV is wider than a double - long double or
    # quadmath - that is not the NV nearest 4.2, and comparing against the
    # literal fails on tail digits the wire never carried. Format to the 15
    # digits a float64 is unambiguous at.
    is(sprintf('%.15g', $v->{'http.server.duration_sum'}), '4.2',
       'the sum survives');
    is($v->{'http.server.duration_count'}, 10,  'and the count');
}

# THE INVARIANT THAT MAKES A PERCENTILE EXACT: the +Inf bucket equals the
# count. If they disagree, every percentile computed from the buckets is
# wrong, and wrong in a way that looks like a plausible number.
{
    my $pb = req(metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 21, sum => 1,
                               bounds => [ 1, 2, 5, 10 ],
                               counts => [ 5, 5, 5, 5, 1 ]) ]) ]);
    my $v = by_name(decode($pb));
    is($v->{'x_bucket{le=+Inf}'}, $v->{'x_count'},
       'the +Inf bucket equals the count');
}

# --- the bounds become labels, and a label IS a series identity -------------

{
    my $pb = req(metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 3, sum => 0,
                               bounds => [ 0.005, 2.5, 1000 ],
                               counts => [ 1, 1, 1, 0 ]) ]) ]);
    my $v = by_name(decode($pb));
    ok(exists $v->{'x_bucket{le=0.005}'}, 'a small bound renders without an exponent');
    ok(exists $v->{'x_bucket{le=2.5}'},   'a fractional bound keeps its fraction');
    ok(exists $v->{'x_bucket{le=1000}'},  'a whole bound has no trailing point');
}

{
    # Two spellings of one bound would be two series that never merge, so the
    # rendering has to be stable rather than merely readable.
    my @seen;
    for (1 .. 3) {
        my $pb = req(metrics => [ metric_hist(
            name   => 'x',
            points => [ hist_point(time => '1', count => 1, sum => 0,
                                   bounds => [ 0.1 ], counts => [ 1, 0 ]) ]) ]);
        my $v = by_name(decode($pb));
        push @seen, join ',', sort keys %$v;
    }
    is(scalar(keys %{{ map { $_ => 1 } @seen }}), 1,
       'the same bound renders identically every time');
}

# --- attributes are inherited AND extended ----------------------------------

{
    my $pb = req(service => 'checkout', metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 2, sum => 0,
                               bounds => [ 1 ], counts => [ 2, 0 ],
                               attributes => [ POWire::keyvalue(
                                   'http.route',
                                   POWire::anyvalue_string('/pay')) ]) ]) ]);
    my $d = decode($pb);
    my ($b) = grep { ($_->{attrs}{le} // '') eq '1' } @{ $d->{records} };
    ok($b, 'a bucket record was produced');
    is($b->{attrs}{'service.name'}, 'checkout',
       '  the resource attribute is inherited');
    is($b->{attrs}{'http.route'}, '/pay', '  the point attribute is kept');
    is($b->{attrs}{le}, '1', '  and `le` is added beside them');

    my ($c) = grep { $_->{body} eq 'x_count' } @{ $d->{records} };
    ok(!exists $c->{attrs}{le}, 'the count carries NO le - it is not a bucket');
}

# --- temporality and monotonicity -------------------------------------------

{
    for my $case ([ 2 => 1, 'cumulative' ], [ 1 => 0, 'delta' ]) {
        my $pb = req(metrics => [ metric_hist(
            name => 'x', temporality => $case->[0],
            points => [ hist_point(time => '1', count => 1, sum => 0,
                                   bounds => [ 1 ], counts => [ 1, 0 ]) ]) ]);
        my $d = decode($pb);
        my ($r) = @{ $d->{records} };
        # OTLP: DELTA = 1, CUMULATIVE = 2. The reverse of some SDKs' internal
        # constants, and getting it backwards draws every rate wrongly while
        # being accepted silently.
        is(($r->{flags} & F_CUMULATIVE) ? 1 : 0, $case->[1],
           "temporality $case->[0] is $case->[2]");
    }
}

{
    my $pb = req(metrics => [ metric_hist(
        name => 'x',
        points => [ hist_point(time => '1', count => 1, sum => 0,
                               bounds => [ 1 ], counts => [ 1, 0 ]) ]) ]);
    my ($r) = @{ decode($pb)->{records} };
    ok($r->{flags} & F_MONOTONIC,
       'buckets are monotonic, so rate() treats them like a counter');
}

# --- malformed points are REFUSED, not half-decoded -------------------------
#
# The bucket array is one longer than the bounds array. A point where that
# does not hold produces a histogram whose percentiles are quietly wrong,
# which is worse than one that is missing.

{
    my $pb = req(metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 5, sum => 0,
                               bounds => [ 1, 2 ],
                               counts => [ 1, 1 ]) ]) ]);   # one too few
    my $d = decode($pb);
    ok($d->{ok}, 'a mismatched bucket array still decodes the batch');
    is(scalar @{ $d->{records} }, 0,
       '  but produces NO records rather than wrong ones');
}

{
    my $pb = req(metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 5, sum => 0,
                               bounds => [ 1 ],
                               counts => [ 1, 1, 1 ]) ]) ]);  # one too many
    my $d = decode($pb);
    is(scalar @{ $d->{records} }, 0, 'and neither does one too many');
}

# --- optional fields ---------------------------------------------------------

{
    # No sum: OTLP allows it, and a count with no sum is still a histogram.
    my $pb = req(metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 4,
                               bounds => [ 1 ], counts => [ 4, 0 ]) ]) ]);
    my $v = by_name(decode($pb));
    ok(!exists $v->{'x_sum'}, 'a point with no sum emits no _sum series');
    is($v->{'x_count'}, 4, '  but still emits the count');
}

{
    my $pb = req(metrics => [ metric_hist(
        name   => 'x',
        points => [ hist_point(time => '1', count => 4, sum => 8,
                               min => 0.5, max => 3.5,
                               bounds => [ 1 ], counts => [ 4, 0 ]) ]) ]);
    my $v = by_name(decode($pb));
    is($v->{'x_min'}, 0.5, 'min is carried when present');
    is($v->{'x_max'}, 3.5, '  and max');
}

{
    # A histogram with NO buckets at all is a count and a sum. Real SDKs emit
    # these when every bucket boundary was dropped by a view.
    my $pb = req(metrics => [ metric_hist(
        name => 'x',
        points => [ hist_point(time => '1', count => 7, sum => 1.5) ]) ]);
    my $v = by_name(decode($pb));
    is($v->{'x_count'}, 7, 'a bucketless histogram still yields a count');
    is($v->{'x_sum'}, 1.5, '  and a sum');
}

# --- a percentile from the buckets ------------------------------------------
#
# The whole point of keeping buckets. This is the arithmetic a query does, run
# here against a known distribution so the shape of the data is proven usable
# rather than merely present.

{
    my $pb = req(metrics => [ metric_hist(
        name   => 'latency',
        points => [ hist_point(time => '1', count => 100, sum => 50,
                               bounds => [ 0.1, 0.25, 0.5,  1,  2.5 ],
                               counts => [  50,   30,  10,  5,    4, 1 ]) ]) ]);
    my $v = by_name(decode($pb));

    # cumulative: 50, 80, 90, 95, 99, 100
    is($v->{'latency_bucket{le=0.1}'},  50, 'the distribution is cumulative');
    is($v->{'latency_bucket{le=0.25}'}, 80, '  through every bucket');
    is($v->{'latency_bucket{le=2.5}'},  99, '  to the last bound');

    # p95 is the first bound whose cumulative count reaches 95% of 100.
    my @bounds = (0.1, 0.25, 0.5, 1, 2.5);
    my $total  = $v->{'latency_count'};
    my $p95;
    for my $b (@bounds) {
        if ($v->{"latency_bucket{le=$b}"} >= 0.95 * $total) { $p95 = $b; last }
    }
    is($p95, 1, 'p95 falls in the le=1 bucket, computed from the buckets alone');
}

# --- AGAINST THE REAL ENCODER ----------------------------------------------
#
# Every assertion above uses this file's own writer, and that writer was WRONG
# in the same way the decoder was: it wrote `count` as a varint where OTLP
# declares fixed64, so both sides agreed and the tests passed while a real
# SDK payload decoded to nothing at all.
#
# A fixture that shares the bug proves nothing. This is the assertion that
# would have caught it: encode with the SDK, decode with this.

SKIP: {
    eval { require Punk::OpenTelemetry;
           require Punk::OpenTelemetry::Meter;
           require Punk::OpenTelemetry::Encode; 1 }
        or skip 'Punk::OpenTelemetry not available', 6;

    # NAME THE VERSION. An older copy on @INC encodes bucket_counts as
    # fixed64, which this decoder correctly refuses to read as varints - and
    # a skip that did not say why would look exactly like the feature being
    # broken. 0.06 is the release that writes them to the schema.
    my $have = $Punk::OpenTelemetry::VERSION || 0;
    skip "Punk::OpenTelemetry $have is older than 0.06, which is the release "
       . "that writes bucket_counts as varints", 6
        if $have < 0.06;

    my $m = Punk::OpenTelemetry::Meter->new;
    # Five observations with a known shape: two under 0.1, one under 0.5,
    # one under 5, one far out in the tail.
    $m->record('latency', 3, $_, { route => '/checkout' })
        for (0.05, 0.08, 0.4, 2.5, 32);

    my $payload = $m->collect;
    skip 'the meter produced nothing', 6 unless $payload;

    my $bytes = Punk::OpenTelemetry::Encode::metrics_protobuf($payload);
    ok(length $bytes, 'the SDK encodes a histogram');

    my $d = decode($bytes);
    ok($d->{ok}, '  and this decoder reads it');
    cmp_ok(scalar @{ $d->{records} }, '>', 3,
        '  producing bucket, sum and count series');

    my $v = by_name($d);
    is($v->{'latency_count'}, 5, 'the count survives the round trip');
    is($v->{'latency_bucket{le=+Inf}'}, 5,
        '  and the +Inf bucket agrees with it');

    # The distribution, checked as a whole: cumulative counts never decrease.
    # The bound is pulled out into a variable before sorting. Doing the match
    # inside the comparator makes the two sides race for $1, which sorted
    # le=10 before le=1 and produced a "descending" sequence that was really
    # a broken sort.
    my @keys = grep { /_bucket\{/ } keys %$v;
    my %bound = map {
        my ($n) = /le=([\d.]+)/;
        ($_ => defined $n ? $n + 0 : 9e99)
    } @keys;
    my @buckets = map { $v->{$_} } sort { $bound{$a} <=> $bound{$b} } @keys;
    my $descends = 0;
    for my $i (1 .. $#buckets) { $descends++ if $buckets[$i] < $buckets[$i-1] }
    is($descends, 0, 'the cumulative counts never decrease');
}

# --- an exemplar belongs to ONE bucket ---------------------------------------
#
# One wire point becomes a record per bucket here, and the exemplar arrives on
# the point. Copying its trace id onto every derived record would claim the
# same request was observed at fifteen different latencies; dropping it would
# leave histograms - the shape this SDK actually sends - with no cross-signal
# jump at all. The wire carries no bucket index, so the bucket is the one the
# exemplar's own value falls in.

sub hist_ex {          # an Exemplar inside a HistogramDataPoint (field 8)
    my (%a) = @_;
    my $s = '';
    $s .= POWire::dbl(3, $a{as_double})   if defined $a{as_double};
    $s .= POWire::bytes(5, $a{trace_id})  if defined $a{trace_id};
    return $s;
}

{
    my $T = pack 'H*', '0123456789abcdef0123456789abcdef';
    my $HALF = '81985529216486895';

    # Bounds 1, 5, 10 - so four buckets: <=1, <=5, <=10, +Inf. The exemplar's
    # value of 7 falls in the third.
    my $point = hist_point(time => 1, count => 4, sum => 20,
                           counts => [ 1, 1, 1, 1 ], bounds => [ 1, 5, 10 ])
              . POWire::msg(8, hist_ex(as_double => 7, trace_id => $T));
    my $d = decode(req(metrics => [ metric_hist(name => 'h',
                                                points => [ $point ]) ]));
    ok($d->{ok}, 'a histogram with an exemplar decodes');

    my %by;
    for my $r (@{ $d->{records} }) {
        my $le = $r->{attrs}{le};
        my $key = $r->{body} . (defined $le ? "{le=$le}" : '');
        $by{$key} = $r;
    }
    is($by{'h_bucket{le=10}'}{trace_hi}, $HALF,
       'the exemplar lands on the bucket its value falls in');
    is($by{'h_bucket{le=5}'}{trace_hi} + $by{'h_bucket{le=5}'}{trace_lo}, 0,
       '  and not on the bucket below it');
    is($by{'h_bucket{le=+Inf}'}{trace_hi}
     + $by{'h_bucket{le=+Inf}'}{trace_lo}, 0,
       '  nor on every bucket above, which cumulative counts might suggest');
    is($by{'h_count'}{trace_hi} + $by{'h_count'}{trace_lo}, 0,
       '  and never on _count, which is arithmetic and not an observation');
    is($by{'h_sum'}{trace_hi} + $by{'h_sum'}{trace_lo}, 0,
       '  nor on _sum');

    # A value above every bound belongs to +Inf, which is the bucket with no
    # upper bound to compare against.
    my $over = hist_point(time => 1, count => 1, counts => [ 0, 0, 0, 1 ],
                          bounds => [ 1, 5, 10 ])
             . POWire::msg(8, hist_ex(as_double => 99, trace_id => $T));
    my $d2 = decode(req(metrics => [ metric_hist(name => 'h',
                                                 points => [ $over ]) ]));
    my ($inf) = grep { ($_->{attrs}{le} // '') eq '+Inf' } @{ $d2->{records} };
    is($inf->{trace_hi}, $HALF, 'a value over the top bound lands on +Inf');
}

done_testing();

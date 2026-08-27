#!perl
# The OTLP schema layer: po_otlp_in.h.
#
# The headline assertion is the round-trip against Punk::OpenTelemetry's OWN
# encoder. No hand-built fixture can make it: it is the only check that the
# client and the server agree about what field 9 means, and a field-number
# drift between the two dists produces plausible wrong data with no error
# anywhere.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use POWire;

sub decode { Punk::Observe::Decode::decode($_[0], $_[1]) }

# Find the SDK to round-trip against, and be loud about which one it is.
#
# The sibling is searched for UPWARD, because `make disttest` runs one level
# deeper than a checkout and a fixed "../" silently misses it there. When it
# does miss, the test falls back to whatever is INSTALLED - and an installed
# copy four versions behind the header this was built against still passes
# the simple cases, so the headline assertion quietly becomes vacuous while
# still printing PASS. That is the failure this block exists to make visible.
my $SDK_MIN = '0.05';
my $sdk_from = 'installed';
for my $up ('..', '../..', '../../..') {
    my $lib = "$up/Punk-OpenTelemetry/blib/lib";
    next unless -d $lib;
    unshift @INC, $lib, "$up/Punk-OpenTelemetry/blib/arch";
    $sdk_from = "checkout at $up/Punk-OpenTelemetry";
    last;
}
my $SDK = eval { require Punk::OpenTelemetry;
                 require Punk::OpenTelemetry::Encode; 1 };
my $SDK_VER = $SDK ? ($Punk::OpenTelemetry::VERSION // '0') : undef;

if (!$SDK) {
    diag("SDK not loadable: the round-trip assertions will SKIP");
}
elsif ($SDK_VER lt $SDK_MIN) {
    diag("SDK is $SDK_VER ($sdk_from), older than the $SDK_MIN this was built");
    diag("against. The round-trip still runs, but it is a WEAKER assertion:");
    diag("it no longer proves agreement with the header's field numbers.");
}
else {
    diag("SDK: Punk::OpenTelemetry $SDK_VER ($sdk_from)");
}

# --- traces -----------------------------------------------------------------

{
    my $req = POWire::trace_request(
        resource => POWire::resource(
            POWire::keyvalue('service.name', POWire::anyvalue_string('checkout'))),
        spans => [ POWire::span(
            trace_id => "\x01" x 16,
            span_id  => "\x02" x 8,
            parent_id=> "\x03" x 8,
            name     => 'POST /pay',
            kind     => 2,                      # SERVER
            start    => '1774224000000000000',
            end      => '1774224000500000000',
            status   => 2,                      # ERROR
            attributes => [
                POWire::keyvalue('http.route', POWire::anyvalue_string('/pay')),
                POWire::keyvalue('http.status_code', POWire::anyvalue_int(500)),
            ],
        ) ],
    );
    my $r = decode($req, 'traces');
    ok($r->{ok}, 'a trace request decodes');
    is(scalar @{ $r->{records} }, 1, 'one span');
    my $s = $r->{records}[0];
    is($s->{kind}, 3, '  kind is PO_SPAN');
    is("$s->{t}", '1774224000000000000', '  start time exact, above 2^53');
    is("$s->{duration}", '500000000', '  duration computed in u64');
    is($s->{body}, 'POST /pay', '  name');
    is($s->{span_kind}, 2, '  span kind SERVER');
    is($s->{status}, 2, '  status ERROR');
    is($s->{attrs}{'service.name'}, 'checkout',
       '  resource attributes are inherited by the span');
    is($s->{attrs}{'http.route'}, '/pay', '  span attributes present');
    is("$s->{attrs}{'http.status_code'}", '500', '  int attribute');
}

# An all-zero trace id is invalid and is counted, not stored.
{
    my $req = POWire::trace_request(spans => [
        POWire::span(trace_id => "\x00" x 16, span_id => "\x02" x 8,
                     name => 'bad', start => 1, end => 2),
        POWire::span(trace_id => "\x01" x 16, span_id => "\x03" x 8,
                     name => 'good', start => 1, end => 2),
    ]);
    my $r = decode($req, 'traces');
    ok($r->{ok}, 'a batch with a zero trace id still decodes');
    is(scalar @{ $r->{records} }, 1, '  the invalid span is dropped');
    is($r->{dropped_bad_trace}, 1, '  and counted');
    is($r->{records}[0]{body}, 'good', '  the valid one survives');
}

# end < start means the clock stepped. In a u64 that is ~1.8e19, not negative.
{
    my $req = POWire::trace_request(spans => [
        POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
                     name => 'backwards',
                     start => '1774224000000000000',
                     end   => '1774223999000000000') ]);
    my $r = decode($req, 'traces');
    is("$r->{records}[0]{duration}", '0', 'end before start clamps to zero');
    is($r->{clamped_durations}, 1, '  and is counted');
    ok($r->{records}[0]{flags} & 0x0020, '  and flagged on the record');
}

# A wrong-length id is OMITTED, never padded: padding invents an id that
# collides with a real one.
{
    my $req = POWire::trace_request(spans => [
        POWire::span(trace_id => "\x01" x 8, span_id => "\x02" x 8,
                     name => 'shortid', start => 1, end => 2) ]);
    my $r = decode($req, 'traces');
    is(scalar @{ $r->{records} }, 0,
       'an 8-byte trace id is not padded to 16, it is refused as all-zero');
    is($r->{dropped_bad_trace}, 1, '  and counted');
}

# --- the attribute sort, which phase 4 depends on ---------------------------

# Two spans whose attributes are given in DIFFERENT ORDERS must produce the
# same canonical block. If the order leaks into the bytes, phase 4's
# content-derived series id gives the same series two ids: storage doubles and
# the cardinality cap counts everything twice.
{
    my @kv = (
        POWire::keyvalue('zebra', POWire::anyvalue_string('z')),
        POWire::keyvalue('alpha', POWire::anyvalue_string('a')),
        POWire::keyvalue('mike',  POWire::anyvalue_int(7)),
    );
    my $mk = sub {
        my (@order) = @_;
        my $req = POWire::trace_request(spans => [
            POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
                         name => 'n', start => 1, end => 2,
                         attributes => [ @kv[@order] ]) ]);
        decode($req, 'traces')->{records}[0];
    };
    my $a = $mk->(0, 1, 2);
    my $b = $mk->(2, 1, 0);
    my $c = $mk->(1, 0, 2);
    is_deeply($a->{attr_order}, $b->{attr_order},
              'attributes canonicalise to one order regardless of input order');
    is_deeply($a->{attr_order}, $c->{attr_order}, '  for a third permutation too');
    is_deeply($a->{attr_order}, ['alpha', 'mike', 'zebra'], '  sorted by key');
    is_deeply($a->{attrs}, $b->{attrs}, '  and the values agree');
}

# --- nested attribute values ------------------------------------------------

{
    my $req = POWire::trace_request(spans => [
        POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
            name => 'n', start => 1, end => 2,
            attributes => [
                POWire::keyvalue('tags', POWire::anyvalue_array(
                    POWire::anyvalue_string('a'), POWire::anyvalue_string('b'))),
                POWire::keyvalue('http', POWire::anyvalue_kvlist(
                    POWire::keyvalue('method', POWire::anyvalue_string('GET')))),
                POWire::keyvalue('ok',   POWire::anyvalue_bool(1)),
                POWire::keyvalue('rate', POWire::anyvalue_double(0.25)),
            ]) ]);
    my $r = decode($req, 'traces');
    my $at = $r->{records}[0]{attrs};
    is($at->{'tags.0'}, 'a', 'an array flattens to key.0');
    is($at->{'tags.1'}, 'b', '  and key.1');
    is($at->{'http.method'}, 'GET', 'a map flattens to key.sub');
    is("$at->{ok}", '1', 'a bool');
    is($at->{rate}, 0.25, 'a double');
}

# Depth is bounded because the input is untrusted: a thousand nested kvlists
# must not recurse the C stack to death.
{
    my $v = POWire::anyvalue_string('deep');
    $v = POWire::anyvalue_kvlist(POWire::keyvalue("k$_", $v)) for 1 .. 200;
    my $req = POWire::trace_request(spans => [
        POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
            name => 'n', start => 1, end => 2,
            attributes => [ POWire::keyvalue('deep', $v) ]) ]);
    my $r = eval { decode($req, 'traces') };
    ok(defined $r, '200 levels of nesting does not crash');
    ok($r->{ok}, '  and decodes');
}

# --- logs -------------------------------------------------------------------

{
    my $req = POWire::log_request(
        resource => POWire::resource(
            POWire::keyvalue('service.name', POWire::anyvalue_string('api'))),
        records => [ POWire::log_record(
            time     => '1774224000000000000',
            severity => 17,                         # ERROR
            body     => POWire::anyvalue_string('connection refused'),
            trace_id => "\x0a" x 16,
            span_id  => "\x0b" x 8,
        ) ]);
    my $r = decode($req, 'logs');
    ok($r->{ok}, 'a log request decodes');
    my $l = $r->{records}[0];
    is($l->{kind}, 2, '  kind is PO_LOG');
    is($l->{body}, 'connection refused', '  body');
    is($l->{severity}, 17, '  severity on the 24-point scale');
    is("$l->{t}", '1774224000000000000', '  timestamp exact');
    ok($l->{flags} & 0x0001, '  trace correlation flagged');
    isnt("$l->{trace_hi}", '0', '  trace id carried, which | logs depends on');
}

# time_unix_nano absent falls back to observed_time, as the spec intends.
{
    my $req = POWire::log_request(records => [
        POWire::log_record(observed => '1774224000000000123',
                           body => POWire::anyvalue_string('x')) ]);
    my $r = decode($req, 'logs');
    is("$r->{records}[0]{t}", '1774224000000000123',
       'an absent time falls back to observed_time');
}

# A structured body is preserved, not dropped.
{
    my $req = POWire::log_request(records => [
        POWire::log_record(time => 1, body => POWire::anyvalue_kvlist(
            POWire::keyvalue('msg', POWire::anyvalue_string('hi')),
            POWire::keyvalue('n',   POWire::anyvalue_int(3)))) ]);
    my $r = decode($req, 'logs');
    is($r->{records}[0]{attrs}{'body.msg'}, 'hi',
       'a structured log body flattens into attributes rather than vanishing');
    is("$r->{records}[0]{attrs}{'body.n'}", '3', '  with every field');
}

# --- metrics, and the reversed temporality enum -----------------------------

# otel_proto.h:217-226 is emphatic: OTLP is DELTA=1, CUMULATIVE=2, the reverse
# of the SDK's internal constants, and a backend that gets it wrong "accepts
# without complaint and then draws completely wrongly".
{
    my $mk = sub {
        my ($temporality) = @_;
        my $req = POWire::metric_request(metrics => [ POWire::metric_sum(
            name => 'http.server.duration',
            temporality => $temporality,
            monotonic => 1,
            points => [ POWire::number_point(
                time => '1774224000000000000', as_double => 1.5) ],
        ) ]);
        decode($req, 'metrics')->{records}[0];
    };
    my $cum = $mk->(2);          # OTLP CUMULATIVE
    my $del = $mk->(1);          # OTLP DELTA
    ok($cum->{flags} & 0x0008, 'OTLP temporality 2 reads as CUMULATIVE');
    ok(!($del->{flags} & 0x0008), 'OTLP temporality 1 reads as DELTA');
    ok($cum->{flags} & 0x0004, 'is_monotonic carried');
    is($cum->{body}, 'http.server.duration', 'metric name');
    is($cum->{value}, 1.5, 'double value');
}

# as_int is kept EXACTLY. A cast to double loses integers above 2^53, and a
# counter that big is precisely the one somebody is watching.
{
    my $req = POWire::metric_request(metrics => [ POWire::metric_sum(
        name => 'bytes.total', temporality => 2, monotonic => 1,
        points => [ POWire::number_point(
            time => 1, as_int => '9007199254740993') ]) ]);
    my $r = decode($req, 'metrics');
    my $m = $r->{records}[0];
    ok($m->{value_is_int}, 'an int point is flagged as an int');
    is("$m->{value}", '9007199254740993',
       '  and 2^53+1 survives exactly rather than rounding to 2^53');
}

{
    my $req = POWire::metric_request(metrics => [ POWire::metric_gauge(
        name => 'queue.depth',
        points => [ POWire::number_point(time => 1, as_double => 42) ]) ]);
    my $r = decode($req, 'metrics');
    is($r->{records}[0]{body}, 'queue.depth', 'a gauge decodes');
    is($r->{records}[0]{value}, 42, '  with its value');
}

# An unknown metric type (histogram, phase 5) is skipped, not half-decoded.
{
    my $req = POWire::metric_request(metrics => [
        POWire::bytes(1, 'some.histogram') . POWire::msg(9, POWire::vint(2, 2)),
        POWire::metric_gauge(name => 'g',
            points => [ POWire::number_point(time => 1, as_double => 1) ]),
    ]);
    my $r = decode($req, 'metrics');
    ok($r->{ok}, 'a histogram is skipped rather than failing the batch');
    is(scalar @{ $r->{records} }, 1, '  and the gauge beside it still decodes');
}

# --- the empty and the malformed -------------------------------------------

{
    my $r = decode('', 'traces');
    ok($r->{ok}, 'an empty body is valid');
    is(scalar @{ $r->{records} }, 0, '  and yields zero records, not an error');
}
{
    # A ResourceSpans with no ScopeSpans is legal and means zero records.
    my $r = decode(POWire::msg(1, ''), 'traces');
    ok($r->{ok}, 'an empty ResourceSpans is valid');
    is(scalar @{ $r->{records} }, 0, '  with no records');
}
{
    my $r = decode(POWire::bad_group(1), 'traces');
    ok(!$r->{ok}, 'a deprecated group fails the decode');
}

# --- THE round-trip: the SDK next door encodes, this decodes ----------------

SKIP: {
    skip 'Punk::OpenTelemetry not loadable', 9 unless $SDK;

    my $payload = {
        resource_spans => [ {
            resource => { attributes => { 'service.name' => 'checkout' } },
            scope_spans => [ {
                scope => { name => 'test', version => '1' },
                spans => [ {
                    trace_id => '0123456789abcdef0123456789abcdef',
                    span_id  => '0123456789abcdef',
                    name     => 'POST /pay',
                    kind     => 2,
                    start_time_unix_nano => '1774224000000000000',
                    end_time_unix_nano   => '1774224000500000000',
                    attributes => { 'http.route' => '/pay' },
                    status   => { code => 2 },
                } ],
            } ],
        } ],
    };

    my $wire = Punk::OpenTelemetry::Encode::traces_protobuf($payload);
    ok(length $wire, 'the SDK encoded a trace request');

    my $r = decode($wire, 'traces');
    ok($r->{ok}, 'and this decoder reads it') or diag 'decode failed';
    is(scalar @{ $r->{records} }, 1, '  one span');

    my $s = $r->{records}[0];
    is($s->{body}, 'POST /pay', '  name matches what the SDK wrote');
    is("$s->{t}", '1774224000000000000',
       '  a nanosecond timestamp above 2^53 survives the round trip');
    is("$s->{duration}", '500000000', '  duration matches');
    is($s->{span_kind}, 2, '  span kind matches');
    is($s->{status}, 2, '  status matches');
    is($s->{attrs}{'service.name'}, 'checkout',
       '  resource attributes match, so field 1 means the same in both dists');
}

SKIP: {
    skip 'Punk::OpenTelemetry not loadable', 3 unless $SDK;
    skip 'SDK has no logs_protobuf', 3
        unless defined &Punk::OpenTelemetry::Encode::logs_protobuf;

    my $wire = Punk::OpenTelemetry::Encode::logs_protobuf({
        resource_logs => [ {
            resource => { attributes => { 'service.name' => 'api' } },
            scope_logs => [ {
                scope => { name => 'test' },
                log_records => [ {
                    time_unix_nano  => '1774224000000000000',
                    severity_number => 17,
                    body            => 'connection refused',
                } ],
            } ],
        } ],
    });
    my $r = decode($wire, 'logs');
    ok($r->{ok}, 'the SDK-encoded log request decodes');
    is(scalar @{ $r->{records} }, 1, '  one record');
    is($r->{records}[0]{body}, 'connection refused', '  body matches');
}

done_testing();

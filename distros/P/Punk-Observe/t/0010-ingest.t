#!perl
# The receivers. Protobuf and JSON must produce IDENTICAL records - the
# protobuf path is the reference, since it is the one the SDK uses by default.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use Punk::Observe::Ingest;
use POWire;

# --- a tiny PSGI driver, so this needs no HTTP server ----------------------

sub req {
    my (%a) = @_;
    my $body = defined $a{body} ? $a{body} : '';
    open my $in, '<', \$body or die;
    binmode $in;
    my $env = {
        REQUEST_METHOD => $a{method} || 'POST',
        PATH_INFO      => $a{path}   || '/v1/traces',
        CONTENT_TYPE   => exists $a{type} ? $a{type} : 'application/x-protobuf',
        CONTENT_LENGTH => length $body,
        'psgi.input'   => $in,
        'psgi.url_scheme' => 'http',
        %{ $a{env} || {} },
    };
    delete $env->{CONTENT_TYPE} unless defined $env->{CONTENT_TYPE};
    return $env;
}

my @stored;
sub app {
    my (%opt) = @_;
    @stored = ();
    return Punk::Observe::Ingest->new(
        on_batch => sub { push @stored, [ @_[0,1] ]; 1 },
        %opt,
    )->to_app;
}

sub call { my ($app, %a) = @_; return $app->(req(%a)) }

# A real trace request from the independent writer.
sub trace_pb {
    my (%a) = @_;
    return POWire::trace_request(
        resource => POWire::resource(
            POWire::keyvalue('service.name', POWire::anyvalue_string('checkout'))),
        spans => [ POWire::span(
            trace_id => "\x01" x 16, span_id => "\x02" x 8,
            name => 'POST /pay', kind => 2,
            start => '1774224000000000000', end => '1774224000500000000',
            status => 2,
            attributes => [
                POWire::keyvalue('http.route', POWire::anyvalue_string('/pay')) ],
            %a) ],
    );
}

# --- the happy path ---------------------------------------------------------

{
    my $app = app();
    my $r = call($app, body => trace_pb());
    is($r->[0], 200, 'a protobuf trace batch is accepted');
    is($r->[2][0], '', '  a full accept is an EMPTY 200');
    is(scalar @stored, 1, '  and reached the store');
    is($stored[0][0], 'default', '  attributed to the default tenant');
    is($stored[0][1], 'traces', '  with the right signal');
}

for my $path (qw(/v1/traces /v1/metrics /v1/logs)) {
    my $app = app();
    my $body = $path eq '/v1/traces'  ? trace_pb()
             : $path eq '/v1/logs'    ? POWire::log_request(records => [
                   POWire::log_record(time => 1,
                       body => POWire::anyvalue_string('x')) ])
             : POWire::metric_request(metrics => [ POWire::metric_gauge(
                   name => 'g', points => [
                       POWire::number_point(time => 1, as_double => 1) ]) ]);
    my $r = call($app, path => $path, body => $body);
    is($r->[0], 200, "$path accepts its own signal");
}

# --- the status-code table, row by row --------------------------------------

{
    my $app = app();
    is(call($app, path => '/nope')->[0], 404, '404 for a non-OTLP path');
    is(call($app, method => 'GET')->[0], 405, '405 for a GET');
    is(call($app, type => 'text/plain', body => 'x')->[0], 415,
       '415 for an unsupported content type');
    is(call($app, body => 'not protobuf at all')->[0], 400,
       '400 for a malformed body');
    is(call($app, type => 'application/json', body => '{ not json')->[0], 400,
       '400 for malformed JSON');
}

# A body that is valid JSON but not OTLP is a 200 with zero records, not a
# 400: every field is simply absent, which is what proto3 semantics mean.
{
    my $app = app();
    my $r = call($app, type => 'application/json', body => '{"nope":1}');
    is($r->[0], 200, 'valid JSON that is not OTLP is accepted as empty');
    is(scalar @stored, 0, '  and nothing is stored');
}

# A batch that decodes to zero records is a 200 and NO append.
{
    # A zero-length body is a valid EMPTY protobuf message, not a malformed
    # one - proto3 says an empty message has every field absent. So it is a
    # 200 with no records, consistent with the decoder in phase 1, and NOT a
    # 400: refusing it would reject a legal request.
    my $app = app();
    my $r = call($app, body => '');
    is($r->[0], 200, 'a zero-length body is a valid empty message');
    is(scalar @stored, 0, '  storing nothing');

    $app = app();
    $r = call($app, body => POWire::msg(1, ''));
    is($r->[0], 200, 'an empty ResourceSpans is a 200');
    is(scalar @stored, 0, '  with no append, so no nonsense timestamp span');
}

# 413 before the decode, not after.
{
    my $app = app(max_body => 100);
    my $r = call($app, body => 'x' x 500);
    is($r->[0], 413, '413 for a body over max_body');
    is(scalar @stored, 0, '  and it never reached the store');
}

# A store failure is a 503 - retryable - not a 500, which the client drops.
{
    my $app = Punk::Observe::Ingest->new(on_batch => sub { die "disk full\n" })->to_app;
    my $r = $app->(req(body => trace_pb()));
    is($r->[0], 503, 'a store failure is a retryable 503');
    my %h = @{ $r->[1] };
    is($h{'Retry-After'}, 1, '  with Retry-After');
}
{
    my $app = Punk::Observe::Ingest->new(on_batch => sub { 0 })->to_app;
    is($app->(req(body => trace_pb()))->[0], 503,
       'a store that returns false is also a 503');
}

# --- partial success --------------------------------------------------------

# Over the per-batch cap the excess is REJECTED and reported through
# partial_success. A 4xx would make the exporter re-send the whole batch
# forever, at exactly the moment the server is already under pressure.
{
    my $app = app(max_records => 2);
    my $body = POWire::trace_request(spans => [
        map { POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
                           name => "s$_", start => 1, end => 2) } 1 .. 5 ]);
    my $r = call($app, body => $body);
    is($r->[0], 200, 'over the record cap is a 200, not a 4xx');
    ok(length $r->[2][0], '  with a partial_success body');

    # Decode the response with the generic reader: field 1 is
    # partial_success, whose field 1 is the rejected count.
    my $outer = Punk::Observe::Decode::pb_fields($r->[2][0]);
    is($outer->{err}, 0, '  which is valid protobuf');
    is($outer->{fields}[0]{field}, 1, '  field 1 is partial_success');
    my $inner = Punk::Observe::Decode::pb_fields($outer->{fields}[0]{bytes});
    is("$inner->{fields}[0]{varint}", '3', '  reporting 3 rejected of 5');
    ok(length $inner->{fields}[1]{bytes}, '  with an error message');
}

# The JSON rendering of the same thing. Rule 3: the count is a STRING.
{
    my $app = app(max_records => 2);
    my $json = '{"resourceSpans":[{"scopeSpans":[{"spans":['
             . join(',', map {
                   '{"traceId":"01010101010101010101010101010101",'
                 . '"spanId":"0202020202020202","name":"s' . $_ . '",'
                 . '"startTimeUnixNano":"1","endTimeUnixNano":"2"}'
               } 1 .. 5)
             . ']}]}]}';
    my $r = $app->(req(type => 'application/json', body => $json));
    is($r->[0], 200, 'the JSON path also answers 200 over the cap');
    my $doc = File::Raw::JSON::file_json_decode($r->[2][0]);
    is($doc->{partialSuccess}{rejectedSpans}, '3',
       '  with the rejected count as a STRING, per rule 3');
}

# --- protobuf and JSON must agree -------------------------------------------

{
    # The same span, expressed both ways. The protobuf path is the reference
    # because it is the transport the SDK uses by default.
    my $pb = Punk::Observe::Decode::decode(trace_pb(), 'traces');

    my $json = <<'JSON';
{ "resourceSpans": [ {
    "resource": { "attributes": [
      { "key": "service.name", "value": { "stringValue": "checkout" } } ] },
    "scopeSpans": [ { "scope": { "name": "t" }, "spans": [ {
      "traceId": "01010101010101010101010101010101",
      "spanId":  "0202020202020202",
      "name": "POST /pay",
      "kind": "SPAN_KIND_SERVER",
      "startTimeUnixNano": "1774224000000000000",
      "endTimeUnixNano":   "1774224000500000000",
      "status": { "code": "STATUS_CODE_ERROR" },
      "attributes": [
        { "key": "http.route", "value": { "stringValue": "/pay" } } ]
    } ] } ] } ] }
JSON
    my $doc = File::Raw::JSON::file_json_decode($json);
    my $js  = Punk::Observe::Ingest::decode_json($doc, 'traces');

    ok($pb->{ok} && $js->{ok}, 'both encodings decode');
    is(scalar @{ $js->{records} }, 1, 'JSON yields one span');

    my ($a, $b) = ($pb->{records}[0], $js->{records}[0]);
    for my $k (qw(kind t duration span_kind status trace_hi trace_lo
                  span_id body)) {
        is("$b->{$k}", "$a->{$k}", "JSON and protobuf agree on $k");
    }
    is_deeply($b->{attrs}, $a->{attrs}, 'and on the attributes');
    is_deeply($b->{attr_order}, $a->{attr_order}, 'and on their canonical order');
}

# Rule 2: hex and base64 ids must land on the SAME sixteen bytes. A trace
# whose ids are spelled two ways silently splits in half, and presents as
# data simply being missing.
{
    my $hex = '{"resourceSpans":[{"scopeSpans":[{"spans":[{'
            . '"traceId":"0102030405060708090a0b0c0d0e0f10",'
            . '"spanId":"0102030405060708","name":"n",'
            . '"startTimeUnixNano":"1","endTimeUnixNano":"2"}]}]}]}';
    my $b64 = '{"resourceSpans":[{"scopeSpans":[{"spans":[{'
            . '"traceId":"AQIDBAUGBwgJCgsMDQ4PEA==",'
            . '"spanId":"AQIDBAUGBwg=","name":"n",'
            . '"startTimeUnixNano":"1","endTimeUnixNano":"2"}]}]}]}';
    my $h = Punk::Observe::Ingest::decode_json(
        File::Raw::JSON::file_json_decode($hex), 'traces');
    my $b = Punk::Observe::Ingest::decode_json(
        File::Raw::JSON::file_json_decode($b64), 'traces');
    is("$h->{records}[0]{trace_hi}", "$b->{records}[0]{trace_hi}",
       'a hex trace id and a base64 one decode to the same bytes');
    is("$h->{records}[0]{trace_lo}", "$b->{records}[0]{trace_lo}",
       '  in both halves');
    is("$h->{records}[0]{span_id}", "$b->{records}[0]{span_id}",
       '  and the span id too');
}

# Rule 3: a 64-bit timestamp arriving as a JSON NUMBER loses its last digits.
# As a string it must be exact.
{
    my $j = '{"resourceSpans":[{"scopeSpans":[{"spans":[{'
          . '"traceId":"01010101010101010101010101010101",'
          . '"spanId":"0202020202020202","name":"n",'
          . '"startTimeUnixNano":"1774224000000000123",'
          . '"endTimeUnixNano":"1774224000000000123"}]}]}]}';
    my $r = Punk::Observe::Ingest::decode_json(
        File::Raw::JSON::file_json_decode($j), 'traces');
    is("$r->{records}[0]{t}", '1774224000000000123',
       'a nanosecond timestamp as a JSON string is exact to the last digit');
}

# Rule 1: snake_case keys parse as a message with every field absent. That is
# proto3's own semantics - accepted, stored, and empty - so the assertion is
# that it does NOT silently look like a good span.
{
    my $j = '{"resource_spans":[{"scope_spans":[{"spans":[{'
          . '"trace_id":"01010101010101010101010101010101",'
          . '"start_time_unix_nano":"1"}]}]}]}';
    my $r = Punk::Observe::Ingest::decode_json(
        File::Raw::JSON::file_json_decode($j), 'traces');
    is(scalar @{ $r->{records} }, 0,
       'snake_case keys yield NO records, rather than an empty-looking one');
}

# Rule 4: enums by name or by number.
{
    for my $k ('"SPAN_KIND_CLIENT"', '3') {
        my $j = '{"resourceSpans":[{"scopeSpans":[{"spans":[{'
              . '"traceId":"01010101010101010101010101010101",'
              . '"spanId":"0202020202020202","name":"n","kind":' . $k . ','
              . '"startTimeUnixNano":"1","endTimeUnixNano":"2"}]}]}]}';
        my $r = Punk::Observe::Ingest::decode_json(
            File::Raw::JSON::file_json_decode($j), 'traces');
        is($r->{records}[0]{span_kind}, 3, "enum as $k reads as CLIENT");
    }
}

# --- compression ------------------------------------------------------------

SKIP: {
    # IO::Compress::Gzip rather than Compress::Raw::Zlib for the fixture:
    # WANT_GZIP is an ADDEND to MAX_WBITS, not a WindowBits value on its own,
    # so `-WindowBits => WANT_GZIP` produces a stream that is not gzip. The
    # fixture being subtly wrong is exactly the failure this test exists to
    # catch, so it uses the unambiguous API.
    eval { require IO::Compress::Gzip; 1 } or skip 'no IO::Compress::Gzip', 6;

    my $gz;
    IO::Compress::Gzip::gzip(\(my $raw = trace_pb()), \$gz) or skip 'gzip failed', 6;

    my $app = app();
    my $r = $app->(req(body => $gz,
                       env => { HTTP_CONTENT_ENCODING => 'gzip' }));
    is($r->[0], 200, 'a gzip body is accepted');
    is(scalar @stored, 1, '  and decodes to the same batch');

    # A body labelled gzip that is not gzip must be REFUSED, not passed
    # through. IO::Uncompress defaults to Transparent => 1, which would accept
    # it silently and then report a malformed OTLP payload instead of a
    # mislabelled encoding.
    $app = app();
    $r = $app->(req(body => trace_pb(),
                    env => { HTTP_CONTENT_ENCODING => 'gzip' }));
    is($r->[0], 413, 'a body labelled gzip that is not gzip is refused');

    # A gzip bomb: highly compressible input whose expansion blows the ratio.
    my $bomb;
    IO::Compress::Gzip::gzip(\(my $z = "\0" x (5 * 1024 * 1024)), \$bomb)
        or skip 'gzip failed', 3;
    cmp_ok(length($bomb), '<', 100_000, 'the bomb is small on the wire');

    $app = app(max_ratio => 20);
    $r = $app->(req(body => $bomb,
                    env => { HTTP_CONTENT_ENCODING => 'gzip' }));
    is($r->[0], 413, 'and is refused on its DECOMPRESSED size');
    is(scalar @stored, 0, '  having never reached the store');
}

# --- authentication ---------------------------------------------------------

{
    my $app = Punk::Observe::Ingest->new(
        auth     => sub {
            my ($env) = @_;
            my $h = $env->{HTTP_AUTHORIZATION} || '';
            return $h =~ /^Bearer\s+good-key$/ ? 'acme' : undef;
        },
        on_batch => sub { push @stored, [ @_[0,1] ]; 1 },
    )->to_app;

    @stored = ();
    is($app->(req(body => trace_pb()))->[0], 401,
       'no credential is a 401 when a resolver is configured');
    is(scalar @stored, 0, '  and nothing was decoded or stored');

    is($app->(req(body => trace_pb(),
        env => { HTTP_AUTHORIZATION => 'Bearer wrong' }))->[0], 401,
       'a wrong credential is a 401');

    my $r = $app->(req(body => trace_pb(),
        env => { HTTP_AUTHORIZATION => 'Bearer good-key' }));
    is($r->[0], 200, 'the right credential is accepted');
    is($stored[0][0], 'acme', '  and the batch is attributed to that tenant');
}

# With no resolver, everything is the default tenant. That is what makes "no
# key on a private network" a supported configuration rather than a hole.
{
    my $app = app();
    my $r = call($app, body => trace_pb());
    is($r->[0], 200, 'no resolver means no credential is needed');
    is($stored[0][0], 'default', '  and the tenant is `default`');
}

# --- gRPC refuses at BOOT ---------------------------------------------------

{
    my $ok = eval { Punk::Observe::Ingest->new(grpc => 1); 1 };
    ok(!$ok, 'gRPC refuses at construction rather than at the first request');
    like($@, qr/trailer/i, '  saying that trailers are the reason');
    like($@, qr/4318|HTTP/, '  and pointing at the HTTP endpoints');
}

# --- the engine as an object ------------------------------------------------

# to_app hands back the receiver itself rather than a closure around it, so
# what keeps the engine alive is the coderef the server is holding. Nothing
# else refers to it by the time a request arrives.
{
    my $app;
    {
        my $ingest = Punk::Observe::Ingest->new(
            on_batch => sub { push @stored, [ @_[0,1] ]; 1 });
        $app = $ingest->to_app;
    }
    @stored = ();
    is(call($app, body => trace_pb())->[0], 200,
       'the app outlives the object it came from');
    is(scalar @stored, 1, '  with the store callback still attached');
}

# Two apps from one engine are independent handles on the same receiver.
{
    my $ingest = Punk::Observe::Ingest->new(
        on_batch => sub { push @stored, [ @_[0,1] ]; 1 });
    my ($a, $b) = ($ingest->to_app, $ingest->to_app);
    isnt($a, $b, 'each to_app is its own coderef');
    @stored = ();
    is(call($a, body => trace_pb())->[0], 200, '  and the first serves');
    is(call($b, body => trace_pb())->[0], 200, '  and so does the second');
    is(scalar @stored, 2, '  both reaching the same store');
}

# The object is mountable directly, for a caller who would rather not carry a
# coderef around.
{
    @stored = ();
    my $ingest = Punk::Observe::Ingest->new(
        on_batch => sub { push @stored, [ @_[0,1] ]; 1 });
    is($ingest->call(req(body => trace_pb()))->[0], 200,
       'call is a method as well as an app');
    is(scalar @stored, 1, '  reaching the store the same way');
}

{
    my $ingest = Punk::Observe::Ingest->new;
    my $ok = eval { $ingest->call([]); 1 };
    ok(!$ok, 'a PSGI environment that is not a hashref is refused loudly');
}

{
    @Punk::Observe::Ingest::Sub::ISA = ('Punk::Observe::Ingest');
    my $ingest = Punk::Observe::Ingest::Sub->new;
    isa_ok($ingest, 'Punk::Observe::Ingest::Sub', 'a subclass');
    is($ingest->call(req(body => trace_pb()))->[0], 200, '  and it serves');
}

# The store callback's fifth argument is what the batch turned out to be.
{
    my $out;
    my $app = Punk::Observe::Ingest->new(
        max_records => 2,
        on_batch    => sub { $out = $_[4]; 1 })->to_app;
    my $body = POWire::trace_request(spans => [
        map { POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
                           name => "s$_", start => 1, end => 2) } 1 .. 5 ]);
    call($app, body => $body);
    is($out->{records},  2, 'on_batch is told how many records were kept');
    is($out->{rejected}, 3, '  and how many were rejected');
    ok(exists $out->{dropped_bad_trace} && exists $out->{clamped_durations},
       '  along with the decoder counters');
}

# --- the content type -------------------------------------------------------

{
    my $app = app();
    is(call($app, type => 'application/json; charset=utf-8',
                  body => '{"nope":1}')->[0], 200,
       'a content type with parameters matches on the type alone');
    is(call($app, type => 'APPLICATION/X-PROTOBUF', body => trace_pb())->[0], 200,
       'and the match is case-insensitive');
    is(call($app, type => 'application/json; charset=utf-8; boundary=' . ('x' x 300),
                  body => '{"nope":1}')->[0], 200,
       'a parameter list longer than the buffer does not hide the type');
    like(call($app, type => 'text/plain', body => 'x')->[2][0], qr/text\/plain/,
       'the 415 names the type it was given');
}

# --- compression, beyond gzip -----------------------------------------------

SKIP: {
    eval { require IO::Compress::Deflate; require IO::Compress::Gzip; 1 }
        or skip 'no IO::Compress', 5;

    my $raw = trace_pb();
    my ($df, $gz);
    IO::Compress::Deflate::deflate(\(my $a = $raw), \$df) or skip 'deflate failed', 5;
    IO::Compress::Gzip::gzip(\(my $b = $raw), \$gz)       or skip 'gzip failed', 5;

    my $app = app();
    is($app->(req(body => $df, env => { HTTP_CONTENT_ENCODING => 'deflate' }))->[0],
       200, 'a deflate body is accepted');

    # gzip and deflate are not the same stream, and neither is guessed at. A
    # body labelled as one and framed as the other is a mislabelled encoding,
    # and saying so beats passing it on to fail as malformed OTLP later.
    $app = app();
    is($app->(req(body => $gz, env => { HTTP_CONTENT_ENCODING => 'deflate' }))->[0],
       413, 'gzip framing under a deflate label is refused, not auto-detected');
    $app = app();
    is($app->(req(body => $df, env => { HTTP_CONTENT_ENCODING => 'gzip' }))->[0],
       413, '  and the other way round');

    # A stream that stops part way through is refused rather than handed on as
    # however much of it arrived - which would surface as a malformed payload
    # with the actual cause thrown away.
    $app = app();
    my $cut = substr($gz, 0, int(length($gz) / 2));
    is($app->(req(body => $cut, env => { HTTP_CONTENT_ENCODING => 'gzip' }))->[0],
       413, 'a truncated body is refused rather than partly accepted');
    is(scalar @stored, 0, '  having never reached the store');
}

# The ratio ceiling, and $MAX_RATIO as its default.
SKIP: {
    eval { require IO::Compress::Gzip; 1 } or skip 'no IO::Compress::Gzip', 3;

    # One span with a very compressible name: about 100KB of body arriving as
    # a few hundred bytes, so the expansion is the thing under test and not
    # the absolute size.
    my $raw = POWire::trace_request(spans => [
        POWire::span(trace_id => "\x01" x 16, span_id => "\x02" x 8,
                     name => 'a' x 100_000, start => 1, end => 2) ]);
    my $gz;
    IO::Compress::Gzip::gzip(\(my $c = $raw), \$gz) or skip 'gzip failed', 3;
    cmp_ok(length($gz) * 20, '<', length($raw),
           'the fixture expands past the default ratio');

    my $app = app();
    is($app->(req(body => $gz, env => { HTTP_CONTENT_ENCODING => 'gzip' }))->[0],
       413, 'the default ratio is $MAX_RATIO');

    $app = app(max_ratio => 10_000);
    is($app->(req(body => $gz, env => { HTTP_CONTENT_ENCODING => 'gzip' }))->[0],
       200, '  and max_ratio raises it');
}

# --- authentication, continued ----------------------------------------------

# A resolver that dies is a 401, not a 500: a credential that could not be
# checked has not been checked.
{
    my $app = Punk::Observe::Ingest->new(
        auth     => sub { die "the key store is down\n" },
        on_batch => sub { push @stored, [ @_[0,1] ]; 1 },
    )->to_app;
    @stored = ();
    is($app->(req(body => trace_pb()))->[0], 401, 'a resolver that dies is a 401');
    is(scalar @stored, 0, '  and nothing was decoded or stored');
}

{
    my $app = Punk::Observe::Ingest->new(auth => sub { '' })->to_app;
    is($app->(req(body => trace_pb()))->[0], 401,
       'an empty tenant is a 401, the same as undef');
}

done_testing();

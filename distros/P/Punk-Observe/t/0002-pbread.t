#!perl
# The wire contract. No OTLP schema here: this is po_pb_read.h alone.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;
use POWire;

sub parse { Punk::Observe::Decode::pb_fields($_[0]) }

# --- every wire type round-trips -------------------------------------------

{
    # 0x0123456789abcdef spelled as a decimal STRING, not a hex literal: perl
    # warns "Hexadecimal number > 0xffffffff non-portable" and a 32-bit perl
    # cannot hold it. The test would then be testing the wrong value on
    # exactly the machines this rule exists for.
    my $buf = POWire::vint(1, 150)
            . POWire::fixed64(2, '81985529216486895')
            . POWire::fixed32(3, 0xdeadbeef)
            . POWire::bytes(4, 'hello')
            . POWire::dbl(5, 3.5);
    my $r = parse($buf);
    is($r->{err}, 0, 'clean parse') or diag $r->{errstr};
    my @f = @{ $r->{fields} };
    is(scalar @f, 5, 'five fields');
    is($f[0]{field}, 1, 'field 1'); is("$f[0]{varint}", '150', 'varint 150');
    is($f[1]{field}, 2, 'field 2');
    is("$f[1]{fixed64}", '81985529216486895', 'fixed64 little-endian');
    is($f[2]{fixed32}, 0xdeadbeef, 'fixed32');
    is($f[3]{bytes}, 'hello', 'length-delimited borrows the right bytes');
    is($f[4]{double}, 3.5, 'double');
}

# --- varint edges -----------------------------------------------------------

for my $v (qw(0 1 127 128 300 16383 16384 4294967295 4294967296
              9007199254740993 9223372036854775808 18446744073709551615)) {
    my $r = parse(POWire::vint(1, $v));
    is($r->{err}, 0, "varint $v parses") or diag $r->{errstr};
    is("$r->{fields}[0]{varint}", $v, "varint $v exact");
}

# An eleven-byte varint is refused, not read.
{
    my $r = parse(POWire::bad_varint_too_long(1));
    isnt($r->{err}, 0, 'an eleven-byte varint is refused');
    is($r->{errstr}, 'varint too long', '  and says why');
}

# A ten-byte varint whose last byte carries more than bit 0 would overflow
# a uint64_t. Refused rather than silently wrapped.
{
    my $r = parse(POWire::bad_varint_overflow(1));
    isnt($r->{err}, 0, 'a varint that would overflow u64 is refused');
    is($r->{errstr}, 'varint too long', '  rather than wrapping');
}

# A varint running off the end of the buffer.
{
    my $r = parse(POWire::bad_truncated_varint(1));
    isnt($r->{err}, 0, 'a truncated varint is refused');
    is($r->{errstr}, 'truncated', '  as truncated');
}

# --- negative int32, sign-extended to ten bytes -----------------------------

for my $v (-1, -2, -128, -2147483648) {
    my $r = parse(POWire::int32(1, $v));
    is($r->{err}, 0, "int32 $v parses") or diag $r->{errstr};
    is($r->{fields}[0]{int32}, $v, "int32 $v reads back NEGATIVE, not 4294967295");
}

# The specific bug: reading -1 as an unsigned 32-bit value.
{
    my $r = parse(POWire::int32(1, -1));
    isnt($r->{fields}[0]{int32}, 4294967295, '-1 is not 4294967295');
}

# --- length overrun ---------------------------------------------------------

{
    my $r = parse(POWire::bad_length_overrun(1));
    isnt($r->{err}, 0, 'a length past the end of the buffer is refused');
    is($r->{errstr}, 'truncated', '  and is not clamped to what remains');
}

# A length-delimited field that exactly fills the buffer is fine.
{
    my $r = parse(POWire::bytes(1, 'x' x 100));
    is($r->{err}, 0, 'a length that exactly fits is accepted');
    is(length($r->{fields}[0]{bytes}), 100, '  with all its bytes');
}

# --- deprecated groups ------------------------------------------------------

{
    my $r = parse(POWire::bad_group(1));
    isnt($r->{err}, 0, 'wire type 3 (start-group) is refused');
    is($r->{errstr}, 'unsupported wire type',
       '  because it has no length prefix and cannot be skipped');
}
{
    my $r = parse(POWire::tag(1, 4));
    isnt($r->{err}, 0, 'wire type 4 (end-group) is refused too');
}

# --- field number 0 is illegal ---------------------------------------------

{
    my $r = parse(POWire::tag(0, 0) . chr(1));
    isnt($r->{err}, 0, 'field number 0 is refused');
    is($r->{errstr}, 'field number 0', '  by name');
}

# --- unknown fields are SKIPPED, at every wire type -------------------------

{
    # Fields 7000-7003 are not in any OTLP message. The known field around
    # them must still be found.
    my $buf = POWire::vint(7000, 1)
            . POWire::fixed64(7001, 42)
            . POWire::bytes(7002, 'junk')
            . POWire::fixed32(7003, 7)
            . POWire::bytes(5, 'the one we want');
    my $r = parse($buf);
    is($r->{err}, 0, 'unknown fields at every wire type parse');
    is(scalar @{ $r->{fields} }, 5, '  all five seen');
    is($r->{fields}[4]{bytes}, 'the one we want', '  and the known one survives');
}

# A message of nothing but unknown fields is EMPTY, not an error. This is the
# forward-compatibility contract: OTLP adds fields, and a strict reader would
# break on the release after the one it was written for.
{
    my $r = parse(POWire::vint(9001, 1) . POWire::bytes(9002, 'x'));
    is($r->{err}, 0, 'a message of only unknown fields is not an error');
}

# --- the empty message ------------------------------------------------------

{
    my $r = parse('');
    is($r->{err}, 0, 'an empty buffer is valid');
    is(scalar @{ $r->{fields} }, 0, '  with no fields');
}

# --- repeated fields split across the message -------------------------------

# `field 1, field 2, field 1` is legal protobuf. A reader that stops after the
# first run of a field loses the rest.
{
    my $buf = POWire::vint(1, 10) . POWire::vint(2, 99) . POWire::vint(1, 20);
    my $r = parse($buf);
    is($r->{err}, 0, 'a split repeated field parses');
    my @ones = grep { $_->{field} == 1 } @{ $r->{fields} };
    is(scalar @ones, 2, '  both occurrences of field 1 are seen');
    is("$ones[1]{varint}", '20', '  including the one after the interruption');
}

# --- packed and unpacked repeated numerics ---------------------------------

{
    my $packed = parse(POWire::packed_varints(6, 1, 2, 3, 300));
    is($packed->{err}, 0, 'packed repeated parses');
    is(scalar @{ $packed->{fields} }, 1, '  as one length-delimited field');

    my $unpacked = parse(POWire::unpacked_varints(6, 1, 2, 3, 300));
    is($unpacked->{err}, 0, 'unpacked repeated parses');
    is(scalar @{ $unpacked->{fields} }, 4, '  as four varint fields');
    is("$unpacked->{fields}[3]{varint}", '300', '  with the last value intact');
}

# --- no read past the end ---------------------------------------------------

# Every prefix of a valid message must either parse or fail cleanly. None may
# read past its buffer; under ASan this is where that would show.
{
    my $full = POWire::trace_request(
        resource => POWire::resource(
            POWire::keyvalue('service.name', POWire::anyvalue_string('api'))),
        spans => [ POWire::span(
            trace_id => "\x01" x 16, span_id => "\x02" x 8,
            name => 'GET /x', kind => 2, start => 1, end => 2) ],
    );
    my $bad = 0;
    for my $n (0 .. length($full) - 1) {
        my $r = eval { parse(substr($full, 0, $n)) };
        $bad++ unless defined $r;
    }
    is($bad, 0, 'every one of ' . length($full)
              . ' truncations parses or fails cleanly, none crashes');
}

done_testing();

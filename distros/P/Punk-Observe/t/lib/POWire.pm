package POWire;
# An independent protobuf WRITER, in Perl, written from the wire spec alone.
#
# This shares no code with po_pb_read.h and no code with Punk::OpenTelemetry's
# encoder. That is the entire point. A probe built from the same understanding
# as the thing it tests CONFIRMS the bug rather than finding it - the mistake
# that cost ClamAV::Clamd a wrong protocol fact from phase 0 all the way to
# phase 3 - and Punk::OpenTelemetry's own OTelWire.pm makes this argument
# about itself in the opposite direction.
#
# So: the SDK's encoder is one independent check on the reader, and this is a
# second one that can also emit things the SDK never would - an eleven-byte
# varint, a length that overruns, a deprecated group, an unpacked repeated
# field. Those are exactly the inputs a real endpoint has to survive.
use strict;
use warnings;

# --- primitives -------------------------------------------------------------

# Is this decimal string past what THIS perl's UV can hold?
#
# The first version of this fixture asked `length("$v") > 18`, which is the
# 64-bit answer written down as a constant. On a 32-bit-IV perl anything past
# 4294967295 is corrupted by the native path, and 10 digits is not 19 - so the
# encoder silently clamped every value between 2^32 and 2^63 to UV_MAX and the
# decoder was blamed for it. The threshold has to come from the perl running
# the test, not from the perl the fixture was written on.
sub _wide {
    my ($s) = @_;
    return 0 unless "$s" =~ /^\d+$/;
    my $max = "" . ~0;                  # UV_MAX for this perl, as digits
    (my $d = "$s") =~ s/^0+(?=\d)//;
    return 1 if length($d) > length($max);
    return length($d) == length($max) && $d gt $max;
}

sub varint {
    my ($v) = @_;
    my $out = '';

    # Values near the top of the u64 range arrive as decimal STRINGS, because
    # that is how this distribution moves 64-bit numbers and because a 32-bit
    # perl cannot hold them any other way. Math::BigInt does that arithmetic;
    # it is only reached for values a native integer would corrupt.
    if (_wide($v)) {
        require Math::BigInt;
        my $b = Math::BigInt->new("$v");
        while (1) {
            my $byte = $b->copy->bmod(128)->numify;
            $b->bdiv(128);
            if ($b->is_zero) { $out .= chr($byte); last }
            $out .= chr($byte | 0x80);
        }
        return $out;
    }

    $v = 0 + $v;
    while (1) {
        my $byte = $v & 0x7F;
        $v >>= 7;
        if ($v) { $out .= chr($byte | 0x80) } else { $out .= chr($byte); last }
    }
    return $out;
}

sub tag { my ($f, $w) = @_; varint(($f << 3) | $w) }

sub bytes    { my ($f, $s) = @_; tag($f, 2) . varint(length $s) . $s }
sub msg      { my ($f, $s) = @_; bytes($f, $s) }
sub vint     { my ($f, $v) = @_; tag($f, 0) . varint($v) }
# Eight little-endian bytes, built without pack('Q').
#
# 'Q' needs a perl built with 64-bit integers: on a 32-bit-IV build it either
# croaks "Invalid type" or silently truncates. Since this fixture exists to be
# run on exactly those perls, it does the arithmetic itself.
sub u64le {
    my ($v) = @_;
    if (_wide($v)) {
        require Math::BigInt;
        my $b = Math::BigInt->new("$v");
        my $out = '';
        for (1 .. 8) {
            $out .= chr($b->copy->bmod(256)->numify);
            $b->bdiv(256);
        }
        return $out;
    }
    $v = 0 + $v;
    my $out = '';
    for (1 .. 8) { $out .= chr($v & 0xFF); $v >>= 8 }
    return $out;
}

sub fixed64  { my ($f, $v) = @_; tag($f, 1) . u64le($v) }
sub fixed32  { my ($f, $v) = @_; tag($f, 5) . pack('V',  $v) }
sub dbl      { my ($f, $d) = @_; tag($f, 1) . pack('d<', $d) }

# A negative int32 is sign-extended to ten bytes. Written by hand here rather
# than by shifting, because that is precisely the encoding under test.
sub int32 {
    my ($f, $v) = @_;
    return vint($f, $v) if $v >= 0;
    # protobuf sign-extends a negative int32 to 64 bits before varint-encoding
    # it, so -1 is ten bytes: ff ff ff ff ff ff ff ff ff 01. A reader that
    # assumes an int32 fits five bytes reads garbage from valid input.
    require Math::BigInt;
    my $u = Math::BigInt->new(2)->bpow(64)->badd("$v");   # two's complement
    return tag($f, 0) . varint($u->bstr);
}

# --- deliberately malformed -------------------------------------------------

# Eleven continuation bytes: longer than any legal varint.
sub bad_varint_too_long { my ($f) = @_; tag($f, 0) . (chr(0x80) x 11) . chr(0x01) }

# A ten-byte varint whose tenth byte carries more than bit 0, so it would
# overflow a uint64_t. Must be refused, not wrapped.
sub bad_varint_overflow { my ($f) = @_; tag($f, 0) . (chr(0xFF) x 9) . chr(0x7F) }

# A length-delimited field claiming more bytes than remain.
sub bad_length_overrun { my ($f) = @_; tag($f, 2) . varint(1000) . 'short' }

# Wire type 3: a deprecated start-group. OTLP never emits one, and it cannot
# be skipped without understanding the schema.
sub bad_group { my ($f) = @_; tag($f, 3) }

# A varint truncated at the buffer end.
sub bad_truncated_varint { my ($f) = @_; tag($f, 0) . chr(0x80) }

# --- repeated, both spellings ----------------------------------------------

sub packed_varints {
    my ($f, @v) = @_;
    bytes($f, join '', map { varint($_) } @v);
}

sub unpacked_varints {
    my ($f, @v) = @_;
    join '', map { vint($f, $_) } @v;
}

# --- OTLP shapes, built from the numbers in otel_proto.h --------------------

sub anyvalue_string { my ($s) = @_; bytes(1, $s) }
sub anyvalue_bool   { my ($b) = @_; vint(2, $b ? 1 : 0) }
sub anyvalue_int    { my ($i) = @_; vint(3, $i) }
sub anyvalue_double { my ($d) = @_; dbl(4, $d) }
sub anyvalue_bytes  { my ($s) = @_; bytes(7, $s) }
sub anyvalue_array  { my (@vals) = @_; msg(5, join '', map { msg(1, $_) } @vals) }
sub anyvalue_kvlist { my (@kvs)  = @_; msg(6, join '', map { msg(1, $_) } @kvs) }

sub keyvalue { my ($k, $v) = @_; bytes(1, $k) . msg(2, $v) }

sub resource   { my (@kvs) = @_; msg(1, join '', map { msg(1, $_) } @kvs) }
sub scope      { my ($n, $v) = @_; msg(1, bytes(1, $n) . bytes(2, $v // '')) }

sub span {
    my (%a) = @_;
    my $s = '';
    $s .= bytes(1, $a{trace_id})   if defined $a{trace_id};
    $s .= bytes(2, $a{span_id})    if defined $a{span_id};
    $s .= bytes(4, $a{parent_id})  if defined $a{parent_id};
    $s .= bytes(5, $a{name})       if defined $a{name};
    $s .= vint(6, $a{kind})        if defined $a{kind};
    $s .= fixed64(7, $a{start})    if defined $a{start};
    $s .= fixed64(8, $a{end})      if defined $a{end};
    $s .= join '', map { msg(9, $_) } @{ $a{attributes} || [] };
    $s .= msg(15, vint(3, $a{status})) if defined $a{status};
    $s .= $a{extra} if defined $a{extra};
    return $s;
}

sub trace_request {
    my (%a) = @_;
    my $scope_spans = msg(2, ($a{scope} // scope('t', '1'))
                            . join '', map { msg(2, $_) } @{ $a{spans} || [] });
    my $rs = ($a{resource} // '') . $scope_spans;
    return msg(1, $rs);
}

sub log_record {
    my (%a) = @_;
    my $s = '';
    $s .= fixed64(1, $a{time})              if defined $a{time};
    $s .= vint(2, $a{severity})             if defined $a{severity};
    $s .= msg(5, $a{body})                  if defined $a{body};
    $s .= join '', map { msg(6, $_) } @{ $a{attributes} || [] };
    $s .= bytes(9, $a{trace_id})            if defined $a{trace_id};
    $s .= bytes(10, $a{span_id})            if defined $a{span_id};
    $s .= fixed64(11, $a{observed})         if defined $a{observed};
    return $s;
}

sub log_request {
    my (%a) = @_;
    my $scope_logs = msg(2, ($a{scope} // scope('t', '1'))
                           . join '', map { msg(2, $_) } @{ $a{records} || [] });
    return msg(1, ($a{resource} // '') . $scope_logs);
}

sub number_point {
    my (%a) = @_;
    my $s = '';
    $s .= fixed64(3, $a{time})                          if defined $a{time};
    $s .= dbl(4, $a{as_double})                         if defined $a{as_double};
    $s .= vint(6, $a{as_int})                           if defined $a{as_int};
    $s .= join '', map { msg(7, $_) } @{ $a{attributes} || [] };
    return $s;
}

# temporality: OTLP DELTA=1, CUMULATIVE=2 (the reverse of the SDK's internal
# constants - otel_proto.h:217-226 is emphatic about it, so the tests are too)
sub metric_sum {
    my (%a) = @_;
    my $s = join '', map { msg(1, $_) } @{ $a{points} || [] };
    $s .= vint(2, $a{temporality}) if defined $a{temporality};
    $s .= vint(3, 1)               if $a{monotonic};
    return bytes(1, $a{name}) . msg(7, $s);
}

sub metric_gauge {
    my (%a) = @_;
    my $s = join '', map { msg(1, $_) } @{ $a{points} || [] };
    return bytes(1, $a{name}) . msg(5, $s);
}

sub metric_request {
    my (%a) = @_;
    my $scope_metrics = msg(2, ($a{scope} // scope('t', '1'))
                              . join '', map { msg(2, $_) } @{ $a{metrics} || [] });
    return msg(1, ($a{resource} // '') . $scope_metrics);
}

1;

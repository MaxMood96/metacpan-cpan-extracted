#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PPKTest qw(fixture_dir hex_to_bytes);
use File::Raw::JSON ();
use Punk::Passkey ();

# The decoder against the RFC 8949 Appendix A vectors, verbatim, from
# the CBOR project's published copy (t/fixtures/README names it).
#
# Both directions matter, and only one of them is obvious:
#
#   every vector this ACCEPTS must decode to the published value - so a
#   misread cannot hide;
#
#   every vector this REFUSES must be one the documented subset
#   excludes - so a bug cannot hide behind "not supported", which is
#   the failure mode a subset decoder invites.
#
# The expectation for each vector is derived from the vector's OWN
# published fields, never from what this decoder happens to do.

my $path = fixture_dir() . '/cbor-appendix-a.json';
open my $fh, '<', $path or plan skip_all => "no CBOR fixtures: $!";
my $json = do { local $/; <$fh> };
close $fh;
my $vectors = File::Raw::JSON::file_json_decode($json)
    or plan skip_all => 'the CBOR fixture did not decode';
ok(@$vectors > 50, 'the published vector set loaded (' . @$vectors . ' vectors)');

# Which vectors the documented subset excludes, decided from the
# published `hex` and `diagnostic` and nothing else:
#
#   f9/fa/fb   the three float widths
#   f7         undefined; f0, f8xx  other simple values
#   c0-db      a tag
#   5f/7f/9f/bf an indefinite-length string, array or map
#   '_' in the diagnostic  an indefinite length anywhere inside
#
# true (f5), false (f4) and null (f6) are IN the subset.
sub excluded {
    my ($v) = @_;
    my $hex  = lc $v->{hex};
    my $diag = $v->{diagnostic};
    my $b    = hex substr $hex, 0, 2;
    return 'float'       if $b == 0xf9 || $b == 0xfa || $b == 0xfb;
    return 'simple'      if $b == 0xf7 || $b == 0xf0 || $b == 0xf8;
    return 'tag'         if $b >= 0xc0 && $b <= 0xdb;
    return 'indefinite'  if $b == 0x5f || $b == 0x7f || $b == 0x9f || $b == 0xbf;
    return 'indefinite'  if defined $diag && $diag =~ /_/;
    # an 8-byte argument of 0xffffffffffffffff, unsigned (1b) or
    # negative (3b): past what an IV holds, either way
    return 'big integer' if $hex =~ /\A[13]bffffffffffffffff/;
    # An indefinite length NESTED inside a definite container leaves no
    # mark on the outer bytes and none in a JSON `decoded`, so those
    # vectors would look admissible above. The published `roundtrip`
    # flag catches them: re-encoding an indefinite item yields the
    # definite form, so it is false for exactly the indefinite vectors
    # and the non-finite floats - both already outside the subset.
    return 'indefinite (nested)' if !$v->{roundtrip};
    return undef;
}

# The published value, as a canonical string this decoder's output can
# be rendered into. Byte strings and integer-keyed maps have no JSON
# form, so the appendix gives those as diagnostic notation.
sub render {
    my ($v) = @_;
    if (!defined $v)   { return 'null' }
    my $r = ref $v;
    # the JSON decoder gives true/false as blessed singletons; this
    # decoder gives 1 and 0, which is what a C caller wants to test
    if ($r eq 'File::Raw::JSON::Boolean') { return $$v ? 1 : 0 }
    if ($r eq 'ARRAY') { return '[' . join(', ', map { render($_) } @$v) . ']' }
    if ($r eq 'HASH')  {
        return '{' . join(', ', map { "$_: " . render($v->{$_}) }
                                sort keys %$v) . '}';
    }
    # The published value is a character string; this decoder hands
    # back the UTF-8 BYTES with the flag off, on purpose (see the
    # contract asserted below), so the comparison is made in bytes.
    my $s = $v;
    utf8::encode($s) if utf8::is_utf8($s);
    return $s;
}

# CBOR null decodes to Perl undef, which is also what a refusal
# returns - so at the Perl seam the signal is $ERR, empty on success.
# (The C entry point has no such ambiguity: it returns an SV pointer,
# or NULL. Phases 1 and 2 call the C, not this.)
sub decode {
    my ($bytes) = @_;
    $Punk::Passkey::ERR = '';
    my $got = Punk::Passkey::_decode_cbor($bytes);
    return ($got, $Punk::Passkey::ERR eq '' ? 1 : 0);
}

my ($accepted, $refused, $checked) = (0, 0, 0);
my @wrong_value;

for my $v (@$vectors) {
    my $bytes = hex_to_bytes($v->{hex});
    my $why   = excluded($v);
    my ($got, $ok) = decode($bytes);

    if ($why) {
        $refused++;
        if ($ok) {
            fail("$v->{hex} is $why and must be refused");
        }
        else {
            like($Punk::Passkey::ERR, qr/\S/,
                "$v->{hex} ($why) refused, with a reason");
        }
        next;
    }

    $accepted++;
    unless ($ok) {
        fail("$v->{hex} is inside the subset but was refused: "
           . $Punk::Passkey::ERR);
        next;
    }

    # A value to compare against: the published `decoded` where JSON
    # could express it, else the diagnostic for the two shapes it
    # could not.
    if (exists $v->{decoded}) {
        $checked++;
        my $want = render($v->{decoded});
        my $have = render($got);
        push @wrong_value, "$v->{hex}: got $have, published $want"
            if $have ne $want;
    }
    elsif (defined $v->{diagnostic} && $v->{diagnostic} =~ /\Ah'([0-9a-f]*)'\z/) {
        $checked++;
        my $want = $1;
        my $have = unpack 'H*', $got;
        push @wrong_value, "$v->{hex}: bytes $have, published $want"
            if $have ne $want;
    }
}

is(scalar @wrong_value, 0,
    'every accepted vector decoded to the value the RFC publishes for it')
    or diag join "\n", @wrong_value;

ok($checked >= 30,
    "$checked vectors were compared against a published value - a subset "
  . 'decoder that quietly refused most of its corpus would still pass the '
  . 'refusal half, so the acceptance half is counted');

# The split is pinned. A change that starts refusing valid documents,
# or accepting excluded ones, moves these numbers and has to be
# explained rather than absorbed.
is($accepted + $refused, scalar @$vectors, 'every vector was classified');
is($accepted, 35, 'the subset accepts 35 of the published vectors');
is($refused,  47, 'and refuses 47 as outside it');

# ---- text strings come back as bytes, and that is the contract ---------------
# Not an accident of the C: everything the protocol layer does with a
# decoded string is compare it against a constant or hash it, and a
# character string entering either is a double-encode. The one string
# that is ever shown to a person is decoded at that seam.
{
    my ($got, $ok) = decode(hex_to_bytes('62c3bc'));      # "u-umlaut"
    ok($ok, 'a UTF-8 text string decodes');
    ok(!utf8::is_utf8($got), '...as bytes, with the UTF-8 flag off');
    is(length $got, 2, '...two bytes, not one character');
    is(unpack('H*', $got), 'c3bc', '...the UTF-8 encoding, unaltered');
}

# ---- the value of a refusal is that it happens for the right reason ----

my %reason_for = (
    '9f018202039f0405ffff' => qr/indefinite/,   # indefinite array
    'bf61610161629f0203ffff' => qr/indefinite/, # indefinite map
    '5f42010243030405ff'   => qr/indefinite/,   # chunked byte string
    'c074323031332d30332d32315432303a30343a30305a' => qr/tag/,
    'f97e00'               => qr/float/,
    'f7'                   => qr/simple/,
);
for my $hex (sort keys %reason_for) {
    my ($got, $ok) = decode(hex_to_bytes($hex));
    is($ok, 0, "$hex refused");
    like($Punk::Passkey::ERR, $reason_for{$hex},
        "...naming the reason, not a generic failure");
}

done_testing;

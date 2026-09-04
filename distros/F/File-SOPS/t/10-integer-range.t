#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Config;

use File::SOPS;
use File::SOPS::Encrypted;
use File::SOPS::Metadata;
use JSON::MaybeXS;
use YAML::XS ();
use Crypt::Age;

# ----------------------------------------------------------------------------
# The SOPS int type is Go's int64, and nothing wider (k28).
#
# Measured against sops 3.13.3, one key per document, both formats:
#
#   range                         YAML (yaml.v3)              JSON (encoding/json)
#   -----------------------------------------------------------------------------
#   [-2^63, 2^63-1]               type:int, exact             type:int, exact
#   [2^63, 2^64-1]                REFUSED: exit 23,           type:float, truncated
#                                 "Cannot walk value,         to float64
#                                  unknown type: uint64"
#   > 2^64-1 / < -2^63            type:float, truncated       type:float, truncated
#
# So sops NEVER writes type:int outside int64, in either format, and reading one
# fails in Go with "strconv.Atoi: value out of range".
#
# Perl's IV/UV is unsigned-capable, so a Perl integer can sit in [2^63, 2^64-1]
# where Go's int cannot. File::SOPS wrote those as type:int with their exact
# decimal, and the file was then unreadable:
#
#   $ sops -d
#   Error decrypting tree: Error walking tree: Could not decrypt value:
#   strconv.Atoi: parsing "12345678901234567890": value out of range   (exit 25)
#
# Unencrypted leaves are worse, because they reach the document verbatim:
#
#   YAML: Cannot walk value, unknown type: uint64                      (exit 25)
#   JSON: MAC mismatch                                                 (exit 51)
#         (Go re-derives 12345678901234567000 from the float64 it parsed,
#          while we hashed the exact 12345678901234567890)
#
# There is no SOPS wire form that preserves such an integer, so it is refused
# rather than silently truncated to a float64 the way sops's JSON store does.
# A caller who needs the digits passes them as a STRING, which is type:str and
# round-trips exactly through both implementations.
#
# No sops binary needed; t/04-interop.t pins the Go half.
# ----------------------------------------------------------------------------

plan skip_all => "needs a 64-bit-integer Perl (ivsize=$Config{ivsize})"
    unless $Config{ivsize} >= 8;

my ($public, $secret) = Crypt::Age->generate_keypair();

my $INT64_MAX = 9223372036854775807;
my $INT64_MIN = -9223372036854775807 - 1;

# ----------------------------------------------------------------------------
# 1. The boundary itself must still work. These are the widest values sops
#    writes as type:int, so refusing them would be a different bug.
# ----------------------------------------------------------------------------

for my $edge ($INT64_MAX, $INT64_MIN, 0, 42, -1) {
    is(File::SOPS::Encrypted->detect_type($edge), 'int', "detect_type($edge) is int");
    is(File::SOPS::Encrypted->value_to_bytes($edge), "$edge",
        "value_to_bytes($edge) is its exact decimal");

    my $enc = eval {
        File::SOPS->encrypt(
            data => { v => $edge }, recipients => [$public], format => 'yaml',
        );
    };
    ok($enc, "encrypt accepts $edge") or diag("died: $@");
    like($enc, qr/type:int\]/, "and writes it as type:int") if $enc;
}

# ----------------------------------------------------------------------------
# 2. An integer above int64 must be refused, not written.
#
#    Both the encrypted case (which produced a file sops exits 25 on) and the
#    unencrypted one (exit 25 in YAML, MAC mismatch in JSON).
# ----------------------------------------------------------------------------

my $UV_BIG = 12345678901234567890;   # 2^63 < x < 2^64: a Perl UV, not a Go int

is(File::SOPS::Encrypted->detect_type($UV_BIG), 'int',
    'a Perl UV above int64 is still what Perl holds it as');

for my $format (qw(yaml json)) {
    for my $key (qw(v v_unencrypted)) {
        my $err = do {
            local $@;
            eval {
                File::SOPS->encrypt(
                    data       => { $key => $UV_BIG },
                    recipients => [$public],
                    format     => $format,
                );
            };
            $@;
        };

        like($err, qr/int64/,
            "[$format] encrypt refuses an integer above int64 under '$key'");
        unlike($err, qr/\Q$UV_BIG\E/,
            "[$format] and the error does not quote the value back");
    }
}

# The same refusal from the value-level API, which is where a direct caller
# would hit it.
{
    my $err = do {
        local $@;
        eval {
            File::SOPS::Encrypted->encrypt_value(
                value => $UV_BIG, key => "\0" x 32, aad => 'v:',
            );
        };
        $@;
    };
    like($err, qr/int64/, 'encrypt_value refuses an integer above int64');
}

# ----------------------------------------------------------------------------
# 3. A caller who needs the digits passes a string. That is type:str and is
#    written verbatim, which is exactly what sops does with a quoted scalar.
# ----------------------------------------------------------------------------

{
    my $as_string = '12345678901234567890';
    is(File::SOPS::Encrypted->detect_type($as_string), 'str',
        'the same digits as a string are type:str');
    is(File::SOPS::Encrypted->value_to_bytes($as_string), '12345678901234567890',
        'and go to the wire verbatim');

    my $enc = File::SOPS->encrypt(
        data => { v => $as_string }, recipients => [$public], format => 'yaml',
    );
    like($enc, qr/type:str\]/, 'and encrypt writes them');
    is(
        File::SOPS->decrypt(encrypted => $enc, identities => [$secret])->{v},
        $as_string,
        'and they come back with every digit'
    );
}

# ----------------------------------------------------------------------------
# 4. Values ABOVE 2^64 already become NVs in Perl, so they are type:float and
#    take the canonical Go float form. That must not change -- it is what sops
#    writes for the same input.
# ----------------------------------------------------------------------------

{
    my $huge = YAML::XS::Load("v: 123456789012345678901234567890\n")->{v};
    is(File::SOPS::Encrypted->detect_type($huge), 'float',
        'a value above 2^64 is a float, as it is in Go');
    is(File::SOPS::Encrypted->value_to_bytes($huge), '123456789012345680000000000000',
        'and is written in the positional form sops writes');
}

# ----------------------------------------------------------------------------
# 5. READING must not refuse what sops legitimately writes.
#
#    sops's JSON store truncates a big integer to float64 and then writes the
#    RESULT into the document -- 12345678901234567000, which is above int64 but
#    below 2^64, so Perl parses it back as an exact UV. Such a leaf, unencrypted,
#    is part of the digest, and File::SOPS must hash it as those same digits.
#    A blanket range check on value_to_bytes would reject this real sops file.
# ----------------------------------------------------------------------------

{
    my $from_sops = decode_json('{"v": 12345678901234567000}')->{v};
    is(File::SOPS::Encrypted->detect_type($from_sops), 'int',
        'Perl parses a truncated sops float back as an integer');
    is(
        File::SOPS::Encrypted->value_to_bytes($from_sops),
        '12345678901234567000',
        'and value_to_bytes still produces the bytes Go re-derives, without refusing'
    );
}

# ----------------------------------------------------------------------------
# 6. Reading a type:int whose plaintext Go itself refuses must be loud.
#
#    Go stops with "strconv.Atoi: value out of range". File::SOPS ran it through
#    int(), which is exact up to 2^64-1 on this Perl and silently lossy above --
#    so the same document gave one answer here and no answer at all in Go.
#    Hand-built fixtures: no producer writes these, which is the point.
# ----------------------------------------------------------------------------

{
    my $key = "\1" x 32;

    for my $plaintext ('12345678901234567890',
                       '123456789012345678901234567890',
                       '-9223372036854775809') {
        # Built with an explicit type, which overrides the label and not the
        # bytes -- the documented way to reproduce a foreign producer's value.
        my $enc = File::SOPS::Encrypted->encrypt_value(
            value => $plaintext, key => $key, aad => 'v:', type => 'int',
        );
        is($enc->type, 'int', "fixture for $plaintext is labelled int");

        my $err = do {
            local $@;
            eval { $enc->decrypt_value(key => $key, aad => 'v:') };
            $@;
        };
        like($err, qr/int64|out of range/,
            "decrypting type:int with plaintext out of int64 range is refused");

        # The raw plaintext stays reachable, so the value is not lost.
        is($enc->decrypt_bytes(key => $key, aad => 'v:'), $plaintext,
            'and decrypt_bytes still returns the authenticated plaintext');
    }

    # An in-range value through the same fixture path must still decrypt.
    my $ok = File::SOPS::Encrypted->encrypt_value(
        value => '9223372036854775807', key => $key, aad => 'v:', type => 'int',
    );
    is($ok->decrypt_value(key => $key, aad => 'v:'), 9223372036854775807,
        'int64 max still decrypts');
}

# ----------------------------------------------------------------------------
# 7. The refusal offers BOTH answers, and both of them are true (k104).
#
#    Until 0.003 the message closed with "Pass it as a string to store it
#    exactly", because that was the only answer there was. ADR 0021 gave this
#    window a second one -- the double, which is what sops itself writes for
#    such a number -- and a message that does not mention it sends every caller
#    to the one answer that does NOT reproduce the sops-compatible leaf.
#
#    This block pins the message by its CONTENT and not by its wording, and
#    then runs both answers it offers: an error message that recommends
#    something untrue is worse than a terse one.
#
#    Measured for k104 against sops 3.13.3, 12 literals across the window
#    x 2 formats x 2 slots. The STRING answer: 48 of 48 `sops -d` exit 0 with
#    the digits verbatim. The FLOAT answer: 41 of 48 exit 0 with sops's own
#    normalisation, the other 7 -- all of them UNENCRYPTED YAML -- refused here
#    by ADR 0013's guard instead, and not one cell that put a file on disk sops
#    rejects. That 7 is why the message offers the float as an answer and not
#    as a promise. The Go half of this is t/04-interop.t's business; this file
#    needs no binary.
# ----------------------------------------------------------------------------

{
    my $err = do {
        local $@;
        eval { File::SOPS::Encrypted->assert_representable($UV_BIG) };
        $@;
    };

    like($err, qr/int64/, 'the refusal still names the range it is about');
    unlike($err, qr/\Q$UV_BIG\E/, 'and still does not quote the value back');

    like($err, qr/\bstring\b/i, 'the message offers the string answer');
    like($err, qr/type:str\b/, '... and names the type that answer writes');

    # Naming type:float in the "it would lose digits" clause is not OFFERING
    # the float -- the pre-0.003 message already did that. The conversion is
    # what makes it an offer, so the conversion is what this pins: drop the
    # float answer again and this assertion is the one that fails.
    like($err, qr/type:float\b/, 'the message offers the float answer too');
    like($err, qr/pack\s*\(\s*'d'/,
        '... naming the conversion that actually produces a float SV');
    like($err, qr/YAML/i,
        '... and saying the float answer is conditional, not a promise');
}

{
    # Answer one, executed.
    my $as_string = '12345678901234567890';
    is(File::SOPS::Encrypted->detect_type($as_string), 'str',
        'the string answer is type:str');
    ok(eval { File::SOPS::Encrypted->assert_representable($as_string) },
        '... and this guard lets it through');

    # Answer two, executed -- the exact spelling the message hands over.
    my $as_float = unpack('d', pack('d', 12345678901234567890));
    is(File::SOPS::Encrypted->detect_type($as_float), 'float',
        'the conversion the message names produces a float');
    ok(eval { File::SOPS::Encrypted->assert_representable($as_float) },
        '... which this guard lets through');
    is(File::SOPS::Encrypted->value_to_bytes($as_float), '12345678901234567000',
        '... and whose digest is the canonical decimal sops writes for it');

    # The spelling a caller reaches for first, and the reason the message
    # names pack/unpack instead of "make it a float": Perl's arithmetic is
    # integer-preserving, so this comes back an int and lands on the same
    # croak. Fresh copies, because reading a UV as a float sets NOK on it.
    for my $spelling ('+ 0.0', '* 1.0') {
        my $copy = 12345678901234567890;
        my $still_int = $spelling eq '+ 0.0' ? $copy + 0.0 : $copy * 1.0;
        is(File::SOPS::Encrypted->detect_type($still_int), 'int',
            "\$value $spelling does NOT produce a float");
    }
}

{
    # Both answers through the real encrypt path, all four cells. The string
    # is written everywhere; the float is written everywhere except an
    # UNENCRYPTED YAML slot, where ADR 0013's guard refuses it because the
    # decimal the emitter has to write there is one yaml.v3 resolves as a
    # uint64. That cell is the whole reason the message hedges -- if it ever
    # stops refusing, the hedge needs re-reading, not deleting.
    for my $format (qw(yaml json)) {
        for my $key (qw(v v_unencrypted)) {
            my $as_string = '12345678901234567890';
            my $doc = eval {
                File::SOPS->encrypt(
                    data       => { $key => $as_string },
                    recipients => [$public],
                    format     => $format,
                );
            };
            ok($doc, "[$format/$key] the string answer is written")
                or diag("died: $@");

            my $as_float = unpack('d', pack('d', 12345678901234567890));
            my $float_doc = eval {
                File::SOPS->encrypt(
                    data       => { $key => $as_float },
                    recipients => [$public],
                    format     => $format,
                );
            };

            if ($format eq 'yaml' && $key eq 'v_unencrypted') {
                ok(!$float_doc,
                    "[$format/$key] the float answer is refused separately");
            }
            else {
                ok($float_doc, "[$format/$key] the float answer is written")
                    or diag("died: $@");
                like($float_doc, qr/type:float\]/,
                    "[$format/$key] as type:float")
                    if $float_doc && $key eq 'v';
            }
        }
    }
}

# ----------------------------------------------------------------------------
# 8. The refusal can only ever be about a POSITIVE value (k104).
#
#    SVf_IOK means the SV carries an IV or a UV. An IV bottoms out at exactly
#    int64min and a UV cannot be negative, so there is no integer SV below the
#    range and the negative half of the window does not exist -- which is the
#    premise ADR 0021's decision rests on and the one half k101's lanes
#    had not proved.
#
#    Measured for k104: 14 negative decimals bracketing int64min,
#    uint64max and beyond, through 13 construction routes each -- 182 rows, 36
#    of them `int`, not one of those below int64min, and zero croaks. A sample
#    of the routes is pinned here. Below the range a value arrives as a float
#    (ADR 0020) or a string, and neither rung refuses.
# ----------------------------------------------------------------------------

{
    my $below = '-9223372036854775809';       # int64min - 1, exactly

    my @routes = (
        [ 'a Perl literal'          => -9223372036854775809 ],
        [ 'int64min minus one'      => $INT64_MIN - 1 ],
        [ 'zero minus 2**64'        => 0 - 2**64 ],
        [ 'a numified string'       => 0 + $below ],
        [ 'a JSON number'           => decode_json(qq({"v":$below}))->{v} ],
        [ 'a YAML scalar'           => YAML::XS::Load("v: $below\n")->{v} ],
        [ 'a YAML quoted scalar'    => YAML::XS::Load("v: '$below'\n")->{v} ],
    );

    for my $route (@routes) {
        my ($what, $value) = @$route;
        isnt(File::SOPS::Encrypted->detect_type($value), 'int',
            "below int64min, $what is not an int -- no integer SV lives there");
        ok(eval { File::SOPS::Encrypted->assert_representable($value) },
            "... so the int64 refusal never fires for it");
    }

    # int64min itself is an int and in range, and the clamping spellings land
    # exactly on it rather than below it -- the other half of the same bound.
    is(File::SOPS::Encrypted->detect_type($INT64_MIN), 'int',
        'int64min itself is an int');
    is(File::SOPS::Encrypted->value_to_bytes(0 + sprintf('%d', -1e19)),
        '-9223372036854775808',
        'and a spelling that would go below it clamps onto it instead');
}

done_testing;

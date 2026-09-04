#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::SOPS;
use File::SOPS::Format::YAML;
use File::SOPS::Metadata;
use JSON::MaybeXS;
use Crypt::Age;

# ----------------------------------------------------------------------------
# Regressions for three wire-format bugs that were all invisible to the rest
# of the suite, because each one was self-consistent: File::SOPS produced a
# file that File::SOPS itself was happy with. Only the real `sops` binary
# disagreed -- and t/04-interop.t skips unless SOPS_BIN is set, so for two
# releases the suite reported "All tests successful" while Perl->sops was
# broken in every YAML case.
#
# Everything below therefore runs WITHOUT the sops binary, on purpose. These
# are the tests that had to fail when the binary was absent.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();

# ----------------------------------------------------------------------------
# 1. lastmodified must be emitted as a QUOTED YAML scalar.
#
# YAML::XS emits plain scalars for anything its resolver does not recognise.
# $YAML::XS::QuoteNumericStrings (on by default) already covers numbers,
# booleans and nulls, but the resolver has no notion of timestamps, so an
# RFC3339 lastmodified came out bare. Go's yaml.v3 resolves a bare RFC3339
# scalar to time.Time, and sops rejects the entire file before decrypting
# anything:
#
#   'lastmodified' expected type 'string', got unconvertible type 'time.Time'
#
# JSON is structurally immune (no timestamp type, strings always quoted),
# which is exactly why JSON interop passed while every YAML case failed.
# ----------------------------------------------------------------------------

{
    my $metadata = File::SOPS::Metadata->new;
    $metadata->lastmodified('2026-01-10T12:00:00Z');

    my $yaml = File::SOPS::Format::YAML->serialize(
        data     => { secret => 'ENC[AES256_GCM,data:x,iv:y,tag:z,type:str]' },
        metadata => $metadata,
    );

    like(
        $yaml,
        qr/^\s+lastmodified: "2026-01-10T12:00:00Z"$/m,
        'lastmodified is emitted as a quoted string (Go would type a bare '
            . 'RFC3339 scalar as time.Time and reject the file)'
    );

    unlike(
        $yaml,
        qr/^\s+lastmodified: 2026-01-10T12:00:00Z\s*$/m,
        'lastmodified is never emitted bare'
    );
}

# The quoting is a post-process on the dumped text, so it must be scoped to
# the sops block. A user key called "lastmodified" in the DATA section must
# not be rewritten -- that would corrupt user data.
{
    my $metadata = File::SOPS::Metadata->new;
    $metadata->lastmodified('2026-01-10T12:00:00Z');

    my $yaml = File::SOPS::Format::YAML->serialize(
        data => {
            lastmodified => 'user-owned-value',
            # sorts after "sops", so it also proves the sops block is
            # correctly closed at the next column-0 key
            zzz_after_sops => 'untouched',
        },
        metadata => $metadata,
    );

    like(
        $yaml,
        qr/^lastmodified: user-owned-value$/m,
        'a user data key named lastmodified is left alone (quoting is scoped '
            . 'to the sops block)'
    );

    like(
        $yaml,
        qr/^zzz_after_sops: untouched$/m,
        'data keys sorting after "sops" are left alone'
    );
}

# ----------------------------------------------------------------------------
# 2. A false boolean must be encrypted, not silently written as plaintext ''.
#
# JSON::PP::Boolean overloads eq, and JSON->false eq '' is TRUE -- even though
# the same object stringifies to '0'. _encrypt_tree's "SOPS doesn't encrypt
# empty values" guard therefore swallowed every false boolean and wrote it to
# the file as a bare '', in plaintext. _compute_mac had already hashed 'False'
# for that node, so the document then failed its OWN MAC check on the next
# read. sops encrypts false as type:bool with plaintext 'False'.
# ----------------------------------------------------------------------------

for my $format (qw(yaml json)) {
    my $encrypted = File::SOPS->encrypt(
        data       => { flag_false => JSON->false, flag_true => JSON->true },
        recipients => [$public],
        format     => $format,
    );

    unlike(
        $encrypted,
        qr/flag_false"?\s*:\s*(''|""|,|\s*$)/m,
        "[$format] false boolean is not written as an empty plaintext value"
    );

    like(
        $encrypted,
        qr/flag_false"?\s*:\s*"?ENC\[AES256_GCM,[^\]]*type:bool\]/,
        "[$format] false boolean is encrypted as type:bool"
    );

    # The real payoff: this is what actually broke. MAC verification of a
    # self-produced file failed whenever the document contained a false.
    my $decrypted = eval {
        File::SOPS->decrypt(
            encrypted  => $encrypted,
            identities => [$secret],
            format     => $format,
        );
    };
    is($@, '', "[$format] document containing a false boolean passes its own MAC");

    isa_ok($decrypted->{flag_false}, 'JSON::PP::Boolean',
        "[$format] decrypted false");
    ok(!$decrypted->{flag_false}, "[$format] false survives the round trip as false");
    ok($decrypted->{flag_true},   "[$format] true survives the round trip as true");
}

# Same bug, one level down: a false inside an array.
{
    my $encrypted = File::SOPS->encrypt(
        data       => { list => [ 'a', JSON->false, 'b' ] },
        recipients => [$public],
        format     => 'yaml',
    );

    my $decrypted = eval {
        File::SOPS->decrypt(
            encrypted => $encrypted, identities => [$secret], format => 'yaml',
        );
    };
    is($@, '', 'array containing a false boolean passes its own MAC');
    ok(!$decrypted->{list}[1], 'false inside an array survives as false');
}

# ----------------------------------------------------------------------------
# 3. Serializing a bool must not fall through to Perl truthiness.
#
# Both bool serializers ended in a bare Perl truthiness fallback:
#
#   ($value eq 'true' || $value eq '1' || $value) ? 'True' : 'False'
#
# The non-empty string 'false' is truthy in Perl, so it fell through to
# 'True'. The bug was present identically in BOTH twins (the one producing the
# ciphertext and the one producing the MAC digest input), which is precisely
# why it never showed up as a MAC failure: the ciphertext and the MAC were
# consistently wrong together. There is now one implementation --
# File::SOPS::Encrypted->value_to_bytes -- and File::SOPS::_value_to_bytes
# calls it, so the twins cannot drift.
#
# The rule only applies where a caller has forced type => 'bool' on a plain
# scalar, since that is the only route left by which a string reaches the
# boolean branch (see section 4).
# ----------------------------------------------------------------------------

{
    my $key = "\x01" x 32;

    my %expected = (
        'true'  => 'True',
        'false' => 'False',
        '1'     => 'True',
        '0'     => 'False',
        'True'  => 'True',
        'FALSE' => 'False',
    );

    for my $literal (sort keys %expected) {
        is(File::SOPS::Encrypted->value_to_bytes($literal, 'bool'),
            $expected{$literal},
            "forced type:bool serializes '$literal' as $expected{$literal}");

        my $enc = File::SOPS::Encrypted->encrypt_value(
            value => $literal, type => 'bool', key => $key, aad => 'a:',
        );
        my $back = $enc->decrypt_value(key => $key, aad => 'a:');
        is(!!$back, ($expected{$literal} eq 'True' ? 1 : ''),
            "forced type:bool round-trips '$literal' to $expected{$literal}");
    }
}

# ----------------------------------------------------------------------------
# 4. A value's type comes from the SCALAR, not from a pattern match on its
#    text (k15, ADR 0002).
#
# The old ladder read 'true'/'false' as booleans and /^-?\d+$/ as integers, so
# a quoted "false" in a document came back as a boolean and "007" as 7. sops
# 3.13.3, measured: bare false is type:bool, but "false", "true", "1", "0",
# "007" and "1.50" are ALL type:str, and their plaintext is the string
# verbatim. A bare number is stored in Go's canonical form instead -- 007 as
# 7, 1.50 as 1.5 -- which is what the reference re-derives when it recomputes
# the MAC, and therefore what a file has to contain for `sops -d` to accept
# it.
#
# t/04-interop.t proves this against the binary. This is the half that runs
# without one.
# ----------------------------------------------------------------------------

{
    my $key = "\x01" x 32;

    # [ value, expected type, expected plaintext, label ]
    my @cases = (
        [ 'false', 'str',   'false', 'quoted false'         ],
        [ 'true',  'str',   'true',  'quoted true'          ],
        [ '1',     'str',   '1',     'quoted one'           ],
        [ '0',     'str',   '0',     'quoted zero'          ],
        [ '007',   'str',   '007',   'zero-padded string'   ],
        [ '1.50',  'str',   '1.50',  'trailing-zero string' ],
        [ '1e20',  'str',   '1e20',  'exponent string'      ],
        [ 'yes',   'str',   'yes',   'YAML 1.1 truthy word' ],
        [ JSON->false, 'bool',  'False', 'bare false'       ],
        [ JSON->true,  'bool',  'True',  'bare true'        ],
        [ 1,       'int',   '1',     'bare integer'         ],
        [ 5432,    'int',   '5432',  'bare port number'     ],
        [ 1.50,    'float', '1.5',   'bare 1.50'            ],
        [ 1e20,    'float', '100000000000000000000', 'bare 1e20' ],
        [ 3.14159, 'float', '3.14159', 'bare pi'            ],
    );

    for my $case (@cases) {
        my ($value, $type, $plaintext, $label) = @$case;

        is(File::SOPS::Encrypted->detect_type($value), $type,
            "$label is type:$type");

        # The plaintext is what the ciphertext holds AND what the MAC digests,
        # so asserting it once covers both. Go re-derives exactly these bytes.
        is(File::SOPS::Encrypted->value_to_bytes($value), $plaintext,
            "$label serializes to '$plaintext'");

        my $enc = File::SOPS::Encrypted->encrypt_value(
            value => $value, key => $key, aad => 'a:',
        );
        is($enc->type, $type, "$label reaches the wire as type:$type");
        is($enc->decrypt_bytes(key => $key, aad => 'a:'), $plaintext,
            "$label authenticates '$plaintext'");
    }
}

# ----------------------------------------------------------------------------
# 5. value_to_bytes returns TEXT, and the scalar has to say so (k80).
#
# The shortest-form search in _float_bytes compared with `$g + 0 == $n`, which
# numifies $g IN PLACE -- the same in-place retyping k72 and k73 are
# about, on the OUTPUT side. So the digits came back carrying the double as
# well as the text, and detect_type, which reads the public SV flags and
# nothing else (ADR 0002), called value_to_bytes's own return a `float`. For a
# negative zero it called it an `int`, because the text `-0` numifies to an IV.
#
# Harmless where the return is used inside this distribution -- plaintext
# bytes, digest input, an `eq` in the round-trip checks, all string contexts,
# and the wire bytes are byte-identical either way (measured: 18216
# value_to_bytes rows and a 228-row emitter corpus, 0 differences). It bites
# the caller who sends a value through value_to_bytes and hands the result back
# to encrypt: they mean a string and would get a float, with a different type
# on the wire and a different digest.
#
# The assertion is on the TYPE of the return, not on its bytes, because the
# bytes were never wrong.
# ----------------------------------------------------------------------------

{
    my @cases = (
        [ 'float needing 17 digits', 0.1 + 0.2,  undef,   '0.30000000000000004' ],
        [ 'float 1.5',               1.5,        undef,   '1.5'                 ],
        [ 'float forced type',       1.5,        'float', '1.5'                 ],
        [ 'float 2.0',               2.0,        undef,   '2'                   ],
        [ 'negative zero',           -0.0,       undef,   '-0'                  ],
        [ 'float 1e20 (expanded)',   1e20,       undef,   '100000000000000000000' ],
        [ 'float 1e-7 (expanded)',   1e-7,       undef,   '0.0000001'           ],
        [ 'integer',                 5432,       undef,   '5432'                ],
        [ 'string',                  '007',      undef,   '007'                 ],
        [ 'boolean',                 JSON->true, undef,   'True'                ],
        [ 'forced bytes',            'raw',      'bytes', 'raw'                 ],
    );

    for my $case (@cases) {
        my ($label, $value, $type, $expected) = @$case;
        my $bytes = File::SOPS::Encrypted->value_to_bytes($value, $type);

        is($bytes, $expected, "[$label] value_to_bytes still writes '$expected'");
        is(File::SOPS::Encrypted->detect_type($bytes), 'str',
            "[$label] and returns it as a STRING, not as the number it spells");
    }

    # The caller path the ticket is about, end to end: a value that went
    # through value_to_bytes and came back must reach the wire as type:str.
    my $key   = "\x01" x 32;
    my $bytes = File::SOPS::Encrypted->value_to_bytes(0.1 + 0.2);
    my $enc   = File::SOPS::Encrypted->encrypt_value(
        value => $bytes, key => $key, aad => 'a:',
    );
    is($enc->type, 'str',
        'a value round-tripped through value_to_bytes encrypts as type:str');
    is($enc->decrypt_bytes(key => $key, aad => 'a:'), '0.30000000000000004',
        'and its plaintext is the digits verbatim');

    # And the source scalar is not retyped either -- the input side of the same
    # rule, which is what k72 and k73 fixed.
    my $float = 0.1 + 0.2;
    File::SOPS::Encrypted->value_to_bytes($float);
    is(File::SOPS::Encrypted->detect_type($float), 'float',
        "and the caller's own scalar is still a float afterwards");
}

# The round trip through the public API, which is what a caller sees change:
# a string that reads like something else stays that string.
for my $format (qw(yaml json)) {
    my %data = (
        s_true  => 'true',
        s_false => 'false',
        s_one   => '1',
        s_zero  => '0',
        s_pad   => '007',
        s_float => '1.50',
        n_int   => 5432,
        n_float => 1.50,
        b_true  => JSON->true,
        b_false => JSON->false,
    );

    my $encrypted = File::SOPS->encrypt(
        data => \%data, recipients => [$public], format => $format,
    );

    my $got = eval {
        File::SOPS->decrypt(
            encrypted => $encrypted, identities => [$secret], format => $format,
        );
    };
    is($@, '', "[$format] mixed string/number/boolean document passes its own MAC")
        or diag("died: $@");
    next unless $got;

    # is() compares with eq, so this is a genuine string assertion: under the
    # old ladder $got->{s_pad} was the integer 7 and would fail it.
    is($got->{$_}, $data{$_}, "[$format] $_ round-trips as the string '$data{$_}'")
        for qw(s_true s_false s_one s_zero s_pad s_float);

    ok(!ref $got->{s_true},  "[$format] the string 'true' is not a boolean");
    ok(!ref $got->{s_false}, "[$format] the string 'false' is not a boolean");
    isa_ok($got->{b_true},  'JSON::PP::Boolean', "[$format] a real true");
    isa_ok($got->{b_false}, 'JSON::PP::Boolean', "[$format] a real false");
    cmp_ok($got->{n_int},   '==', 5432, "[$format] a real integer stays numeric");
    cmp_ok($got->{n_float}, '==', 1.5,  "[$format] a real float stays numeric");
}

# Reading the type off the scalar only works if nothing on the way to the
# cipher changes it. Perl marks a string as numeric IN PLACE the moment it is
# used in numeric context, and encrypt walks the caller's structure twice --
# once for the MAC and once to encrypt -- so a numification anywhere in the
# first walk would silently retype the document during the second, and the
# caller's own data with it.
{
    my %data = (s => '5432', n => 5432, s_float => '1.50');

    my @wire;
    for my $pass (1, 2) {
        my $encrypted = File::SOPS->encrypt(
            data => \%data, recipients => [$public], format => 'yaml',
        );
        push @wire, [ $encrypted =~ /^(\w+): ENC\[[^\]]*(type:\w+)\]$/mg ];
    }

    is_deeply($wire[1], $wire[0], 'encrypting the same structure twice gives the same types');
    is_deeply(
        { @{ $wire[0] } },
        { s => 'type:str', n => 'type:int', s_float => 'type:str' },
        'and they are the types the scalars started with',
    );

    is(File::SOPS::Encrypted->detect_type($data{s}), 'str',
        "encrypt leaves the caller's string a string");
    is($data{s}, '5432', "and does not change the caller's value");
}

done_testing;

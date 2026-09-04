#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::Temp qw(tempdir);
use YAML::XS ();
use JSON::MaybeXS;
use Crypt::Age;
use Crypt::AuthEnc::GCM qw(gcm_decrypt_verify);

use File::SOPS;
use File::SOPS::Encrypted;
use File::SOPS::Backend::Age;
use File::SOPS::Format::YAML;

# ----------------------------------------------------------------------------
# Regressions for the two character-encoding defects (k26, k12).
#
# Both were invisible to the rest of the suite for the same reason: every
# assertion in it is ASCII, and in ASCII a character string and its UTF-8
# encoding are the same bytes. The moment a key or a value leaves ASCII the two
# rules this file pins come apart:
#
#   k26  The AAD reaching AES-GCM must be UTF-8 bytes, because that is what the
#        Go implementation authenticates against. It used to be handed over as a
#        character string, which CryptX either downgraded to Latin-1 (U+0080 to
#        U+00FF -- a file that looks right and authenticates against nothing) or
#        refused outright with "Wide character in subroutine entry" (above
#        U+00FF). Both directions were affected, including the MAC, which
#        re-derives the same AAD to hash each value's plaintext.
#
#   k12  The API boundary is characters. decrypt used to return the UTF-8 bytes
#        straight off the cipher, so a decrypted structure compared unequal to
#        the one that was encrypted, and decrypt_file encoded those bytes a
#        second time and wrote mojibake.
#
# Nothing here shells out. The fixture in section 1 is a real document written
# by sops 3.13.3, checked in with its (throwaway) age identity, so the read
# direction is pinned against the reference implementation without needing the
# binary present -- which is the whole point, since t/04-interop.t skips when it
# is not. The codepoints are written as \x{} escapes rather than literal UTF-8
# so that the test states them exactly and does not depend on how this file is
# itself decoded.
# ----------------------------------------------------------------------------

# A \x{} escape below U+0100 leaves Perl free to store the string as single
# bytes with the UTF-8 flag off, which is byte-for-byte indistinguishable from a
# caller who really did pass bytes. Everything below is meant as CHARACTERS, so
# say so once, here, rather than depending on how Perl chose to hold a literal.
# (For anything above U+00FF the flag is always on and this is a no-op.)
sub chars { my ($s) = @_; utf8::upgrade($s); return $s }

my $K_LATIN1 = chars("caf\x{e9}");         # café  -- was silently encoded as Latin-1
my $K_WIDE   = "\x{30ad}\x{30fc}";         # キー   -- was fatal, above U+00FF
my $K_PASSW  = chars("passw\x{f6}rd");
my $V_UMLAUT = chars("h\x{e4}mlich");
my $V_OFFEN  = chars("\x{f6}ffentlich");   # unencrypted, but still hashed into the MAC
my $V_CJK    = "\x{5024}";
my $V_EMOJI  = "\x{1f510}ok";              # outside the BMP

# ----------------------------------------------------------------------------
# 1. A real sops 3.13.3 document whose keys leave ASCII.
#
# This is the ground truth for k26: the AAD sops used for the value below is
# "caf\xc3\xa9:passw\xc3\xb6rd:" -- UTF-8, not Latin-1 and not a Perl character
# string. Before the fix this died in the U+30AD branch and failed
# authentication in the café branch.
#
# It also covers the read side of k12: the values must come back as characters,
# and "notiz_unencrypted" exercises a non-ASCII value that is hashed into the
# MAC without being encrypted, so the digest and the AAD are both under test.
# ----------------------------------------------------------------------------

my $SOPS_IDENTITY =
    'AGE-SECRET-KEY-1SU0PVPYT46DZXY67SYTYRCPN95D4VSL9EFF6LJ3TQ6APL7WL2HGQYF0LZV';

my $SOPS_FIXTURE = <<'YAML';
café:
    passwörd: ENC[AES256_GCM,data:eIYc2cwPv0E=,iv:JLLV+z1GQtCSTkaYsUUt4yJZD63wbfvKx6HbGRNQdn4=,tag:oG/xfbEDRLpbgWt/WG+98g==,type:str]
    notiz_unencrypted: öffentlich
キー:
    value: ENC[AES256_GCM,data:PXgm,iv:pkzxWR7YtRiWWyOhZZquCYYh9R5gZzXPKlmNsltmAVM=,tag:y3X7HdQlbWJUEVywTDGlwA==,type:str]
    "n": ENC[AES256_GCM,data:2CA=,iv:JTux29FVhMRWN0XvZCzqwmsCVvzs89QCORHCZJ1IwYk=,tag:upJhbV9UloaFesOluCU0rQ==,type:int]
ascii:
    plain: ENC[AES256_GCM,data:moKf/QI=,iv:AbrnGcKxLs8h4EfEdgyIHznlZRTro5nXRkOrB2d4Y44=,tag:ksWaxRO/dZ2fSw1UIoE72w==,type:str]
sops:
    age:
        - enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSA5T0dSRE5VVHVFU0IrZTFj
            OThwdFR4TkJyUjJuY1ExWTRIS24wSkFhZndJCmZIWVFQVkk0NlA3cmNUTVl6Q3F5
            VVVNT2VxYXh3TDNEMnpncWVVcnNnR2sKLS0tIGdINDlqWkE2eFhzdFBwcHdHS1JJ
            S0lwUWpzSG03UU4yc0QySVE2Y2Zod1UKAmfGsJLjDRi/ZWhBGhBw8Tol7XHjgQQx
            /d8Hvqfh188dnCUw8zSz4a/TVINHbNJLIJXAaJ1/Gg7QwRLDUeKK0g==
            -----END AGE ENCRYPTED FILE-----
          recipient: age1e2xuas0wksl0zu40m4wdzvltznqestr34kuua82v5gqzgzhsaqhq067evm
    lastmodified: "2026-08-08T22:25:11Z"
    mac: ENC[AES256_GCM,data:Z2f3wuWLGT/390WnM/TuocoDlUBIcU6LmBknyoIKyAOj9nvY7UFXItr+7WbUL9TO3SWOsImJ+Jm03ZdZxzb+DXBRnWbnwY5SiGYSfQwCM/pL35Z7LBNr+TVzSTg8xDAGS4bD5Pz/L2YEb0XGncnsdkMNxS0X9uY9i52Gt0hwS4k=,iv:H6ETwBMiYqgBdkt5oLnbxvH8g4l4/QMuwI9A5vVRYZA=,tag:iQtSslWK8D3OXQbP3N3aYA==,type:str]
    unencrypted_suffix: _unencrypted
    version: 3.13.3
YAML

subtest 'sops-written document with non-ASCII keys (k26 read side)' => sub {
    my $got = eval {
        File::SOPS->decrypt(
            encrypted  => $SOPS_FIXTURE,
            identities => [$SOPS_IDENTITY],
        );
    };

    ok(defined $got, 'decrypts, MAC included')
        or do { diag("died: $@"); return };

    is_deeply(
        $got,
        {
            $K_LATIN1 => {
                $K_PASSW            => $V_UMLAUT,
                'notiz_unencrypted' => $V_OFFEN,
            },
            $K_WIDE => { value => $V_CJK, n => 42 },
            ascii   => { plain => 'hello' },
        },
        'values come back as characters under keys that are not ASCII',
    );

    ok(utf8::is_utf8($got->{$K_LATIN1}{$K_PASSW}),
        'decrypted non-ASCII value is a character string, not UTF-8 bytes');
};

# ----------------------------------------------------------------------------
# 2. The AAD we WRITE is UTF-8 (k26 write side), asserted without sops.
#
# The document is encrypted through the public API, then the ENC value under a
# non-ASCII path is re-authenticated by hand under each candidate AAD encoding.
# Exactly one of them may work, and it has to be the UTF-8 one -- section 1
# establishes that as what sops uses.
# ----------------------------------------------------------------------------

subtest 'AAD written for a non-ASCII path is UTF-8 (k26 write side)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();

    my $doc = eval {
        File::SOPS->encrypt(
            data       => { $K_LATIN1 => { $K_PASSW => $V_UMLAUT } },
            recipients => [$public],
            format     => 'yaml',
        );
    };
    ok(defined $doc, 'encrypting under a Latin-1-range key succeeds')
        or do { diag("died: $@"); return };

    # The emitter's own encoding of the key, which is what the AAD has to agree
    # with. Note \Q..\E is no use here: it suppresses the \x escapes.
    my $key_on_the_wire = "caf\xc3\xa9:";
    like($doc, qr/\Q$key_on_the_wire\E/,
        'the key itself is written to the document as UTF-8');

    my ($data, $metadata) = File::SOPS::Format::YAML->parse($doc);
    my $data_key = File::SOPS::Backend::Age->decrypt_data_key(
        age_keys   => $metadata->age,
        identities => [$secret],
    );

    my $enc = File::SOPS::Encrypted->parse($data->{$K_LATIN1}{$K_PASSW});
    ok($enc, 'value was encrypted');

    # Straight at the GCM primitive, deliberately bypassing decrypt_bytes: the
    # claim under test is which BYTES were authenticated, and decrypt_bytes
    # takes characters and does the encoding itself, so asking it would only
    # confirm that it agrees with its own twin. sops has nothing but these
    # bytes.
    is(
        gcm_decrypt_verify('AES', $data_key, $enc->iv,
            "caf\xc3\xa9:passw\xc3\xb6rd:", $enc->data, $enc->tag),
        "h\xc3\xa4mlich",
        'the AAD on the wire is UTF-8, and so is the plaintext',
    );

    is(
        gcm_decrypt_verify('AES', $data_key, $enc->iv,
            "caf\xe9:passw\xf6rd:", $enc->data, $enc->tag),
        undef,
        'and it is not Latin-1',
    );
};

# ----------------------------------------------------------------------------
# The AAD rule has to be UNCONDITIONAL, not "encode if the scalar carries the
# UTF-8 flag", and this is the case that shows why.
#
# For a key whose characters are all below U+0100 that flag is an internal
# storage detail: "caf\x{e9}" may be held as one byte or as two, and Perl
# considers both the same string. The emitters do not care either -- YAML::XS
# and JSON::MaybeXS write the key as UTF-8 both ways. So a flag-guarded AAD
# authenticated an unflagged key against caf\xe9: while the emitter wrote
# caf\xc3\xa9, and the very next read of our OWN document re-derived the UTF-8
# form and failed the MAC. sops rejected it for the same reason.
# ----------------------------------------------------------------------------

subtest 'AAD does not depend on Perl\'s internal string representation (k26)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();

    my $downgraded = "caf\x{e9}";
    utf8::downgrade($downgraded);
    ok(!utf8::is_utf8($downgraded), 'the key is held as bytes, flag off');
    ok(utf8::is_utf8($K_LATIN1),    'and the same key is also available flagged');
    is($downgraded, $K_LATIN1,      'Perl considers the two the same string');

    my %doc;
    for my $case (['downgraded', $downgraded], ['upgraded', $K_LATIN1]) {
        my ($name, $key) = @$case;

        $doc{$name} = File::SOPS->encrypt(
            data       => { $key => 'secret' },
            recipients => [$public],
            format     => 'yaml',
        );

        # The whole point: this must verify, and it is our own output.
        my $got = eval {
            File::SOPS->decrypt(encrypted => $doc{$name}, identities => [$secret]);
        };
        is_deeply($got, { $K_LATIN1 => 'secret' },
            "$name: our own document verifies and round-trips")
            or diag("died: $@");
    }
};

subtest 'a key above U+00FF no longer kills the encoder (k26)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();

    my $data = { $K_WIDE => { $K_WIDE => $V_CJK } };
    my $doc  = eval {
        File::SOPS->encrypt(
            data       => $data,
            recipients => [$public],
            format     => 'yaml',
        );
    };

    ok(defined $doc, 'no "Wide character in subroutine entry"')
        or do { diag("died: $@"); return };

    is_deeply(
        File::SOPS->decrypt(encrypted => $doc, identities => [$secret]),
        $data,
        'and the document verifies and round-trips',
    );
};

# ----------------------------------------------------------------------------
# 3. The boundary rule (k12): what goes in as characters comes back as
#    characters, through every entry point.
# ----------------------------------------------------------------------------

subtest 'encrypt/decrypt is an identity for non-ASCII (k12)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();

    my $data = {
        greeting => chars("gr\x{fc}\x{df}e"),
        cjk      => $V_CJK,
        emoji    => $V_EMOJI,
        nested   => { $K_LATIN1 => $V_UMLAUT },
        ascii    => 'plain',
        number   => 42,
    };

    for my $format (qw(yaml json)) {
        my $doc = File::SOPS->encrypt(
            data       => $data,
            recipients => [$public],
            format     => $format,
        );
        my $got = File::SOPS->decrypt(
            encrypted  => $doc,
            identities => [$secret],
        );
        is_deeply($got, $data, "$format: decrypted structure equals the original");
    }
};

subtest 'decrypt_file does not double-encode (k12)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();
    my $dir = tempdir(CLEANUP => 1);

    my $data = { greeting => chars("gr\x{fc}\x{df}e"), nested => { $K_LATIN1 => $V_CJK } };

    for my $format (qw(yaml json)) {
        my $enc_file = "$dir/secrets.$format";
        my $out_file = "$dir/plain.$format";

        open my $fh, '>:raw', $enc_file or die $!;
        print $fh File::SOPS->encrypt(
            data       => $data,
            recipients => [$public],
            format     => $format,
        );
        close $fh;

        File::SOPS->decrypt_file(
            input      => $enc_file,
            output     => $out_file,
            identities => [$secret],
        );

        open my $in, '<:raw', $out_file or die $!;
        my $bytes = do { local $/; <$in> };
        close $in;

        # "gr\xc3\xbc\xc3\x9fe" is UTF-8 for grüße. The double-encoded form the
        # bug produced is "gr\xc3\x83\xc2\xbc..." -- the leading \xc3\x83 is the
        # signature, and it must not appear.
        unlike($bytes, qr/\xc3\x83/,
            "$format: no double-encoded UTF-8 in the decrypted file");

        my $back = $format eq 'json'
            ? JSON::MaybeXS->new(utf8 => 1)->decode($bytes)
            : YAML::XS::Load($bytes);
        is_deeply($back, $data, "$format: file round-trips to the original characters");
    }
};

subtest 'extract returns characters and takes a character path (k12)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();
    my $dir = tempdir(CLEANUP => 1);

    my $file = "$dir/secrets.yaml";
    open my $fh, '>:raw', $file or die $!;
    print $fh File::SOPS->encrypt(
        data       => { $K_LATIN1 => { $K_WIDE => $V_UMLAUT } },
        recipients => [$public],
        format     => 'yaml',
    );
    close $fh;

    my $got = File::SOPS->extract(
        file       => $file,
        path       => "[\"$K_LATIN1\"][\"$K_WIDE\"]",
        identities => [$secret],
    );

    is($got, $V_UMLAUT, 'extracted value is the character string that went in');
    ok(utf8::is_utf8($got), 'and it carries the UTF-8 flag, i.e. it is not bytes');
};

# ----------------------------------------------------------------------------
# 4. The value conversion is UNCONDITIONAL, exactly like the AAD (k27,
#    ADR 0003).
#
# The value used to be encoded only when the scalar carried Perl's UTF-8 flag.
# Below U+0100 that flag is storage, not meaning: "caf\x{e9}" may be held as
# one byte or as two and Perl considers both the same string. The emitters do
# not consult it -- YAML::XS::Dump and JSON::MaybeXS(utf8 => 1) write café as
# caf\xc3\xa9 either way -- so a flag-guarded value conversion disagreed with
# the bytes our own emitter wrote, which is the same defect the AAD had.
#
# Two measured consequences, both reproduced below:
#
#   * An UNENCRYPTED value (unencrypted_suffix, on by default) went into the
#     document as UTF-8 and into the digest as Latin-1, so the document failed
#     its OWN MAC. No configuration needed.
#   * An ENCRYPTED value was self-consistent but reached the wire as Latin-1.
#     sops cannot read that as text: it hands back `!!binary Y2Fm6Q==` instead
#     of café. t/04-interop.t pins that half against the real binary.
# ----------------------------------------------------------------------------

# The same string in both of Perl's storage forms. These are EQUAL as far as
# Perl is concerned, so anything that writes different bytes for them is
# letting an implementation detail reach the wire format.
my $V_CAFE_UP   = do { my $s = "caf\x{e9}"; utf8::upgrade($s);   $s };
my $V_CAFE_DOWN = do { my $s = "caf\x{e9}"; utf8::downgrade($s); $s };

subtest 'the value on the wire does not depend on Perl\'s string storage (k27)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();

    ok(utf8::is_utf8($V_CAFE_UP),   'one copy carries the UTF-8 flag');
    ok(!utf8::is_utf8($V_CAFE_DOWN), 'the other does not');
    is($V_CAFE_UP, $V_CAFE_DOWN,    'and Perl considers them the same string');

    my %plaintext;
    for my $case (['flagged', $V_CAFE_UP], ['unflagged', $V_CAFE_DOWN]) {
        my ($name, $value) = @$case;

        my $doc = File::SOPS->encrypt(
            data       => { greeting => $value },
            recipients => [$public],
            format     => 'yaml',
        );
        my ($data, $metadata) = File::SOPS::Format::YAML->parse($doc);
        my $data_key = File::SOPS::Backend::Age->decrypt_data_key(
            age_keys   => $metadata->age,
            identities => [$secret],
        );
        $plaintext{$name} = File::SOPS::Encrypted->parse($data->{greeting})
            ->decrypt_bytes(key => $data_key, aad => 'greeting:');
    }

    # This is the assertion the old flag-guarded rule failed: it wrote
    # "caf\xe9" for the unflagged copy, which is not what any emitter, any
    # AAD, or sops understands café to be.
    is($plaintext{flagged}, "caf\xc3\xa9",
        'a flagged Latin-1-range value is written to the wire as UTF-8');
    is($plaintext{unflagged}, $plaintext{flagged},
        'and an unflagged one produces the SAME wire bytes');
};

subtest 'an unencrypted Latin-1-range value passes its own MAC (k27)' => sub {
    # The zero-configuration case. unencrypted_suffix defaults to
    # _unencrypted, so this value is written into the document by the emitter
    # AND hashed into the digest -- the two have to agree on its bytes.
    my ($public, $secret) = Crypt::Age->generate_keypair();

    for my $case (['flagged', $V_CAFE_UP], ['unflagged', $V_CAFE_DOWN]) {
        my ($name, $value) = @$case;

        my $doc = File::SOPS->encrypt(
            data       => { note_unencrypted => $value, s => 'x' },
            recipients => [$public],
            format     => 'yaml',
        );

        # What the emitter actually wrote, stated as bytes rather than as a
        # string, because the whole bug lives in the difference.
        like($doc, qr/^note_unencrypted: caf\xc3\xa9$/m,
            "$name: the emitter writes the unencrypted value as UTF-8");

        my $got = eval {
            File::SOPS->decrypt(encrypted => $doc, identities => [$secret]);
        };
        is($@, '', "$name: our own document passes its own MAC")
            or diag("died: $@");
        is($got->{note_unencrypted}, $V_CAFE_UP,
            "$name: and the value comes back") if $got;
    }
};

subtest 'the same holds for JSON, and for a whole-document round trip (k27)' => sub {
    my ($public, $secret) = Crypt::Age->generate_keypair();

    my $data = {
        enc_unflagged   => $V_CAFE_DOWN,
        note_unencrypted => $V_CAFE_DOWN,
        wide            => $K_WIDE,
    };

    for my $format (qw(yaml json)) {
        my $doc = File::SOPS->encrypt(
            data => $data, recipients => [$public], format => $format,
        );
        my $got = eval {
            File::SOPS->decrypt(encrypted => $doc, identities => [$secret]);
        };
        is($@, '', "[$format] document of unflagged Latin-1-range values verifies")
            or diag("died: $@");
        is_deeply($got, { %$data, enc_unflagged => $V_CAFE_UP,
                          note_unencrypted => $V_CAFE_UP },
            "[$format] and round-trips to the same characters") if $got;
    }
};

subtest 'type:bytes is neither encoded nor decoded (k27 escape hatch)' => sub {
    my $key = "\x00" x 32;

    # 0x80 alone is not valid UTF-8, so a decode attempt would either mangle it
    # or leave it -- either way the point is that nothing tries.
    my $binary = "\x89PNG\x0d\x0a\x1a\x0a\x80\xff";

    # The ENCODE side, which is what makes this an escape hatch rather than an
    # accident. Everything else is UTF-8 encoded unconditionally now, so
    # asserting the round trip alone would pass under either rule -- the claim
    # is about the bytes that reach the cipher.
    is(File::SOPS::Encrypted->value_to_bytes($binary, 'bytes'), $binary,
        'type:bytes reaches the cipher byte-for-byte');
    isnt(File::SOPS::Encrypted->value_to_bytes($binary, 'str'), $binary,
        'while the same scalar as type:str is encoded (the contrast that '
            . 'proves the exemption is real)');

    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => $binary,
        key   => $key,
        aad   => 'blob:',
        type  => 'bytes',
    );

    is($enc->decrypt_bytes(key => $key, aad => 'blob:'), $binary,
        'and the authenticated plaintext is the input, unencoded');

    my $got = $enc->decrypt_value(key => $key, aad => 'blob:');
    is($got, $binary, 'binary type comes back byte-for-byte');
    ok(!utf8::is_utf8($got), 'and is not upgraded to characters');
};

done_testing;

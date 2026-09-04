#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::SOPS;
use File::SOPS::Encrypted;
use File::SOPS::Backend::Age;
use Crypt::Age;
use Crypt::PRNG ();
use MIME::Base64 qw(decode_base64);

# ----------------------------------------------------------------------------
# The CSPRNG's return length is checked where the bytes are obtained, because
# there is nowhere downstream that can check it.
#
# _random_bytes used to exist twice -- once in File::SOPS::Encrypted for the
# per-value GCM nonce, once in File::SOPS for the data key -- byte-identical
# apart from a line wrap, and both ended in an unchecked
#
#     read $fh, $bytes, $length;
#
# from /dev/urandom. read() can return short and returns undef on error, so
# either copy could hand back a key or a nonce of the wrong length with no
# error raised. What made that a cryptographic defect rather than a style
# complaint is that a wrong length is accepted everywhere it then goes.
# Measured against CryptX 0.087 and sops 3.13.3, encrypting a document with a
# truncated data key and a truncated IV and then running the real binary
# over it:
#
#   data key -> 16 bytes   iv written 32   our decrypt OK   `sops -d` exit 0
#   data key -> 24 bytes   iv written 32   our decrypt OK   `sops -d` exit 0
#   iv       -> 12 bytes   iv written 12   our decrypt OK   `sops -d` exit 0
#   iv       ->  1 byte    iv written  1   our decrypt OK   `sops -d` exit 0
#
# Not one of those is an error to any part of the system. The 16-byte data key
# is a working AES-128 key; a 1-byte nonce is a working GCM nonce out of a
# 256-value space, which repeats under one data key within a few hundred
# values. Only a data key that is not 16/24/32 bytes and a 0-byte IV fail at
# all, and they fail as "FATAL: ccm_memory failed: Invalid key size" from
# inside CryptX, attributed to the gcm call and naming neither the CSPRNG nor
# which of the two values was short.
#
# So these tests do not check that 32 bytes come back -- that assertion cannot
# fail. They replace the source with one that returns the wrong number of
# bytes, and require that the wrong number is refused before it reaches a key
# or a nonce.
# ----------------------------------------------------------------------------

my $real_random_bytes = \&Crypt::PRNG::random_bytes;

# An override that truncates every call to $len bytes.
sub always_short {
    my ($len) = @_;
    return sub {
        my ($n) = @_;
        return substr($real_random_bytes->($n), 0, $len);
    };
}

# An override that truncates only the $nth call, so a single value inside a
# larger operation can be targeted. File::SOPS::encrypt takes the data key
# before it touches age, so call 1 is always the data key.
sub short_on_call {
    my ($nth, $len) = @_;
    my $calls = 0;
    return sub {
        my ($n) = @_;
        my $bytes = $real_random_bytes->($n);
        $calls++;
        return $calls == $nth ? substr($bytes, 0, $len) : $bytes;
    };
}

my ($public, $secret) = Crypt::Age->generate_keypair();

sub encrypt_a_document {
    return File::SOPS->encrypt(
        data       => { password => 'plaintext-that-must-not-be-written' },
        recipients => [$public],
        format     => 'yaml',
    );
}

subtest 'one _random_bytes, not two' => sub {
    ok defined &File::SOPS::Encrypted::_random_bytes,
        'File::SOPS::Encrypted::_random_bytes is the shared helper';
    ok !defined &File::SOPS::_random_bytes,
        'File::SOPS has no second copy of it';
};

subtest 'a short return is refused at the source' => sub {
    for my $len (0, 1, 12, 16, 24, 31) {
        no warnings 'redefine';
        local *Crypt::PRNG::random_bytes = always_short($len);

        my $bytes = eval { File::SOPS::Encrypted::_random_bytes(32) };
        my $err   = $@;
        is $bytes, undef, "_random_bytes(32) returns nothing for a $len-byte source";
        like $err, qr/random_bytes/,
            "  ... and says where the short return came from ($len bytes)";
        like $err, qr/\b$len bytes\b/, "  ... naming the length it got ($len)";
    }
};

subtest 'an undef return is refused too' => sub {
    no warnings 'redefine';
    local *Crypt::PRNG::random_bytes = sub { return undef };

    my $bytes = eval { File::SOPS::Encrypted::_random_bytes(32) };
    my $err   = $@;
    is $bytes, undef, '_random_bytes(32) returns nothing when the source fails';
    like $err, qr/undef/, '... and says the source returned undef';
};

subtest 'a short data key never reaches a document' => sub {
    # 16 and 24 are the dangerous lengths: they are valid AES key sizes, so
    # every check that exists downstream -- CryptX, our own decrypt, and the
    # sops binary -- passes on them. Before this check, each of these produced
    # a complete, valid, sops-readable document under a weakened key.
    for my $len (16, 24) {
        no warnings 'redefine';
        local *Crypt::PRNG::random_bytes = short_on_call(1, $len);

        my $doc = eval { encrypt_a_document() };
        my $err = $@;
        is $doc, undef, "encrypt produces no document for a $len-byte data key";
        like $err, qr/random_bytes/, "... and blames the CSPRNG, not the gcm call ($len)";
    }

    # 20 already died before this change, but inside CryptX and as "Invalid
    # key size" attributed to gcm_encrypt_authenticate. The claim here is not
    # that it dies, it is that it dies naming the short return.
    {
        no warnings 'redefine';
        local *Crypt::PRNG::random_bytes = short_on_call(1, 20);

        my $doc = eval { encrypt_a_document() };
        my $err = $@;
        is $doc, undef, 'encrypt produces no document for a 20-byte data key';
        like $err, qr/random_bytes/,
            '... and reports the short return rather than CryptX key-size';
    }
};

subtest 'a short IV never reaches a value' => sub {
    # GCM takes any nonce length, so nothing below encrypt_value can object.
    for my $len (1, 12, 31) {
        no warnings 'redefine';
        local *Crypt::PRNG::random_bytes = always_short($len);

        my $enc = eval {
            File::SOPS::Encrypted->encrypt_value(
                value => 'secret',
                key   => 'k' x 32,
                aad   => 'database:password:',
            );
        };
        my $err = $@;
        is $enc, undef, "encrypt_value produces no value for a $len-byte IV";
        like $err, qr/random_bytes/, "... and blames the CSPRNG ($len)";
    }
};

subtest 'the refusal does not leak the bytes it refused' => sub {
    my $marker = 'CANARY0123456789';   # 16 bytes, as a short data key would be
    no warnings 'redefine';
    local *Crypt::PRNG::random_bytes = sub { return $marker };

    my $doc = eval { encrypt_a_document() };
    my $err = $@;
    is $doc, undef, 'encrypt refused';
    unlike $err, qr/\QCANARY\E/,
        'the error carries lengths, not key material';
};

subtest 'the checked helper still produces what the wire format needs' => sub {
    # An anchor, not the point of this file: these two lengths are fixed by
    # the reference implementation, not chosen here. sops 3.13.3 writes a
    # 32-byte iv and a 16-byte tag for every value.
    is length(File::SOPS::Encrypted::_random_bytes(32)), 32,
        '_random_bytes(32) is 32 bytes';

    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => 'secret',
        key   => 'k' x 32,
        aad   => 'database:password:',
    );
    is length($enc->iv), 32, 'the IV on an encrypted value is 32 bytes';
    is length($enc->tag), 16, 'the GCM tag is 16 bytes';

    my $doc = encrypt_a_document();
    my ($iv) = $doc =~ /ENC\[AES256_GCM,data:[^,]+,iv:([^,]+),/;
    ok defined $iv, 'a full encrypt writes an encrypted value';
    is length(decode_base64($iv)), 32, 'and its iv is 32 bytes on the wire';

    is_deeply(
        File::SOPS->decrypt(encrypted => $doc, identities => [$secret]),
        { password => 'plaintext-that-must-not-be-written' },
        'the document round-trips',
    );
};

# ----------------------------------------------------------------------------
# Crypt::Age's own CSPRNG calls (file key, nonce, ephemeral key) live inside
# Crypt::Age and we cannot see them from here -- k52 notes this is fixed
# upstream, not here. What we *can* check is the one byte sequence Crypt::Age
# hands back across our boundary: the data key itself, in decrypt_data_key.
# A 16-byte (AES-128) or 24-byte (AES-192) data key is silently accepted by
# CryptX; a 32-byte one is AES-256 and the only length the reference impl
# generates. This is the same defect class as the data-key / IV checks above.
# ----------------------------------------------------------------------------

subtest 'a wrong-length data key from Crypt::Age is refused' => sub {
    # Encrypt a real document so we have an age stanza to feed back in.
    my $doc = encrypt_a_document();

    # Recover the armored age stanza from the document and feed it back to
    # decrypt_data_key under a mocked Crypt::Age::decrypt. The mock returns
    # exactly the requested length, bypassing the real ChaCha20-Poly1305 path.
    my ($armored) = $doc =~ /(-----BEGIN AGE ENCRYPTED FILE-----.*?-----END AGE ENCRYPTED FILE-----)/s;
    ok defined $armored, 'extracted an armored age stanza from the document';
    my $fake_age_keys = [{ recipient => $public, enc => $armored }];

    # The dangerous lengths are 16 and 24: both are valid AES key sizes, so
    # CryptX accepts them and the document encrypts under a weakened key.
    # 31 and 33 fail inside CryptX as "Invalid key size", unattributed.
    for my $len (16, 24, 31, 33, 40) {
        no warnings 'redefine';
        local *Crypt::Age::decrypt = sub { return 'K' x $len };

        my $dk = eval {
            File::SOPS::Backend::Age->decrypt_data_key(
                age_keys   => $fake_age_keys,
                identities => [$secret],
            );
        };
        my $err = $@;
        is $dk, undef, "decrypt_data_key refuses a $len-byte data key";
        like $err, qr/data key of \Q$len\E bytes/,
            "  ... and names the length it received ($len)";
        like $err, qr/expected 32/,
            '  ... and names the length it expected';
    }
};

subtest 'the refusal does not leak the (mocked) data key bytes' => sub {
    my $doc = encrypt_a_document();
    my ($armored) = $doc =~ /(-----BEGIN AGE ENCRYPTED FILE-----.*?-----END AGE ENCRYPTED FILE-----)/s;
    my $fake_age_keys = [{ recipient => $public, enc => $armored }];

    # Use a distinctive fill that no real data key would contain.
    no warnings 'redefine';
    local *Crypt::Age::decrypt = sub { return 'CANARYCANARYCANARYCANARY' };  # 24 bytes

    my $dk = eval {
        File::SOPS::Backend::Age->decrypt_data_key(
            age_keys   => $fake_age_keys,
            identities => [$secret],
        );
    };
    my $err = $@;
    is $dk, undef, 'decrypt_data_key refuses the canary-length key';
    unlike $err, qr/CANARY/,
        '  ... and the error carries lengths, not key material';
};

subtest 'a 32-byte data key from Crypt::Age is accepted' => sub {
    # Round-trip with a normal Crypt::Age to confirm the check accepts the
    # length it actually produces in the wild. If Crypt::Age ever changes
    # its data-key length, this test goes red and points here.
    my $doc = encrypt_a_document();

    my $plaintext = File::SOPS->decrypt(
        encrypted  => $doc,
        identities => [$secret],
    );
    is_deeply $plaintext, { password => 'plaintext-that-must-not-be-written' },
        'a real decrypt round-trips with a 32-byte data key';
};

done_testing;

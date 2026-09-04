#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use File::SOPS;
use File::SOPS::Format::YAML;
use File::SOPS::Format::JSON;
use Crypt::Age;

# ----------------------------------------------------------------------------
# The top-level `sops` key is RESERVED (k18).
#
# Two failures that looked unrelated are one rule in the reference
# implementation. Measured against sops 3.13.3, all three of these are refused
# identically -- exit code 203, before anything is encrypted:
#
#   * `sops -e` on a plaintext file containing a top-level `sops:` entry
#   * `sops -e` on a file that is already encrypted
#   * `sops -e -i` on a file that is already encrypted
#
#   The file you have provided contains a top-level entry called 'sops', or for
#   flat file formats top-level entries starting with 'sops_'. This is
#   generally due to the file already being encrypted. SOPS uses a top-level
#   entry called 'sops' to store the metadata required to decrypt the file. For
#   this reason, SOPS can not encrypt files that already contain such an entry.
#
# File::SOPS did neither check, and both failures were silent:
#
#   * serialize assigns the metadata into `sops` unconditionally, so a user
#     value under that name was overwritten by the metadata section. The
#     digest, computed before serialization, covered the user's value -- so the
#     document that came out failed its own MAC on the very next read.
#   * encrypt_file parses the input first, and parse SPLITS OFF the sops
#     section. So an already-encrypted file arrived at encrypt as a plain tree
#     of ENC[...] strings with no metadata, and every one of them was encrypted
#     a second time. That succeeded, and produced a file whose values are
#     doubly-wrapped ciphertext -- readable only by decrypting twice, and
#     silently useless to anything expecting the original values.
#
# Both must be loud. Nothing here needs the sops binary; t/04-interop.t pins
# the Go side of the same rule.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();
my $tempdir = tempdir(CLEANUP => 1);

# ----------------------------------------------------------------------------
# 1. encrypt() must refuse a data structure carrying a top-level `sops` key.
# ----------------------------------------------------------------------------

for my $format (qw(yaml json)) {
    my $err = do {
        local $@;
        eval {
            File::SOPS->encrypt(
                data       => { sops => 'my own value', other => 'kept' },
                recipients => [$public],
                format     => $format,
            );
        };
        $@;
    };

    like(
        $err,
        qr/top-level 'sops' entry/,
        "[$format] encrypt refuses a data structure with a top-level sops key"
    );
}

# The reason it has to be refused rather than merged: the digest is computed
# over the user's value and the serializer then throws that value away, so the
# document contradicts its own MAC. Pin that consequence directly, so a future
# "just merge the two" fix cannot pass this file.
{
    my $data = { sops => 'my own value', other => 'kept' };

    my $metadata = File::SOPS::Metadata->new;
    $metadata->lastmodified('2026-01-10T12:00:00Z');

    my $yaml = do {
        local $@;
        eval {
            File::SOPS::Format::YAML->serialize(data => $data, metadata => $metadata);
        };
    };

    # Whatever the serializer does, it must not silently return a document in
    # which the user's value has been replaced by the metadata section.
    ok(
        !defined $yaml || $yaml !~ /^other: kept$/m || $yaml =~ /my own value/,
        'serialization never silently drops a user value stored under "sops"'
    );
}

# ----------------------------------------------------------------------------
# 2. encrypt_file() must refuse input that is already encrypted.
# ----------------------------------------------------------------------------

for my $format (qw(yaml json)) {
    my $encrypted = File::SOPS->encrypt(
        data       => { secret => 'value', n => 42 },
        recipients => [$public],
        format     => $format,
    );

    my $enc_file = "$tempdir/already.$format";
    open my $fh, '>:raw', $enc_file or die $!;
    print $fh $encrypted;
    close $fh;

    my $err = do {
        local $@;
        eval {
            File::SOPS->encrypt_file(
                input      => $enc_file,
                output     => "$tempdir/twice.$format",
                recipients => [$public],
            );
        };
        $@;
    };

    like(
        $err,
        qr/top-level 'sops' entry/,
        "[$format] encrypt_file refuses an already-encrypted input file"
    );

    ok(
        !-e "$tempdir/twice.$format",
        "[$format] and writes no output file"
    );

    # The specific damage, reproduced through the parts encrypt_file used to
    # chain together. It is not "the file looks odd": parse splits the sops
    # section off and encrypt builds a NEW one, so the doubly-wrapped file
    # carries a new data key and NOT the one its inner ENC[...] strings were
    # encrypted with. Decrypting it returns those strings, and nothing left in
    # the file can decrypt them.
    my $format_class = $format eq 'json'
        ? 'File::SOPS::Format::JSON' : 'File::SOPS::Format::YAML';
    my ($stripped, $dropped_metadata) = $format_class->parse($encrypted);
    ok($dropped_metadata,
        "[$format] parse splits the sops section off, which is why encrypt cannot see it");

    my $twice = File::SOPS->encrypt(
        data => $stripped, recipients => [$public], format => $format,
    );
    my $inner = File::SOPS->decrypt(
        encrypted => $twice, identities => [$secret], format => $format,
    );
    like($inner->{secret}, qr/\AENC\[/,
        "[$format] double encryption yields ciphertext of ciphertext");

    my $keys_in_file = () = $twice =~ /BEGIN AGE ENCRYPTED FILE/g;
    is($keys_in_file, 1,
        "[$format] and only ONE data key survives, so the inner values are lost");
}

# ----------------------------------------------------------------------------
# 3. encrypt_file() must refuse in-place re-encryption too -- the case that
#    destroys the original, because output defaults to input.
# ----------------------------------------------------------------------------

{
    my $encrypted = File::SOPS->encrypt(
        data       => { secret => 'value' },
        recipients => [$public],
        format     => 'yaml',
    );

    my $file = "$tempdir/inplace.yaml";
    open my $fh, '>:raw', $file or die $!;
    print $fh $encrypted;
    close $fh;

    my $err = do {
        local $@;
        eval { File::SOPS->encrypt_file(input => $file, recipients => [$public]) };
        $@;
    };

    like($err, qr/top-level 'sops' entry/,
        'encrypt_file refuses in-place re-encryption of an encrypted file');

    my $after = do { open my $in, '<:raw', $file or die $!; local $/; <$in> };
    is($after, $encrypted, 'and the original file is untouched');
}

# ----------------------------------------------------------------------------
# 4. rotate() is the supported way to re-key an encrypted file, and must keep
#    working -- the guard above must not catch it.
# ----------------------------------------------------------------------------

{
    my $encrypted = File::SOPS->encrypt(
        data       => { secret => 'value' },
        recipients => [$public],
        format     => 'yaml',
    );

    my $file = "$tempdir/rotate.yaml";
    open my $fh, '>:raw', $file or die $!;
    print $fh $encrypted;
    close $fh;

    my $ok = eval { File::SOPS->rotate(file => $file, identities => [$secret]); 1 };
    ok($ok, 'rotate still works on an encrypted file') or diag("died: $@");

    my $after = do { open my $in, '<:raw', $file or die $!; local $/; <$in> };
    is_deeply(
        File::SOPS->decrypt(encrypted => $after, identities => [$secret]),
        { secret => 'value' },
        'and the rotated file still holds the original value'
    );
}

# ----------------------------------------------------------------------------
# 5. The same rule for a `sops` entry that is NOT a mapping (k34).
#
# Everything above is about an entry the parser could turn into a Metadata
# object. The hole left open was the entry it could not: from_hash returned
# undef for anything that was not a HashRef, and both format handlers call it
# as from_hash(delete $data->{sops}) once they have seen the key EXIST. So a
# PLAINTEXT file containing `sops: mine` reached encrypt with the key already
# removed from the tree and no metadata to refuse on -- and the encrypted
# document that came out simply did not have it. With output defaulting to
# input that happened over the original.
#
# Measured against sops 3.13.3, on `sops: mine`, on a list, on an explicit
# null and on an empty mapping alike:
#
#   sops encrypt  -> exit 203, the same reserved-key message as for an
#                    already-encrypted file
#   sops decrypt  -> "Found sops entry that is not a mapping"
#   sops rotate   -> "Found sops entry that is not a mapping"
#
# so the presence of the key decides, not its type. The empty mapping was
# already refused here (from_hash builds a Metadata from {}, and the guards
# above fire on it); the other three were not.
# ----------------------------------------------------------------------------

# The unit-level claim: from_hash refuses what it used to swallow.
{
    for my $case (
        ['a scalar', 'mine'],
        ['a list',   ['one', 'two']],
        ['null',     undef],
    ) {
        my ($what, $value) = @$case;

        my $err = do {
            local $@;
            eval { File::SOPS::Metadata->from_hash($value) };
            $@;
        };

        like(
            $err,
            qr/top-level 'sops' entry is .+ not a mapping/,
            "from_hash refuses a sops section that is $what"
        );
    }

    # null dies with the rest deliberately: `delete $data->{sops}` gives undef
    # for BOTH an absent entry and one holding null, and sops refuses the
    # second. The caller that can still tell them apart is the parser, which
    # asks exists() first -- so a document with no sops key must never reach
    # from_hash, and must still parse.
    for my $format (qw(yaml json)) {
        my $content = $format eq 'json' ? '{"other":"kept"}' : "other: kept\n";
        my $format_class = $format eq 'json'
            ? 'File::SOPS::Format::JSON' : 'File::SOPS::Format::YAML';

        my ($data, $metadata) = $format_class->parse($content);
        is_deeply($data, { other => 'kept' },
            "[$format] a document with no sops key still parses");
        is($metadata, undef,
            "[$format] and still reports no metadata rather than dying");
    }

    my $meta = File::SOPS::Metadata->from_hash({ version => '3.7.3' });
    isa_ok($meta, 'File::SOPS::Metadata', 'from_hash on a real mapping');
}

# The data-loss claim, through the public API. This is the part that fails
# against an unfixed lib: without the guard encrypt_file succeeds, and the
# document it writes has no `sops` key at all.
{
    my %source = (
        yaml => {
            scalar => "other: kept\nsops: mine\n",
            list   => "other: kept\nsops:\n  - one\n  - two\n",
            null   => "other: kept\nsops:\n",
        },
        json => {
            scalar => '{"other":"kept","sops":"mine"}',
            list   => '{"other":"kept","sops":["one","two"]}',
            null   => '{"other":"kept","sops":null}',
        },
    );

    for my $format (qw(yaml json)) {
        for my $shape (qw(scalar list null)) {
            my $original = $source{$format}{$shape};

            # a) input/output: nothing may be written.
            my $in  = "$tempdir/nonmap-$shape-in.$format";
            my $out = "$tempdir/nonmap-$shape-out.$format";
            open my $fh, '>:raw', $in or die $!;
            print $fh $original;
            close $fh;

            my $err = do {
                local $@;
                eval {
                    File::SOPS->encrypt_file(
                        input      => $in,
                        output     => $out,
                        recipients => [$public],
                    );
                };
                $@;
            };

            like($err, qr/top-level 'sops' entry is .+ not a mapping/,
                "[$format/$shape] encrypt_file refuses a non-mapping sops entry");
            ok(!-e $out, "[$format/$shape] and writes no output file");

            # b) in-place, which is where the key used to disappear from the
            #    only copy. Byte-identical afterwards, not merely "still there".
            my $inplace = "$tempdir/nonmap-$shape-inplace.$format";
            open my $ip, '>:raw', $inplace or die $!;
            print $ip $original;
            close $ip;

            eval {
                File::SOPS->encrypt_in_place(
                    file => $inplace, recipients => [$public],
                );
            };

            my $after = do {
                open my $rd, '<:raw', $inplace or die $!; local $/; <$rd>
            };
            is($after, $original,
                "[$format/$shape] encrypt_in_place leaves the file untouched");

            # The claim behind the byte comparison, said as the damage it
            # prevents. NOT a search for the string "sops" in the result: an
            # encrypted document contains that word in its own metadata
            # section, so such a check passes on exactly the file this test
            # exists to catch.
            unlike($after, qr/BEGIN AGE ENCRYPTED FILE/,
                "[$format/$shape] and was not replaced by an encrypted "
                . "document with the user's key missing from it");
        }
    }
}

# Reading such a document says what is wrong with it, instead of the generic
# "No SOPS metadata found" it reported while quietly discarding the section.
{
    for my $format (qw(yaml json)) {
        my $content = $format eq 'json'
            ? '{"other":"kept","sops":"mine"}' : "other: kept\nsops: mine\n";

        my $err = do {
            local $@;
            eval {
                File::SOPS->decrypt(
                    encrypted  => $content,
                    identities => [$secret],
                    format     => $format,
                );
            };
            $@;
        };

        like($err, qr/top-level 'sops' entry is .+ not a mapping/,
            "[$format] decrypt names the malformed sops section");
        unlike($err, qr/No SOPS metadata found/,
            "[$format] rather than reporting it as absent");
    }
}

done_testing;

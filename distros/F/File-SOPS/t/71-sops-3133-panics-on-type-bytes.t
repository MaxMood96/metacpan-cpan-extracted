#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use File::SOPS;
use File::SOPS::Encrypted;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k136 / docs/adr/0003, the "known limitation" section.
#
# A document carrying a `type:bytes` cell panics sops 3.13.3 on the read path:
# exit 2, `panic: runtime error: hash of unhashable type []uint8`, in the
# aes package's `stashKey`. The panic is independent of format (measured on
# YAML and dotenv; identical) and independent of payload (measured on "hello"
# and a 4-byte blob; identical). What triggers it is the LABEL: sops 3.13.3
# can write `type:bytes` into its own model and cannot read it back from a
# file. No sops store produces one (YAML `!!binary` and the `binary` input
# store both surface as `type:str`), so this is a sops-side bug.
#
# That matters to docs/adr/0003 because `type => 'bytes'` is the documented
# escape hatch for a caller who genuinely has bytes rather than characters --
# no UTF-8 encode on the way in, no UTF-8 decode on the way out. A document
# built through that escape hatch cannot be opened by sops in any format.
# The decision this ticket records is to WARN rather than REFUSE: option (b)
# is filed as a separate decision for a future ADR.
#
# Two halves, proving different things:
#
#   * The UNIT half pins that `encrypt_value(..., type => 'bytes')` is still
#     the documented wire shape -- the bytes the caller handed in go to the
#     cipher raw, and come back raw through `decrypt_value`. The read path
#     works for a foreign `type:bytes` cell. No binary needed.
#   * The INTEROP half is the only half that proves anything about sops:
#     that sops 3.13.3 panics on the doc f-sops writes, and that the same
#     doc with `type:str` reads at exit 0 -- so the panic is label-driven,
#     not payload-driven.

# The plaintext the interop half uses. "hello" is what the ticket measured;
# the payload is not what panics, but the fixture is human-readable and stays
# out of commit messages and bug reports. A "4 raw bytes" run is in the
# section comment below, never on disk.
my $PAYLOAD = 'hello';

###############################################################################
# Unit -- encrypt_value / decrypt_value on a type:bytes cell still round-trip
###############################################################################
subtest 'encrypt_value with type => bytes carries the label, decrypt_value returns the bytes' => sub {
    # Same data key for both sides, like a real document.
    my $key = "\x00" x 32;

    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => $PAYLOAD,
        key   => $key,
        aad   => 'secret:',
        type  => 'bytes',
    );

    is $enc->type, 'bytes',
        'the encrypted object carries type:bytes, not the scalar-derived type';

    like $enc->to_string, qr/,type:bytes\]\z/,
        'and the wire form names the label';

    is $enc->decrypt_value(key => $key, aad => 'secret:'), $PAYLOAD,
        'decrypt_value returns the bytes the caller put in -- the read path works';
};

subtest 'type:str on the same payload round-trips with no label confusion' => sub {
    # The control: the same plaintext under type:str produces a different
    # wire form (the str label), and the str label reads back at exit 0 in
    # interop below. Without this half the label-driven nature of the panic
    # would be pinned against a different document.
    my $key = "\x00" x 32;

    my $enc = File::SOPS::Encrypted->encrypt_value(
        value => $PAYLOAD,
        key   => $key,
        aad   => 'secret:',
        type  => 'str',
    );

    is $enc->type, 'str', 'type:str is what the label says';
    like $enc->to_string, qr/,type:str\]\z/, '  and the wire form too';

    is $enc->decrypt_value(key => $key, aad => 'secret:'), $PAYLOAD,
        'and the read path is just as plain for str';
};

###############################################################################
# Interop -- the panic sops 3.13.3 throws, and the str control that doesn't
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- the sops 3.13.3 panic on a type:bytes cell was NOT "
       . "measured, so the POD warning and ADR 0003's 'known limitation' "
       . "section go unpinned. Run maint/fetch-sops or set SOPS_BIN.", 5
        unless $sops_bin;

    require Crypt::Age;
    diag("Using sops binary: $sops_bin");

    my $dir = tempdir(CLEANUP => 1);
    my ($pub, $sec) = Crypt::Age->generate_keypair();
    write_bytes("$dir/key.txt", $sec);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    # Build a properly-formed SOPS YAML doc by encrypting normally, then flip
    # the label on the encrypted cell. The doc carries the same age recipient
    # as the data key, so sops can decrypt to the AES path -- which is where
    # the panic happens, and where the label is what trips it.
    my $base = File::SOPS->encrypt(
        data       => { secret => $PAYLOAD },
        recipients => [ $pub ],
        format     => 'yaml',
    );
    (my $bytes_doc = $base) =~ s/,type:str\]/,type:bytes]/;
    my $str_doc = $base;   # unchanged: the str control

    write_bytes("$dir/bytes.yaml", $bytes_doc);
    write_bytes("$dir/str.yaml",   $str_doc);

    ###########################################################################
    subtest 'sops 3.13.3 panics on a type:bytes cell in YAML, exit 2' => sub {
        my ($out, $exit) = run($sops_bin, "-d '$dir/bytes.yaml'");
        is $exit, 2, 'sops exits 2 (the same exit the ticket measured)';
        like $out, qr/hash of unhashable type \[\]uint8/,
            'stderr names the unhashable type: aes/stashKey, the ticket stack frame';
        like $out, qr{sops/v3/aes},
            '  and the panic sits in the aes package, not in any parser';
    };

    ###########################################################################
    subtest 'the same payload under type:str reads at exit 0' => sub {
        # The control: identical data key, identical AAD, identical payload,
        # only the label differs. Exit 0 is what makes the panic label-driven
        # rather than payload-driven -- which is the entire ticket claim.
        my ($out, $exit) = run($sops_bin, "-d '$dir/str.yaml'");
        is $exit, 0, 'sops reads its own type:str cell at exit 0';
        like $out, qr/^secret:\s*\Q$PAYLOAD\E$/m,
            '  and the plaintext matches what we encrypted';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

sub write_bytes {
    my ($path, $bytes) = @_;
    open my $fh, '>:raw', $path or die "open $path: $!";
    print {$fh} $bytes;
    close $fh or die "close $path: $!";
    return;
}

sub run {
    my ($sops_bin, $args) = @_;
    my $out = `$sops_bin $args 2>&1`;
    return ($out, $? >> 8);
}

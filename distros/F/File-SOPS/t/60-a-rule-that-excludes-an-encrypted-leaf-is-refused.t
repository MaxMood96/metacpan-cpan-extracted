#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Test::More;
use Test::Fatal;
use File::Temp qw(tempdir);
use Encode qw(encode_utf8);
use Crypt::Age;

use File::SOPS;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k150 -- docs/adr/0046, then k160 -- docs/adr/0049.
#
# This distribution decrypted ENC-DRIVEN: _decrypt_tree asked whether a leaf
# LOOKS encrypted and never asked the encryption rule. It encrypts RULE-DRIVEN:
# _encrypt_tree asks should_encrypt_path and nothing else. Every method that
# does both -- rotate and edit -- therefore wrote back BARE every leaf that is
# encrypted in the file and that the document's own rule excludes. Measured
# before docs/adr/0046 landed: `File::SOPS->rotate` on such a document exited 0
# and left
#
#     password: hunter2
#
# on disk, in a file that still looks like a sops file.
#
# sops cannot reach that state: it decrypts rule-first, so a value the rule
# excludes is read as the literal ENC[...] string and hashed as one, and the
# MAC stops the document. The interop half below is what says so.
#
# docs/adr/0046 closed that with a GUARD on the write path, and this file
# pinned the guard. docs/adr/0049 made _decrypt_tree rule-first instead and the
# guard came out, so the pins have moved to what refuses these documents now --
# which is the MAC, in decrypt, exactly where sops refuses them. Nothing about
# the DAMAGE moved, and that is what the assertions are still mostly about:
#
# What this file pins is the PLAINTEXT ON DISK, not the exit code. The exit
# code was the least of it: the damage is the secret in the file.

my ($PUBLIC, $SECRET) = Crypt::Age->generate_keypair();

# Every secret in the fixture. `note_unencrypted` is deliberately NOT one --
# it is the leaf the default rule leaves readable, and it is what makes sops
# answer two of the rows below with exit 25 instead of 51.
my @SECRETS = qw( topsecret hunter2 first-token second-token );

# The rule shapes and what sops answers for the same document. All measured
# against sops 3.13.3 on 2026-08-21.
#
# 51 is the MAC mismatch: the ENC[...] string went into the digest verbatim.
# 25 is the other direction of the same disagreement, reached first by sops's
# walk in those two rows -- `note_unencrypted` is bare and those rules select
# it, so sops tries to decrypt the literal `public`.
#
# Since docs/adr/0049 the exit code is the whole of what distinguishes the
# rows HERE too, which is why it is what the expectations below are keyed off:
# a row sops answers 51 fails our MAC, and a row sops answers 25 is refused at
# the leaf by the same walk that refuses it there. Neither is order-dependent:
# only one branch of _decrypt_tree croaks, so a document holding a bare leaf
# the rule selects stops there whatever order the hash is walked in.
my %REFUSAL = (
    51 => qr/MAC verification failed/,
    25 => qr/rule says this value is encrypted/,
);
my @RULES = (
    [ 'encrypted_regex: "^nothing$"', 'encrypted_regex',    '^nothing$', 51 ],
    [ 'encrypted_suffix: _nope',      'encrypted_suffix',   '_nope',     51 ],
    [ 'unencrypted_regex: "."',       'unencrypted_regex',  '.',         51 ],
    [ 'unencrypted_suffix: word',     'unencrypted_suffix', 'word',      25 ],
    [ 'unencrypted_suffix: s',        'unencrypted_suffix', 's',         25 ],
);

###############################################################################
# 1. rotate refuses, and writes nothing
###############################################################################
subtest 'rotate refuses every rule shape, and leaves the file untouched' => sub {
    for my $rule (@RULES) {
        my ($line, undef, undef, $exit) = @$rule;

        my $dir  = tempdir(CLEANUP => 1);
        my $file = "$dir/secrets.yaml";
        my $doc  = with_rule(base_document(), $line);
        write_bytes($file, $doc);

        my $err = exception {
            File::SOPS->rotate(file => $file, identities => [ $SECRET ])
        };

        like $err, $REFUSAL{$exit},
            "$line: rotate refuses, the way sops does (exit $exit)";

        # ONE mechanism refuses these, and it is the one sops refuses them
        # with. docs/adr/0046's guard sat in front of it and named the leaf;
        # anything still saying so would mean the guard, or something shaped
        # like it, had come back.
        unlike $err, qr/Refusing to rotate/,
            '  and it is not a guard beside the round trip that says so';

        # The point of the whole ticket.
        my $after = slurp($file);
        for my $secret (@SECRETS) {
            unlike $after, qr/\Q$secret\E/,
                "  '$secret' is not on disk in plaintext";
        }
        is $after, $doc, '  the file is byte-for-byte what it was';
    }
};

###############################################################################
# 2. edit refuses too -- and before the editor is opened
###############################################################################
subtest 'edit refuses the same document without opening the editor' => sub {
    my $dir    = tempdir(CLEANUP => 1);
    my $file   = "$dir/secrets.yaml";
    my $marker = "$dir/the-editor-ran";
    my $doc    = with_rule(base_document(), 'encrypted_regex: "^nothing$"');
    write_bytes($file, $doc);

    local $ENV{FILE_SOPS_TEST_MARKER} = $marker;
    my $err = exception {
        File::SOPS->edit(
            file       => $file,
            identities => [ $SECRET ],
            editor     => [ $^X, '-e',
                'open my $f, ">", $ENV{FILE_SOPS_TEST_MARKER} or die; '
              . 'print {$f} "ran"; close $f' ],
        );
    };

    like $err, qr/MAC verification failed/, 'edit refuses';
    unlike $err, qr/Refusing to edit/,
        'on the MAC, in the decrypt it does first, not on a guard of its own';
    ok !-e $marker,
        'the editor never ran -- refusing after it would throw away the edit';

    my $after = slurp($file);
    unlike $after, qr/hunter2/, 'and no secret is on disk in plaintext';
    is $after, $doc, 'the file is byte-for-byte what it was';
};

###############################################################################
# 3. A document whose rule DOES reproduce it is not touched by any of this
###############################################################################
subtest 'a rule that reproduces the document still rotates and still edits' => sub {
    for my $line ('unencrypted_suffix: _unencrypted',
                  'encrypted_regex: "^(api_key|password|tokens)$"') {
        my $dir  = tempdir(CLEANUP => 1);
        my $file = "$dir/secrets.yaml";
        write_bytes($file, with_rule(base_document(), $line));

        is exception {
            File::SOPS->rotate(file => $file, identities => [ $SECRET ])
        }, undef, "$line: rotate goes through";

        my $back = File::SOPS->decrypt(
            encrypted  => slurp($file),
            identities => [ $SECRET ],
            format     => 'yaml',
        );
        is $back->{db}{password}, 'hunter2', '  and the document survives it';

        my $after = slurp($file);
        unlike $after, qr/hunter2/, '  with nothing in plaintext';
    }
};

###############################################################################
# 4. The other direction, INVERTED by docs/adr/0049
###############################################################################
subtest 'a bare leaf the rule selects is refused, not encrypted silently' => sub {
    # The mirror image: the rule says encrypt, the document holds the value
    # bare. Until k160 this subtest pinned the divergence rather than the
    # fix -- rotate went through at exit 0 and the readable value came back
    # ENCRYPTED, under a data key the caller may not keep -- and it said in so
    # many words that a rule-driven _decrypt_tree was what had to change it.
    # It did. sops refuses this document at exit 25 (pinned in the interop
    # half) and so do we now, out of the same walk.
    my $dir  = tempdir(CLEANUP => 1);
    my $file = "$dir/secrets.yaml";
    my $doc  = with_rule(base_document(), 'encrypted_regex: "."');
    write_bytes($file, $doc);

    like exception {
        File::SOPS->rotate(file => $file, identities => [ $SECRET ])
    }, qr/\Anote_unencrypted: .*rule says this value is encrypted/s,
        'rotate refuses it, at the path of the leaf that disagrees';

    is slurp($file), $doc,
        'and the readable value is still readable, in a file left as it was';
};

###############################################################################
# 5. Interop -- the only half that says anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- what sops does with these documents was NOT "
       . "measured, so the refusal above is pinned against nothing. Run "
       . "maint/fetch-sops or set SOPS_BIN.", 2
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    subtest 'sops refuses each of the same documents' => sub {
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        for my $rule (@RULES) {
            my ($line, undef, undef, $expected) = @$rule;
            my $file = "$dir/probe.yaml";
            my $doc  = with_rule(base_document(), $line);
            write_bytes($file, $doc);

            my (undef, $read) = run($sops_bin, "-d '$file'");
            is $read, $expected, "$line: sops -d is exit $expected";

            my (undef, $rotated) = run($sops_bin, "rotate -i '$file'");
            is $rotated, $expected, "  and sops rotate stops there too";

            my $after = slurp($file);
            unlike $after, qr/hunter2/, '  writing nothing';
            is $after, $doc, '  and leaving the file as it was';
        }
    };

    subtest 'the rule this guard used to catch now classifies the same way' => sub {
        # Every row above starts from a document whose rule was edited by
        # hand. This one does not: an ordinary rule, an ordinary `sops -e`,
        # and a non-ASCII key. It used to be the proof that the defect was
        # practical rather than theoretical -- RE2's \w is ASCII-only and
        # Perl's was Unicode-aware for the flagged string our parser produces,
        # so should_encrypt_path called a leaf sops had ENCRYPTED one the rule
        # EXCLUDES, and this guard was the only thing between that and
        # `café: hunter2` on disk.
        #
        # k161 closed the classification itself (docs/adr/0048): the two
        # rule patterns are now compiled /a, which is RE2's answer for \w.
        # So the premise is gone -- the rule no longer excludes the leaf --
        # and what this subtest pins is the step after the guard: rotate goes
        # THROUGH, and the value stays encrypted. The whole file of assertions
        # above is unaffected; those documents carry rules that really do
        # exclude an encrypted leaf, whichever dialect reads them.
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        my $file = "$dir/unicode.yaml";
        write_bytes($file, encode_utf8("caf\x{e9}") . ": hunter2\n");

        my (undef, $code) = run($sops_bin,
            "-e -i --age '$PUBLIC' --unencrypted-regex '^\\w+\$' '$file'");
        is $code, 0, 'sops encrypts it under an ordinary unencrypted_regex';

        my $doc = slurp($file);
        like $doc, qr/ENC\[AES256_GCM/,
            'and the value really is encrypted in the file sops wrote';

        is exception {
            File::SOPS->rotate(file => $file, identities => [ $SECRET ])
        }, undef, 'rotate no longer refuses it: the rule and the file agree';

        my $after = slurp($file);
        unlike $after, qr/hunter2/, 'the secret stays off the disk';
        like $after, qr/ENC\[AES256_GCM/,
            'and the value is still encrypted after the rotation';
        isnt $after, $doc, 'under a new data key, which is what rotate is for';

        my (undef, $read) = run($sops_bin, "-d '$file'");
        is $read, 0, 'and sops reads the document we rotated';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# One document, encrypted under the default rule, with four secrets in three
# shapes: a top-level leaf, a nested one, and two list elements that share
# their parent's path because an array contributes no path component.
sub base_document {
    return File::SOPS->encrypt(
        data => {
            api_key          => 'topsecret',
            db               => { password => 'hunter2' },
            tokens           => [ 'first-token', 'second-token' ],
            note_unencrypted => 'public',
        },
        recipients => [ $PUBLIC ],
        format     => 'yaml',
    );
}

# Replace the document's rule, which is what a `.sops.yaml` that has moved on,
# or a hand-edited section, amounts to. The rules are mutually exclusive, so
# the new one takes the old one's line rather than joining it.
sub with_rule {
    my ($doc, $line) = @_;
    $doc =~ s/^(\s+)unencrypted_suffix: .*$/$1$line/m
        or die 'the fixture has no unencrypted_suffix line';
    return $doc;
}

sub run {
    my ($sops_bin, $args) = @_;
    my $out = `$sops_bin $args 2>&1`;
    return ($out, $? >> 8);
}

sub write_bytes {
    my ($path, $bytes) = @_;
    open my $fh, '>:raw', $path or die "open $path: $!";
    print {$fh} $bytes;
    close $fh or die "close $path: $!";
    return;
}

sub slurp {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "open $path: $!";
    local $/;
    return <$fh>;
}

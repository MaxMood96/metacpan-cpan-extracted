#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Test::More;
use Test::Fatal;
use File::Temp qw(tempdir);
use Crypt::Age;

use File::SOPS;
use File::SOPS::Comment;
use File::SOPS::Metadata;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k160 -- docs/adr/0049, the structural half of k150.
#
# sops decrypts RULE-FIRST: the encryption rule decides what a leaf IS, and the
# leaf's own text never gets a vote. A leaf the rule EXCLUDES is a literal
# value whatever it spells -- ENC[...] included -- and the digest covers that
# text. A leaf the rule SELECTS must be an encrypted string, or one of four
# shapes sops leaves alone.
#
# This distribution decrypted ENC-DRIVEN until 0.003: _decrypt_tree asked
# whether a leaf LOOKED encrypted and never asked the rule. Measured against
# sops 3.13.3 over 4 formats x 4 rule fields x 4 cells, all 64 cells answering
# alike:
#
#                        rule SELECTS       rule EXCLUDES
#     leaf ENC[...]      exit 0             exit 51, MAC mismatch
#     leaf bare          exit 25            exit 0, read as it stands
#
# and the digest input for the exit-51 cell was read straight off sops's own
# `computed` figure: SHA-512 of the ENC[...] string, byte for byte.
#
# What this file pins is that both of those directions now fall out of the
# WALK and the MAC rather than out of a guard beside them.

my ($PUBLIC, $SECRET) = Crypt::Age->generate_keypair();

# The four rule shapes that exclude an encrypted leaf -- one per rule field,
# so that no field can quietly stop taking part.
my @RULES_THAT_EXCLUDE = (
    [ q{encrypted_regex: "^nothing$"} ],
    [ q{encrypted_suffix: _nope}      ],
    [ q{unencrypted_regex: "."}       ],
    [ q{unencrypted_suffix: y}        ],
);

# Every secret in the fixture. `note_unencrypted` is deliberately NOT one.
my @SECRETS = qw( topsecret hunter2 );

###############################################################################
# 1. A leaf the rule EXCLUDES is a literal, and it round-trips as one
###############################################################################
subtest 'an ENC[...] leaf at an excluded path comes back as its own text' => sub {
    # The document is built by encrypt() itself, so nothing here is
    # hand-edited: `keep` holds a string that SPELLS an encrypted value and
    # sits at a path the rule excludes, so encrypt writes it verbatim and
    # hashes it verbatim. A rule-first reader gets the string back; an
    # ENC-driven one tries to decrypt it -- with the wrong key and the wrong
    # AAD -- and dies on a document this library has just written.
    my $inner = enc_string_for('borrowed-ciphertext');

    my $doc = File::SOPS->encrypt(
        data              => { keep => $inner, other => 'plain-secret' },
        recipients        => [$PUBLIC],
        format            => 'yaml',
        unencrypted_regex => '^keep$',
    );

    like $doc, qr/\Qkeep: $inner\E/,
        'the excluded leaf is written verbatim, ENC[...] text and all';

    # Held in an eval so that an ENC-DRIVEN reader records the two assertions
    # below as failures instead of taking the whole file down with it: this is
    # the subtest that has to be able to fail out loud.
    my $back;
    my $err = exception { $back = File::SOPS->decrypt(
        encrypted  => $doc,
        identities => [$SECRET],
        format     => 'yaml',
    ) };
    is $err, undef, 'a rule-first reader does not try to decrypt it';
    $back ||= {};

    is $back->{keep}, $inner,
        'and comes back as that same text, not decrypted and not refused';
    is $back->{other}, 'plain-secret',
        'while the leaf the rule selects is decrypted as usual';
};

###############################################################################
# 2. The MAC is what stops a rule that does not cover what is encrypted
###############################################################################
subtest 'a rule that excludes an encrypted leaf fails the MAC, in all four fields' => sub {
    for my $rule (@RULES_THAT_EXCLUDE) {
        my ($line, undef, undef) = @$rule;
        my $doc = with_rule(sealed_document(), $line);

        my $err = exception {
            File::SOPS->decrypt(encrypted => $doc, identities => [$SECRET],
                format => 'yaml')
        };

        like $err, qr/MAC verification failed/,
            "$line: the digest is over the ENC[...] text, so the MAC stops it";

        # The guard docs/adr/0046 put in front of this is GONE, and its
        # message with it. Anything still naming a leaf here would mean the
        # refusal came from a second mechanism.
        unlike $err, qr/Refusing to/,
            '  and it is the MAC that says so, not a guard';

        # ignore_mac cannot check anything -- and does not have to, because
        # nothing decrypted the excluded leaf. What comes back is ciphertext.
        my $back = File::SOPS->decrypt(encrypted => $doc,
            identities => [$SECRET], format => 'yaml', ignore_mac => 1);
        like $back->{api_key}, qr/\AENC\[AES256_GCM/,
            '  and under ignore_mac the excluded leaf is its own text';
        for my $secret (@SECRETS) {
            isnt $back->{api_key}, $secret,
                "  '$secret' is not what ignore_mac hands back";
        }
    }
};

###############################################################################
# 3. rotate and edit: the plaintext cannot reach the disk any more
###############################################################################
subtest 'rotate and edit cannot write an excluded leaf out in plaintext' => sub {
    my $dir    = tempdir(CLEANUP => 1);
    my $marker = "$dir/the-editor-ran";

    for my $rule (@RULES_THAT_EXCLUDE) {
        my ($line) = @$rule;
        my $file = "$dir/secrets.yaml";
        my $doc  = with_rule(sealed_document(), $line);
        write_bytes($file, $doc);

        my $err = exception {
            File::SOPS->rotate(file => $file, identities => [$SECRET])
        };
        like $err, qr/MAC verification failed/, "$line: rotate stops on the MAC";

        my $after = slurp($file);
        unlike $after, qr/\Q$_\E/, "  '$_' is not on disk in plaintext"
            for @SECRETS;
        is $after, $doc, '  and the file is byte-for-byte what it was';
    }

    my $file = "$dir/edit.yaml";
    my $doc  = with_rule(sealed_document(), 'encrypted_regex: "^nothing$"');
    write_bytes($file, $doc);
    local $ENV{FILE_SOPS_TEST_MARKER} = $marker;
    like exception {
        File::SOPS->edit(
            file       => $file,
            identities => [$SECRET],
            editor     => [ $^X, '-e',
                'open my $f, ">", $ENV{FILE_SOPS_TEST_MARKER} or die; '
              . 'print {$f} "ran"; close $f' ],
        );
    }, qr/MAC verification failed/, 'edit stops on the MAC too';
    ok !-e $marker,
        'and before the editor is opened, which is where it always stopped';
    is slurp($file), $doc, 'leaving the file as it was';
};

###############################################################################
# 4. The other direction: a bare leaf the rule SELECTS
###############################################################################
subtest 'a bare leaf the rule selects is refused, not silently encrypted' => sub {
    # The mirror image, and until k160 it was read as a literal and then
    # ENCRYPTED by the next write -- a value that was readable, turned into
    # ciphertext under a key the caller may not keep. sops stops at exit 25.
    my $doc = with_rule(base_document(), 'encrypted_regex: "."');

    my $err = exception {
        File::SOPS->decrypt(encrypted => $doc, identities => [$SECRET],
            format => 'yaml', ignore_mac => 1)
    };

    like $err, qr/\Anote_unencrypted:/,
        'refused at the path of the leaf that disagrees';
    like $err, qr/rule says this value is encrypted/, 'saying which way round';
    like $err, qr/exit 25/, 'and what sops does with the same document';

    # THE VALUE IS NOT IN THE MESSAGE. sops quotes it ("Input string public
    # does not match sops' data format"); a leaf that is bare where the rule
    # says encrypted is a secret in the clear, and an error goes to bug
    # reports.
    unlike $err, qr/\bpublic\b/,
        'and the value itself is nowhere in the message';

    my $dir  = tempdir(CLEANUP => 1);
    my $file = "$dir/selected.yaml";
    write_bytes($file, $doc);
    like exception {
        File::SOPS->rotate(file => $file, identities => [$SECRET],
            ignore_mac => 1)
    }, qr/rule says this value is encrypted/,
        'and rotate no longer encrypts it quietly';
    like slurp($file), qr/note_unencrypted: public/,
        'the readable value is still readable, and still in the file';
};

###############################################################################
# 5. The four shapes sops leaves alone in a selected slot
###############################################################################
subtest 'a null, an empty string, a comment and an empty container stand bare' => sub {
    # Measured in all four formats, exit 0 for each: Go's walk returns before
    # the cipher for a nil, the cipher itself short-circuits an empty string,
    # a plaintext comment is warned about and kept, and an empty container
    # holds no leaf at all. The first two are also the only shapes
    # _encrypt_tree writes bare into a selected slot, so they are what keeps a
    # document THIS library wrote readable.
    my $doc = File::SOPS->encrypt(
        data       => { e => '', n => undef, k => 'secret', empties => {} },
        recipients => [$PUBLIC],
        format     => 'yaml',
    );

    my $back = File::SOPS->decrypt(encrypted => $doc,
        identities => [$SECRET], format => 'yaml');

    is $back->{e}, '',      'an empty string comes back, and is not refused';
    is $back->{n}, undef,   'a null comes back, and is not refused';
    is $back->{k}, 'secret', 'beside a leaf that really is encrypted';
    is_deeply $back->{empties}, {}, 'an empty mapping holds no leaf to refuse';

    # The comment has no public spelling in a YAML plaintext tree -- YAML::XS
    # drops comment lines on parse -- so the walk is asked directly, the way
    # t/45 asks the other walks.
    my $meta = File::SOPS::Metadata->new(unencrypted_suffix => undef);
    ok $meta->should_encrypt_path(['c']),
        'the rule selects the path the comment sits at';
    my $tree = File::SOPS::_decrypt_tree(
        { c => [ File::SOPS::Comment->new(text => ' note') ] },
        "\0" x 32, $meta, []);
    isa_ok $tree->{c}[0], 'File::SOPS::Comment',
        'and a plaintext comment there is kept rather than refused';
};

###############################################################################
# 6. Which excluded comment the digest covers, and which it does not
###############################################################################
subtest 'an excluded wire comment is a value in YAML and a comment line in a flat store' => sub {
    # The wire has two shapes for a comment and only one of them is a value
    # slot. In dotenv and ini it is a comment LINE (`#ENC[...]`, `; ENC[...]`)
    # which the store reads as a comment before any rule is consulted; this
    # handler spells that as the comment bucket, a '' KEY. In YAML it is an
    # ordinary SEQUENCE ENTRY, so at an excluded path it stays a string.
    #
    # Measured on sops 3.13.3, one rule-swapped document per format put
    # through both hypotheses with the MAC recomputed each way:
    #
    #                   comment digested   comment skipped
    #     yaml                 exit 0            exit 51
    #     ini                  exit 51           exit 0
    #     dotenv               exit 51           exit 0
    my $wire = enc_string_for('a comment', 'comment');
    my $key  = "\0" x 32;
    my $excl = File::SOPS::Metadata->new(unencrypted_regex => '.');
    my $sel  = File::SOPS::Metadata->new(unencrypted_suffix => undef);

    my $seq    = [ [ ['tokens'], $wire ] ];
    my $bucket = [ [ ['db', $File::SOPS::COMMENT_BUCKET_KEY], $wire ] ];

    is scalar @{ File::SOPS::_digested_leaves($seq, $key, $excl) }, 1,
        'a YAML sequence entry the rule excludes IS digested';
    is scalar @{ File::SOPS::_digested_leaves($seq, $key, $sel) }, 0,
        'and is a comment again where the rule selects it';
    is scalar @{ File::SOPS::_digested_leaves($bucket, $key, $excl) }, 0,
        'a comment-bucket entry is NEVER digested, whatever the rule says';
    is scalar @{ File::SOPS::_digested_leaves($bucket, $key, $sel) }, 0,
        '  and that does not depend on the rule either';

    # The encrypt side has no data key and no wire shapes to read.
    is scalar @{ File::SOPS::_digested_leaves($seq, undef, $excl) }, 1,
        'the encrypt side answers nothing here';
};

###############################################################################
# 7. Interop -- the only half that says anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- what sops does with these documents was NOT "
       . "measured, so everything above is pinned against nothing. Run "
       . "maint/fetch-sops or set SOPS_BIN.", 2
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    subtest 'sops answers each of these documents the same way we do' => sub {
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        # exit 51: the rule excludes an encrypted leaf, so its ENC[...] text
        # goes into the digest verbatim and the stored MAC does not match.
        for my $rule (@RULES_THAT_EXCLUDE) {
            my ($line) = @$rule;
            my $file = "$dir/probe.yaml";
            write_bytes($file, with_rule(sealed_document(), $line));
            my (undef, $code) = run($sops_bin, "-d '$file'");
            is $code, 51, "$line: sops -d is exit 51, MAC mismatch";
        }

        # exit 25: the rule selects a leaf the file holds bare.
        my $file = "$dir/probe.yaml";
        write_bytes($file, with_rule(base_document(), 'encrypted_regex: "."'));
        my ($out, $code) = run($sops_bin, "-d '$file'");
        is $code, 25, 'a bare leaf the rule selects is exit 25 at sops';
        like $out, qr/does not match sops/,
            '  and that is a decryption failure, not a MAC one';
    };

    subtest 'sops reads the excluded-ENC document this library writes' => sub {
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        # The document from subtest 1: an ENC[...] string at a path the rule
        # excludes, hashed as its own text by our encrypt side. If sops reads
        # it at exit 0 and prints that text back, our digest for the excluded
        # cell is sops's digest.
        my $inner = enc_string_for('borrowed-ciphertext');
        my $file  = "$dir/literal.yaml";
        write_bytes($file, File::SOPS->encrypt(
            data              => { keep => $inner, other => 'plain-secret' },
            recipients        => [$PUBLIC],
            format            => 'yaml',
            unencrypted_regex => '^keep$',
        ));

        my ($out, $code) = run($sops_bin, "-d '$file'");
        is $code, 0, 'sops reads it -- so the MAC we wrote is the MAC it computes';
        like $out, qr/\Qkeep: $inner\E/,
            'and hands the excluded leaf back as its own text, exactly as we do';
        unlike $out, qr/borrowed-ciphertext/,
            'never as the plaintext behind it';

        my (undef, $rot) = run($sops_bin, "rotate -i '$file'");
        is $rot, 0, 'sops rotates it too';
        like slurp($file), qr/\Qkeep: $inner\E/,
            '  copying the excluded leaf through verbatim, which is what we do';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# Two secrets and NOTHING bare. The four rules above exclude at least one of
# them and select or exclude the rest, so every leaf lands in the ENC[...] half
# of the matrix and the OTHER direction cannot be reached first -- which is
# what sops's walk would do, and it answers exit 25 rather than exit 51 when it
# does (t/60 records that row).
sub sealed_document {
    return File::SOPS->encrypt(
        data => {
            api_key => 'topsecret',
            db      => { password => 'hunter2' },
        },
        recipients => [$PUBLIC],
        format     => 'yaml',
    );
}

# One document with two secrets and one deliberately readable value: the bare
# leaf is what makes the OTHER direction reachable in the same fixture.
sub base_document {
    return File::SOPS->encrypt(
        data => {
            api_key          => 'topsecret',
            db               => { password => 'hunter2' },
            note_unencrypted => 'public',
        },
        recipients => [$PUBLIC],
        format     => 'yaml',
    );
}

# A real ENC[...] string, made the way every other one is made, so that
# nothing in this file hand-writes wire format.
sub enc_string_for {
    my ($plaintext, $type) = @_;
    my $doc = File::SOPS->encrypt(
        data       => { v => $plaintext },
        recipients => [$PUBLIC],
        format     => 'yaml',
    );
    my ($enc) = $doc =~ /^v: (ENC\[[^\n]*\])$/m
        or die 'the fixture has no encrypted value';
    $enc =~ s/,type:str\]\z/,type:$type]/ if defined $type;
    return $enc;
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

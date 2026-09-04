#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;
use File::Temp qw(tempdir);
use Crypt::Age;

use File::SOPS;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k176 -- docs/adr/0066.
#
# docs/adr/0051 split the rule-regex refusal between the read and write paths:
# a pattern RE2 cannot compile matches NOTHING on the read path, sops discards
# the compile error, and decrypt/extract/decrypt_file reproduce that. The split
# is taken by RE2's verdict, but for a pattern PERL cannot compile the code
# cannot see RE2's verdict, so it refuses -- and that conflates two cases:
#
#   (?U)fo+   RE2 COMPILES it (ungreedy flag), Perl rejects it. Refusing is
#             correct: RE2 selects keys over there and this side cannot say
#             which, so guessing "matches nothing" would misclassify leaves.
#   fo(       RE2 REJECTS it too (`missing closing ): fo(`), so sops matches
#             nothing and reads the document at exit 0. We refuse it anyway.
#
# So `fo(` is a document sops READS and this library does not -- the residue
# docs/adr/0051 left standing and docs/adr/0066 accepts as a decided limit
# (the fourth Limit in the Metadata POD, "A fourth arrived with the read
# path"). This file pins that divergence against sops 3.13.3. t/62 already
# unit-pins that `fo(` is refused by should_encrypt_path with the "not a valid
# Perl regular expression" message; t/66 pins the OPPOSITE case ((?=foo), an
# unsupported construct RE2 NAMES -> matches nothing -> read path passes). The
# value HERE is the read-path INTEROP divergence: sops reads, this side refuses.

my ($PUBLIC, $SECRET) = Crypt::Age->generate_keypair();

# The one pattern the whole file turns on. Neither dialect compiles it: RE2
# reports `error parsing regexp: missing closing ): fo(` (section 3 reads that
# verdict off the .sops.yaml path_regex oracle, the one place sops REPORTS it),
# and Perl reports `Unmatched (`. Because RE2 rejects it, sops treats the rule
# as matching nothing -- so every value stays encrypted and the MAC is
# unchanged, which is WHY sops reads the document at exit 0.
my $UNCOMPILABLE = 'fo(';

# A real age-encrypted document carrying `unencrypted_regex: "fo("`. NOT
# hand-built: encrypt() writes it under the default rule and then the suffix
# line is REPLACED by the pattern -- the two rules are mutually exclusive, so
# it is a replace and not an add. encrypt() itself refuses to write this
# pattern (that is the write-path half, pinned in t/66/section 2), which is why
# the fixture swaps it in after the fact. The swap leaves the set of encrypted
# values -- and therefore the MAC -- untouched, exactly as it is untouched at
# sops, because RE2 excludes nothing under `fo(`.
sub injected_document {
    my $doc = File::SOPS->encrypt(
        data       => { foo => 'bar', baz => 'qux' },
        recipients => [ $PUBLIC ],
        format     => 'yaml',
    );
    $doc =~ s/^(\s*)unencrypted_suffix: _unencrypted$/$1unencrypted_regex: "$UNCOMPILABLE"/m
        or die 'fixture: no unencrypted_suffix line to replace';
    return $doc;
}

###############################################################################
# 1. The Perl side refuses it, loudly, naming the pattern -- with or without a
#    binary. This is the loud refusal the divergence is made of.
###############################################################################
subtest 'decrypt refuses a document whose rule neither dialect can compile'
    => sub {
    my $doc = injected_document();

    like $doc, qr/\Qunencrypted_regex: "$UNCOMPILABLE"\E/,
        'the fixture really carries the pattern neither dialect can compile';
    unlike $doc, qr/\bbar\b/,
        '  and its values really are encrypted (nothing excluded)';
    like $doc, qr/ENC\[AES256_GCM/,
        '  as ENC[...] leaves under an unchanged MAC';

    my $err = exception {
        File::SOPS->decrypt(encrypted => $doc, identities => [ $SECRET ]);
    };

    like $err, qr/\QCannot use '$UNCOMPILABLE' as the unencrypted_regex\E/,
        'decrypt refuses, and the message quotes the pattern';
    like $err, qr/\Qis not a valid Perl regular expression\E/,
        '  naming it as one Perl cannot compile';
    unlike $err, qr/at \S+ line \d+\)/,
        '  and without the inner error carrying its own file and line';
};

###############################################################################
# 2. Interop -- the half that says anything about sops. This is the document
#    sops reads and this library does not.
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- that sops READS a document whose rule neither "
       . "dialect can compile was NOT measured, so the divergence in "
       . "section 1 is pinned against nothing. Run maint/fetch-sops or set "
       . "SOPS_BIN.", 1
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    subtest 'sops reads at exit 0 the very document this library refuses'
        => sub {
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        # The exact bytes decrypt() refused above, on disk for the binary.
        my $doc = injected_document();
        write_bytes("$dir/doc.yaml", $doc);

        my ($out, $code) = run($sops_bin, "-d '$dir/doc.yaml'");
        is $code, 0,
            'sops -d reads the document at exit 0 -- the rule matched nothing';
        like $out, qr/^foo: bar$/m,
            '  handing back the first value in plaintext';
        like $out, qr/^baz: qux$/m,
            '  and the second, where File::SOPS->decrypt refused the whole file';

        # And it is the same pattern in both readers' hands: the file sops just
        # read is still the one that names `fo(` when handed to this library.
        like exception {
            File::SOPS->decrypt(
                encrypted  => slurp("$dir/doc.yaml"),
                identities => [ $SECRET ],
            );
        }, qr/\QCannot use '$UNCOMPILABLE' as the unencrypted_regex\E/,
            '  the one-directional divergence: sops reads it, this side refuses';

        # The oracle every "RE2 rejects it" claim rests on: a .sops.yaml
        # path_regex is the one place sops REPORTS the RE2 compile error
        # instead of discarding it. This is WHY `fo(` matches nothing above.
        write_bytes("$dir/.sops.yaml",
              "creation_rules:\n"
            . "  - path_regex: '$UNCOMPILABLE'\n"
            . "    age: $PUBLIC\n");
        write_bytes("$dir/x.yaml", "foo: bar\n");
        my ($oracle, $oracle_code) = run($sops_bin, "-e -i x.yaml", $dir);
        isnt $oracle_code, 0, 'and RE2 rejects the pattern where sops reports it';
        like $oracle, qr/error parsing regexp/,
            '  confirming neither dialect compiles it';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

sub run {
    my ($sops_bin, $args, $cwd) = @_;
    my $prefix = defined $cwd ? "cd '$cwd' && " : '';
    my $out = `$prefix$sops_bin $args 2>&1`;
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

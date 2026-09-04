#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;
use File::Temp qw(tempdir);
use Encode qw(encode_utf8);
use Crypt::Age;

use File::SOPS;
use File::SOPS::Metadata;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k165 -- docs/adr/0065.
#
# docs/adr/0048 closed 28 of the 29 measured (rule, key) disagreements between
# unencrypted_regex / encrypted_regex as Perl matches them and as RE2 matches
# them. Three shapes survive, recorded as Limits there rather than fixed. This
# file pins those three measurements, the chosen behaviour (the limit stands),
# and the proof that ASCII keys under the same rules still decide the way
# both implementations agree.
#
# Shape of each row: the rule is unencrypted_regex, the key is the one whose
# classification disagrees between Perl and RE2, and the ASCII control is the
# same rule over an ASCII key where both implementations agree -- so the limit
# is the (rule, key) pair, not the rule alone.
#
#   shape 1  (?i)^ss$   /  \x{df}    full case folding; ß -> ss here, not there
#   shape 2  ^foo$      /  foo<NL>   Perl's $ is (?=\n?\z), RE2's is \z
#   shape 3  \p{Word}   /  Word      RE2 cannot compile the name; Perl can

my ($PUBLIC, $SECRET) = Crypt::Age->generate_keypair();

###############################################################################
# 1. SHAPE 1 -- full case folding
###############################################################################
subtest 'shape 1 -- (?i)^ss$ / ß: Perl matches, RE2 does not' => sub {
    my $meta = File::SOPS::Metadata->new(unencrypted_regex => '(?i)^ss$');

    # Perl side: the secret-bare direction. The (rule, key) pair says
    # "leave readable" here and "encrypt" at sops.
    is $meta->should_encrypt_path([ "\x{df}" ]), 0,
        '(?i)^ss$ leaves ß READABLE here (Perl full case folding: ß -> ss)';

    # ASCII control keys under the same rule, where both dialects agree:
    # (?i)^ss$ requires two characters, so a single "s" is not matched by
    # either dialect and gets encrypted; "ss" matches both and is bare.
    is $meta->should_encrypt_path([ 's' ]), 1,
        '  and over "s" both dialects agree: ENCRYPT';
    is $meta->should_encrypt_path([ 'ss' ]), 0,
        '  and over "ss" both dialects agree: BARE';

    # The rule itself compiles in /a and is NOT refused by _rule_qr.
    is exception { $meta->_rule_matcher('unencrypted_regex') }, undef,
        'and the rule is not refused for writing';
};

###############################################################################
# 2. SHAPE 2 -- $ before a trailing newline
###############################################################################
subtest 'shape 2 -- ^foo$ / foo<NL>: Perl matches, RE2 does not' => sub {
    my $meta = File::SOPS::Metadata->new(unencrypted_regex => '^foo$');

    # Perl side: the secret-bare direction. Perl's $ is (?=\n?\z), so
    # ^foo$ matches "foo" followed by an optional \n.
    is $meta->should_encrypt_path([ "foo\n" ]), 0,
        '^foo$ leaves "foo<NL>" READABLE here (Perl $ is (?=\n?\z))';

    # ASCII control: "foo" without the trailing newline matches both.
    is $meta->should_encrypt_path([ 'foo' ]), 0,
        '  and over "foo" both dialects agree: BARE';

    # The rule itself is NOT refused by _rule_qr -- ^foo$ compiles in /a
    # and at sops, and ADR 0038 says refusing a rule sops reads back is
    # the wrong answer.
    is exception { $meta->_rule_matcher('unencrypted_regex') }, undef,
        'and the rule is not refused for writing';

    # (?m) makes $ a line boundary on both sides -- the divergence goes
    # away once the pattern asks for it. (?m)^foo$ over foo<NL> is BARE
    # here AND at sops (measured against the binary in section 4), so the
    # ticket's "not under (?m)" is the rewrite would not apply -- the two
    # implementations already agree there.
    my $metam = File::SOPS::Metadata->new(unencrypted_regex => '(?m)^foo$');
    is $metam->should_encrypt_path([ "foo\n" ]), 0,
        'and (?m)^foo$ over "foo<NL>" agrees with RE2: BARE';
};

###############################################################################
# 3. SHAPE 3 -- \p{NAME} with a name RE2 does not have
###############################################################################
subtest 'shape 3 -- \p{Word} / "Word": Perl matches, RE2 rejects the rule' => sub {
    my $meta = File::SOPS::Metadata->new(unencrypted_regex => '\p{Word}');

    # Perl side: the secret-bare direction. \p{Word} compiles here and
    # matches "Word" (any word character); RE2 cannot compile the name
    # -- "invalid character class range" -- so the rule matches nothing
    # there and the value is encrypted.
    is $meta->should_encrypt_path([ 'Word' ]), 0,
        '\p{Word} leaves "Word" READABLE here (Perl has the name)';

    # ASCII control: \p{Word} matches every ASCII word character, so
    # "w" matches here. The control does NOT show the dialects agree,
    # because RE2 still cannot compile the rule -- the rule-level
    # rejection makes the row moot at sops.
    is $meta->should_encrypt_path([ 'w' ]), 0,
        '  and over "w" Perl matches (RE2 still cannot compile the rule)';

    # \p is on the accepted-escapes list in _re2_divergent_construct
    # (ADR 0048 / 0051), and the name "Word" is one Perl has. _rule_qr
    # compiles it without complaint -- which is the limit: we accept \p
    # unconditionally rather than refuse \p{Greek}, which sops takes.
    is exception { $meta->_rule_matcher('unencrypted_regex') }, undef,
        'and \p is on the accepted-escapes list, so the rule is not refused';

    # A name BOTH dialects have -- \p{Lu} -- pins the same-rule-compiles
    # path without the RE2-side rejection. Over an uppercase key, Perl
    # matches and so does RE2 (measured against the binary in section 4).
    my $meta_lu = File::SOPS::Metadata->new(unencrypted_regex => '\p{Lu}');
    is $meta_lu->should_encrypt_path([ 'A' ]), 0,
        '\p{Lu} / "A": Perl matches';
    is $meta_lu->should_encrypt_path([ 'a' ]), 1,
        '  and over "a" Perl does NOT match: ENCRYPT';
};

###############################################################################
# 4. The three shapes, against the binary
###############################################################################
# This half runs sops on the same (rule, key) pairs and reads the document
# to confirm sops's behaviour. It is the cell of the table the ticket
# claims: sops encrypts each of the three rows the Perl half above leaves
# bare.
#
# Skipped (not failed) when no sops binary is found at SOPS_BIN / PATH /
# .sops-bin/sops / /tmp/sops -- without it the Perl-side measurements still
# pin the limit IN THIS DISTRIBUTION, and SOPS_BIN that names a
# non-executable file is still a hard failure.

SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- what sops classifies these keys as was NOT "
       . "measured, so the three shapes above are pinned against nothing "
       . "on the sops side. Run maint/fetch-sops or set SOPS_BIN.", 4
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    my $dir = tempdir(CLEANUP => 1);
    write_bytes("$dir/key.txt", $SECRET);
    local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

    # Shape 1: (?i)^ss$ over ß. sops takes the rule (both dialects compile
    # it) and writes the value encrypted because its simple folding does
    # NOT fold ß -> ss. The key goes on the wire as UTF-8 bytes -- sops
    # parses YAML as UTF-8, so the latin-1 0xDF byte would not parse.
    my $key_ss = "\x{df}";
    my $file1 = "$dir/shape1.yaml";
    write_bytes($file1, encode_utf8($key_ss) . ": hunter2\n");
    my (undef, $code1) = run($sops_bin,
        sprintf("-e -i --age '%s' --unencrypted-regex %s %s",
            $PUBLIC,
            shell_quote('(?i)^ss$'),
            shell_quote($file1)));
    is $code1, 0, 'sops accepts (?i)^ss$ (shape 1)';
    unlike slurp($file1), qr/hunter2/,
        '  and ENCRYPTS the value under ß -- RE2 does NOT fold ß -> ss';

    # Shape 2: ^foo$ over foo\n. JSON because YAML does not allow a
    # quoted key with an embedded newline. The escape \n in a JSON string
    # is one byte (0x0A), so the in-memory key is 4 chars: f, o, o, 0x0A.
    # RE2's $ is \z and does not match.
    my $file2 = "$dir/shape2.json";
    write_bytes($file2, qq({"foo\\n": "hunter2"}\n));  # bytes: ...\n: ...\n
    # The shell-safe quoting below passes the literal chars to sops as bytes.
    # The JSON parser decodes \\n to 0x0A in-memory, so the key at RE2 is 4
    # bytes: 'f', 'o', 'o', 0x0A.
    my (undef, $code2) = run($sops_bin,
        sprintf("-e -i --age '%s' --input-type json --output-type json --unencrypted-regex %s %s",
            $PUBLIC,
            shell_quote('^foo$'),
            shell_quote($file2)));
    is $code2, 0, 'sops accepts ^foo$ (shape 2)';
    unlike slurp($file2), qr/hunter2/,
        '  and ENCRYPTS the value under foo<NL> -- RE2 $ is \\z, not (?=\n?\\z)';

    # Shape 3: \p{Word} over Word. RE2 rejects the rule with "invalid
    # character class range" -- sops discards the compile error, the rule
    # matches nothing, and the value is encrypted.
    my $file3 = "$dir/shape3.yaml";
    write_bytes($file3, "Word: hunter2\n");
    my (undef, $code3) = run($sops_bin,
        sprintf("-e -i --age '%s' --unencrypted-regex %s %s",
            $PUBLIC,
            shell_quote('\\p{Word}'),
            shell_quote($file3)));
    is $code3, 0, 'sops accepts \\p{Word} at the command line (shape 3)';
    unlike slurp($file3), qr/hunter2/,
        '  and ENCRYPTS the value under Word -- the rule is RE2-invalid so matches nothing';

    # Control: a rule RE2 takes and that BOTH sides agree on, so the
    # shape of the row above is not just "sops encrypts". \p{Lu} over A
    # leaves A readable on both sides.
    my $file4 = "$dir/control.yaml";
    write_bytes($file4, "A: hunter2\n");
    my (undef, $code4) = run($sops_bin,
        sprintf("-e -i --age '%s' --unencrypted-regex %s %s",
            $PUBLIC,
            shell_quote('\\p{Lu}'),
            shell_quote($file4)));
    is $code4, 0, 'sops accepts \\p{Lu} (control)';
    like slurp($file4), qr/^A: hunter2$/m,
        '  and leaves the value under A readable -- both dialects agree';
}

done_testing;

###############################################################################
# Helpers
###############################################################################

sub shell_quote {
    my ($string) = @_;
    $string =~ s/'/'\\''/g;
    return "'$string'";
}

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

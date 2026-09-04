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

# k161 -- docs/adr/0048.
#
# unencrypted_regex and encrypted_regex are matched HERE with Perl and in sops
# with Go's RE2, and those are not the same dialect. RE2's \w, \d, \s, \b and
# POSIX classes are ASCII-only for every subject; Perl's are Unicode-aware for
# any string carrying the UTF-8 flag, which is every non-ASCII key our parsers
# produce. Measured against sops 3.13.3 before this landed, over one ordinary
# .sops.yaml with `unencrypted_regex: ^\w+$` and no hand editing anywhere:
#
#     sops encrypts `café`.  This library left it BARE.
#
# Not only on rotate -- on the caller's own `encrypt`. That is what makes it a
# defect of its own rather than the reachability half of k150: a user gets
# an encrypted secret from sops and a readable one from us, for the same rule
# and the same key.
#
# The second half is a pattern RE2 cannot COMPILE. sops does not report those:
# it discards the compile error, so the rule silently matches nothing. Measured
# (and pinned in the interop half below): `--encrypted-regex '(?=f)foo'` leaves
# every value of the document in PLAINTEXT at exit 0. Neither that nor the
# opposite is a classification that can be reproduced quietly, so such a
# pattern is refused here.

my ($PUBLIC, $SECRET) = Crypt::Age->generate_keypair();

###############################################################################
# 1. The character classes are RE2's, not Perl's
###############################################################################
# Every row was measured against sops 3.13.3: the document is one key and one
# value, `sops -e` with the matching --unencrypted-regex / --encrypted-regex
# flag, and `encrypt` is asked the same question here. 1 means sops produced
# ENC[...] for that key, 0 means sops left the value readable.
my @CLASSES = (
    # unencrypted_regex -- a match means the value stays READABLE
    [ unencrypted_regex => '^\w+$',           "caf\x{e9}",         1, '\w does not reach U+00E9' ],
    [ unencrypted_regex => '^\w+$',           "\x{5bc6}",          1, '\w does not reach U+5BC6' ],
    [ unencrypted_regex => '^\w+$',           'plain',             0, '\w does reach ASCII' ],
    [ unencrypted_regex => '^\w$',            "\x{e9}",            1, '\w, one non-ASCII letter' ],
    [ unencrypted_regex => '^\W$',            "\x{e9}",            0, '\W, the other direction' ],
    [ unencrypted_regex => '^n\d$',           "n\x{663}",          1, '\d does not reach U+0663' ],
    [ unencrypted_regex => '^\d+$',           "\x{663}\x{664}",    1, '\d, two arabic-indic digits' ],
    [ unencrypted_regex => '^\D+$',           "\x{663}\x{664}",    0, '\D, the other direction' ],
    [ unencrypted_regex => '^n\d+$',          'n42',               0, '\d does reach ASCII digits' ],
    [ unencrypted_regex => '^a\sb$',          "a\x{a0}b",          1, '\s does not reach NBSP' ],
    [ unencrypted_regex => '^\s$',            "\x{a0}",            1, '\s, NBSP alone' ],
    [ unencrypted_regex => '^\S$',            "\x{a0}",            0, '\S, the other direction' ],
    [ unencrypted_regex => '\Bfoo$',          "\x{e9}foo",         1, '\B, U+00E9 is not a word char' ],
    [ unencrypted_regex => '\bfoo$',          "\x{e9}foo",         0, '\b, the other direction' ],
    [ unencrypted_regex => '^[[:alpha:]]+$',  "caf\x{e9}",         1, '[:alpha:]' ],
    [ unencrypted_regex => '^[[:alnum:]]+$',  "caf\x{e9}2",        1, '[:alnum:]' ],
    [ unencrypted_regex => '^[[:digit:]]+$',  "\x{663}",           1, '[:digit:]' ],
    [ unencrypted_regex => '^[[:space:]]$',   "\x{a0}",            1, '[:space:]' ],
    [ unencrypted_regex => '^[[:upper:]]+$',  "\x{c9}COLE",        1, '[:upper:]' ],
    [ unencrypted_regex => '^[[:lower:]]+$',  "caf\x{e9}",         1, '[:lower:]' ],
    [ unencrypted_regex => '^[[:punct:]]$',   "\x{ab}",            1, '[:punct:]' ],
    [ unencrypted_regex => '^[[:word:]]+$',   "caf\x{e9}",         1, '[:word:]' ],
    [ unencrypted_regex => '^[[:graph:]]+$',  "caf\x{e9}",         1, '[:graph:]' ],
    [ unencrypted_regex => '^[[:print:]]+$',  "caf\x{e9}",         1, '[:print:]' ],
    [ unencrypted_regex => '^[[:blank:]]$',   "\x{a0}",            1, '[:blank:]' ],
    [ unencrypted_regex => '^[[:xdigit:]]$',  "\x{ff46}",          1, '[:xdigit:], fullwidth f' ],
    [ unencrypted_regex => '^[[:^alpha:]]$',  "\x{e9}",            0, '[:^alpha:], negated' ],
    [ unencrypted_regex => '^[[:alpha:]]+$',  'cafe',              0, '[:alpha:] does reach ASCII' ],

    # (?i) is Unicode-aware in BOTH -- Go folds k to U+212A and s to U+017F,
    # and /a keeps that. /aa would have broken these two rows, which is why
    # the pattern is compiled /a and not /aa.
    [ unencrypted_regex => '(?i)^k$',         "\x{212a}",          0, '(?i) folds k to KELVIN SIGN in both' ],
    [ unencrypted_regex => '(?i)^s$',         "\x{17f}",           0, '(?i) folds s to LONG S in both' ],
    [ unencrypted_regex => "(?i)^\x{e4}\$",   "\x{c4}",            0, '(?i) folds non-ASCII in both' ],

    # /a leaves \p{...} and . alone, and so does RE2.
    [ unencrypted_regex => '^\p{L}+$',        "caf\x{e9}",         0, '\p{L} is Unicode in both' ],
    [ unencrypted_regex => '^.$',             "\x{e9}",            0, '. is one character in both' ],
    [ unencrypted_regex => '^.$',             "\x{1f600}",         0, '. is one astral character in both' ],
    [ unencrypted_regex => '^[^a]$',          "\x{e9}",            0, 'a negated class is not ASCII-folded' ],

    # encrypted_regex -- a match means the value is ENCRYPTED
    [ encrypted_regex   => '^\w+$',           "caf\x{e9}",         0, '\w does not reach U+00E9' ],
    [ encrypted_regex   => '^\w+$',           'plain',             1, '\w does reach ASCII' ],
    [ encrypted_regex   => '^[[:alpha:]]+$',  "caf\x{e9}",         0, '[:alpha:]' ],
    [ encrypted_regex   => '^\W+$',           "caf\x{e9}",         0, '\W' ],
    [ encrypted_regex   => '^\D+$',           "n\x{663}",          1, '\D' ],
);

subtest 'a rule pattern classifies a key the way RE2 classifies it' => sub {
    for my $row (@CLASSES) {
        my ($field, $pattern, $key, $expect, $why) = @$row;

        my $meta = File::SOPS::Metadata->new($field => $pattern);
        is $meta->should_encrypt_path([ $key ]), $expect,
            sprintf('%s %s / %s -- %s', $field, $pattern, u($key), $why);
    }
};

###############################################################################
# 2. And the answer does not depend on the UTF-8 flag
###############################################################################
subtest 'the same key decides the same way whichever way it is stored' => sub {
    # This is the second half of the trap. Perl's /d semantics read the
    # subject's internal UTF-8 flag, so `"caf\x{e9}"` out of a Perl literal
    # (latin-1 storage) used to match ASCII-only and the SAME key out of
    # YAML::XS (flagged) matched Unicode-aware. Reading that flag is what
    # ADR 0003 forbids everywhere else in this distribution -- here the regex
    # engine was reading it for us. /a takes it out of the answer.
    for my $key ("caf\x{e9}", "\x{e9}", "a\x{a0}b", "\x{c9}COLE", "\x{df}") {
        for my $field (qw( unencrypted_regex encrypted_regex )) {
            my $meta = File::SOPS::Metadata->new($field => '^\w+$');

            my $down = $key;
            utf8::downgrade($down);
            my $up = $key;
            utf8::upgrade($up);

            is $meta->should_encrypt_path([ $down ]),
               $meta->should_encrypt_path([ $up ]),
                sprintf('%s %s: latin-1 and UTF-8 storage agree', $field, u($key));
        }
    }
};

###############################################################################
# 3. A construct RE2 cannot compile is refused, and the refusal names it
###############################################################################
# The right-hand column is RE2's own verdict, read off `sops -e` with a
# .sops.yaml whose path_regex is the pattern -- the one place sops reports a
# regex compile error instead of discarding it. All measured on 3.13.3.
my @REFUSED = (
    [ '(?=f)foo'   => qr/a lookahead/,                'invalid or unsupported Perl syntax: `(?=' ],
    [ '(?!x)foo'   => qr/a lookahead/,                'invalid or unsupported Perl syntax: `(?!' ],
    [ 'f(?<=f)oo'  => qr/a lookbehind/,               'invalid named capture' ],
    [ 'f(?<!x)oo'  => qr/a lookbehind/,               'invalid named capture' ],
    [ '(f)o\1'     => qr/a backreference/,            'invalid escape sequence: `\1' ],
    [ '(?>foo)'    => qr/an atomic group/,            'invalid or unsupported Perl syntax: `(?>' ],
    [ 'fo*+o'      => qr/a possessive quantifier/,    'invalid nested repetition operator' ],
    [ 'x{1,2}+'    => qr/a possessive quantifier/,    'invalid nested repetition operator' ],
    [ 'f\Koo'      => qr/the escape \\K/,             'invalid escape sequence: `\K' ],
    [ 'foo\Z'      => qr/the escape \\Z/,             'invalid escape sequence: `\Z' ],
    [ '\Gfoo'      => qr/the escape \\G/,             'invalid escape sequence: `\G' ],
    [ 'f\hoo'      => qr/the escape \\h/,             'invalid escape sequence: `\h' ],
    [ 'f\Roo'      => qr/the escape \\R/,             'invalid escape sequence: `\R' ],
    [ '\N'         => qr/the escape \\N/,             'invalid escape sequence: `\N' ],
    [ '\X'         => qr/the escape \\X/,             'invalid escape sequence: `\X' ],
    [ '\cA'        => qr/the escape \\c/,             'invalid escape sequence: `\c' ],
    [ '\o{17}'     => qr/the escape \\o/,             'invalid escape sequence: `\o' ],
    [ '[\b]'       => qr/\\b inside a character class/,'invalid escape sequence: `\b' ],
    [ '(?#c)foo'   => qr/an inline comment/,          'invalid or unsupported Perl syntax: `(?#' ],
    [ '(?|(f)|(o))oo' => qr/a branch reset/,          'invalid or unsupported Perl syntax: `(?|' ],
    [ "(?'n'foo)"  => qr/\(\?'name'/,                 "invalid or unsupported Perl syntax: `(?'" ],
    [ '(?^i)x'     => qr/a flag reset/,               'invalid or unsupported Perl syntax: `(?^' ],
    [ '(?x) f o o' => qr/the regex flag \(\?x\)/,     'invalid or unsupported Perl syntax: `(?x' ],
    [ '(?a)x'      => qr/the regex flag \(\?a\)/,     'invalid or unsupported Perl syntax: `(?a' ],
    [ '(?R)'       => qr/a subpattern call/,          'invalid or unsupported Perl syntax: `(?R' ],
    [ '(?P=n)'     => qr/a backreference/,            'invalid or unsupported Perl syntax: `(?P' ],
);

# The other kind: both dialects compile it and read it as different things.
my @REFUSED_DIFFERENT = (
    [ '\v'         => qr/the escape \\v/ ],
    [ '\Qa.b\E'    => qr/the escape \\Q/ ],
    [ 'a\E'        => qr/the escape \\E/ ],
);

subtest 'a pattern RE2 cannot compile is refused for WRITING' => sub {
    # This subtest asked should_encrypt_path until k171, because until
    # then the refusal WAS the match. docs/adr/0051 splits the two: sops reads
    # such a rule as matching nothing, which is reproducible, so the read path
    # reproduces it and only the write path refuses. The refusal, its wording
    # and every row below are unchanged -- what moved is which call raises it.
    # The read half of the same split is t/66.
    for my $row (@REFUSED) {
        my ($pattern, $names, $re2) = @$row;

        for my $field (qw( unencrypted_regex encrypted_regex )) {
            my $err = exception {
                File::SOPS::Metadata->new($field => $pattern)
                    ->assert_rule_regexes_agree;
            };

            like $err, qr/\QCannot use '$pattern' as the $field\E/,
                "$field $pattern: refused, and the message quotes the pattern";
            like $err, $names, '  and names the construct';
            like $err, qr/silently matches NOTHING/,
                '  and says what sops does with it instead';
        }
    }

    for my $row (@REFUSED_DIFFERENT) {
        my ($pattern, $names) = @$row;

        my $err = exception {
            File::SOPS::Metadata->new(unencrypted_regex => $pattern)
                ->should_encrypt_path([ 'foo' ]);
        };

        like $err, $names, "$pattern: refused";
        like $err, qr/read DIFFERENTLY/,
            '  as a construct both dialects take and disagree about';
    }
};

subtest 'a pattern PERL cannot compile is refused with the reason' => sub {
    # The other direction, and it exists: (?U) is an RE2 flag and not a Perl
    # one. Before this it died out of the tree walk with a bare regex error.
    for my $pattern ('(?U)fo+', 'fo(') {
        my $err = exception {
            File::SOPS::Metadata->new(unencrypted_regex => $pattern)
                ->should_encrypt_path([ 'foo' ]);
        };

        like $err, qr/\Qis not a valid Perl regular expression\E/,
            "$pattern: refused";
        like $err, qr/\(.+\)/, '  with the reason in it';
        unlike $err, qr/at \S+ line \d+\)/,
            '  and without the inner error carrying its own file and line';
    }
};

###############################################################################
# 4. Nothing that is in both dialects is refused
###############################################################################
subtest 'the constructs both dialects have still work' => sub {
    # Every one of these is `ok` at RE2, measured through the same path_regex
    # oracle. A guard that refused any of them would refuse a rule sops takes.
    for my $pattern ('^\w+$', '^[[:alpha:]]+$', '^[[:^alpha:]]+$', '\p{L}+',
                     '\pL', '\P{L}', '(?i:x)', '(?i)x', '(?m)^x$', '(?s)x.y',
                     '(?-i)x', '(?i-s:x)', '(?P<n>foo)', '(?<n>foo)',
                     '(?:foo)', 'foo|bar', '[*+]', '[(?=)]', '[\\\\]Z',
                     'a\\\\Zb', 'x{1,2}?', '[a-z]+?', '\017', '\x{263a}',
                     '\-', 'a{,3}', 'foo\$', '\A\w+\z', '[\w-]', '[^]]x',
                     'foo[]]bar', '^(api_key|password|tokens)$') {
        is exception {
            File::SOPS::Metadata->new(unencrypted_regex => $pattern)
                ->should_encrypt_path([ 'foo' ]);
        }, undef, "$pattern: taken";
    }
};

###############################################################################
# 5. An ASCII rule over ASCII keys does not move
###############################################################################
subtest 'the ordinary case is untouched' => sub {
    # The corpus this change had to leave alone. Every rule pattern the test
    # suite carries, over ordinary keys.
    my @ORDINARY = (
        [ unencrypted_regex => '^public_',  'public_host',  0 ],
        [ unencrypted_regex => '^public_',  'password',     1 ],
        [ unencrypted_regex => '^pub',      'pub',          0 ],
        [ unencrypted_regex => '.',         'anything',     0 ],
        [ unencrypted_regex => '^nothing$', 'api_key',      1 ],
        [ encrypted_regex   => '^secret_',  'secret_token', 1 ],
        [ encrypted_regex   => '^secret_',  'host',         0 ],
        [ encrypted_regex   => '^sec',      'sec',          1 ],
        [ encrypted_regex   => '^(api_key|password|tokens)$', 'password', 1 ],
        [ encrypted_regex   => '^(api_key|password|tokens)$', 'note',     0 ],
        [ encrypted_regex   => '^nothing$', 'api_key',      0 ],
    );

    for my $row (@ORDINARY) {
        my ($field, $pattern, $key, $expect) = @$row;
        my $meta = File::SOPS::Metadata->new($field => $pattern);
        is $meta->should_encrypt_path([ $key ]), $expect,
            "$field $pattern / $key";
    }

    # A rule is evaluated against EVERY component of the path, and that did
    # not change either.
    my $meta = File::SOPS::Metadata->new(unencrypted_regex => '^public_');
    is $meta->should_encrypt_path([ 'public_block', 'password' ]), 0,
        'a component above the leaf still excludes the leaf';
    is $meta->should_encrypt_path([ 'db', 'password' ]), 1,
        'and an unrelated path is still encrypted';
};

###############################################################################
# 6. Interop -- the only half that says anything about sops
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- what sops classifies these keys as was NOT "
       . "measured, so the table above is pinned against nothing. Run "
       . "maint/fetch-sops or set SOPS_BIN.", 3
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    subtest 'the ticket, end to end: one .sops.yaml, sops -e, then us' => sub {
        # No hand-edited metadata anywhere. An ordinary config, an ordinary
        # encrypt on each side, and the same two keys.
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        write_bytes("$dir/.sops.yaml",
              "creation_rules:\n"
            . "  - path_regex: \\.yaml\$\n"
            . "    age: $PUBLIC\n"
            . "    unencrypted_regex: '^\\w+\$'\n");

        my $plain = encode_utf8("\x{e9}cole") . ": hunter2\n"
                  . "plain: keepme\n";

        # sops searches for .sops.yaml upward from the WORKING DIRECTORY,
        # where creation_rules_for searches upward from the file -- ADR 0007.
        # So this half has to be run from the directory holding the config.
        write_bytes("$dir/theirs.yaml", $plain);
        my (undef, $code) = run($sops_bin, "-e -i theirs.yaml", $dir);
        is $code, 0, 'sops encrypts under the config';

        # The document is bytes, and the key sorts AFTER `sops` in both
        # emitters, so the leaf has to be found by its own line rather than by
        # splitting the metadata block off.
        my $key = encode_utf8("\x{e9}cole");

        my $theirs = slurp("$dir/theirs.yaml");
        like $theirs, qr/^\Q$key\E: ENC\[AES256_GCM/m,
            'and the non-ASCII key is one of the values it encrypted';
        unlike $theirs, qr/hunter2/,
            '  -- sops does NOT leave it readable, its \w is ASCII-only';
        like $theirs, qr/^plain: keepme$/m,
            '  while the ASCII key is left readable';

        # The same document, the same config, through this distribution.
        write_bytes("$dir/ours.yaml", $plain);
        my %args = File::SOPS->creation_rules_for(file => "$dir/ours.yaml");
        is $args{unencrypted_regex}, '^\w+$',
            'creation_rules_for hands the rule over unchanged';

        File::SOPS->encrypt_in_place(file => "$dir/ours.yaml", %args);

        my $ours = slurp("$dir/ours.yaml");
        unlike $ours, qr/hunter2/,
            'and OUR document does not carry the secret in plaintext either';
        like $ours, qr/^\Q$key\E: ENC\[AES256_GCM/m,
            '  the value under the non-ASCII key is encrypted';
        like $ours, qr/^plain: keepme$/m,
            '  and the ASCII key is left readable, exactly as at sops';

        my (undef, $read) = run($sops_bin, "-d '$dir/ours.yaml'");
        is $read, 0, 'sops reads the document we wrote';
    };

    subtest 'the class table, against the binary' => sub {
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        my %flag = (
            unencrypted_regex => '--unencrypted-regex',
            encrypted_regex   => '--encrypted-regex',
        );

        for my $row (@CLASSES) {
            my ($field, $pattern, $key, $expect, $why) = @$row;

            my $file = "$dir/probe.yaml";
            write_bytes($file, encode_utf8($key) . ": hunter2\n");

            # The pattern goes over the command line as BYTES, exactly like
            # the key goes into the file as bytes.
            my (undef, $code) = run($sops_bin, sprintf("-e -i --age '%s' %s %s %s",
                $PUBLIC, $flag{$field}, shell_quote(encode_utf8($pattern)),
                shell_quote($file)));
            is $code, 0,
                sprintf('sops encrypts under %s %s / %s',
                        $field, u($pattern), u($key));

            # The one data value is `hunter2`. Still there means sops left the
            # leaf readable. Splitting the document at the `sops:` line does
            # NOT work: both emitters sort keys, so a non-ASCII key sorts
            # after `sops` and lands below the metadata block.
            my $bare = slurp($file) =~ /hunter2/ ? 0 : 1;
            is $bare, $expect, "  and this side agrees with it -- $why";
        }
    };

    subtest 'what sops does with a pattern RE2 cannot compile' => sub {
        # This is the measurement the refusal rests on. sops does not report
        # the compile error, so the rule matches nothing -- which for an
        # encrypted_regex means the whole document goes to disk in PLAINTEXT
        # under a sops section that makes it look encrypted, at exit 0.
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        my $file = "$dir/broken.yaml";
        write_bytes($file, "foo: hunter2\nbar: pw\n");
        my (undef, $code) = run($sops_bin,
            "-e -i --age '$PUBLIC' --encrypted-regex '(?=f)foo' '$file'");
        is $code, 0, 'sops takes an encrypted_regex RE2 cannot compile';
        like slurp($file), qr/^foo: hunter2$/m,
            '  and writes every value in PLAINTEXT under a sops section';

        write_bytes($file, "foo: hunter2\nbar: pw\n");
        (undef, $code) = run($sops_bin,
            "-e -i --age '$PUBLIC' --unencrypted-regex '(?=f)foo' '$file'");
        is $code, 0, 'and it takes an unencrypted_regex it cannot compile';
        unlike slurp($file), qr/hunter2/,
            '  encrypting every value instead -- the rule matched nothing';

        # The one path where sops DOES report it, which is the oracle every
        # row of @REFUSED was read off.
        write_bytes("$dir/.sops.yaml",
              "creation_rules:\n"
            . "  - path_regex: '(?=f)foo'\n"
            . "    age: $PUBLIC\n");
        write_bytes("$dir/x.yaml", "foo: hunter2\n");
        my ($out, $config_code) = run($sops_bin, "-e -i x.yaml", $dir);
        isnt $config_code, 0, 'in a .sops.yaml path_regex it is reported';
        like $out, qr/error parsing regexp/,
            '  which is how RE2 verdicts were measured for the table above';
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# A key, printable in a test name on any terminal.
sub u {
    my ($string) = @_;
    return join '', map {
        ord($_) < 128 ? $_ : sprintf('U+%04X', ord($_))
    } split //, $string;
}

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

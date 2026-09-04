#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;
use File::Temp qw(tempdir);
use Crypt::Age;

use File::SOPS;
use File::SOPS::Metadata;
use lib 't/lib';
use SopsBin qw(find_sops_bin);

# k171 and k166 -- docs/adr/0051.
#
# docs/adr/0048 refuses a rule regex the two dialects do not share, AT THE
# POINT OF USE, and listed decrypt and extract as paths that stay open because
# neither consulted the rule. docs/adr/0049 made _decrypt_tree consult it, and
# the refusal reached the read path with it.
#
# Measured against sops 3.13.3 (pinned in section 5 below): a document whose
# sops section carries `unencrypted_regex: "(?=foo)"` is written AND read by
# sops at exit 0. RE2 cannot compile the pattern, sops discards the compile
# error, and the rule silently matches NOTHING -- so every value is selected
# and every value is decrypted. `--encrypted-regex '(?=f)foo'` is the same
# answer pointing the other way: nothing is selected, and every value goes to
# disk in plaintext.
#
# That answer is REPRODUCIBLE, and the read path reproduces it. The write path
# does not, and that is docs/adr/0048's decision standing where it was put:
# a caller who asks for a rule and is given "matches nothing" gets a document
# whose every secret is readable, at exit 0.
#
# The split this file pins is by what RE2 does with the pattern, not by what
# Perl does with it:
#
#   RE2 cannot compile it       -> matches nothing. Read path passes.
#   both compile, read it apart -> refused everywhere (\v, \Q..\E).
#   Perl cannot compile it      -> refused everywhere ((?U) -- and ONLY (?U);
#                                  see the note in section 4).

my ($PUBLIC, $SECRET) = Crypt::Age->generate_keypair();

# The one pattern the whole file turns on. RE2's own verdict on it was read
# off a .sops.yaml path_regex -- the one place sops reports a compile error
# instead of discarding it -- and is pinned in t/62.
my $UNCOMPILABLE = '(?=foo)';

###############################################################################
# 1. The read path reads it the way sops reads it: the rule matches NOTHING
###############################################################################
# Neither fixture is hand-built. Each is written by encrypt() under a rule
# that classifies exactly as "matches nothing" does, and then has that rule
# field replaced -- the whole of what a hand-edited section, or a .sops.yaml
# that has moved on, amounts to. The classification and therefore the MAC are
# untouched by the swap, which is what makes the document a valid one.
#
#   unencrypted_regex   matches nothing -> nothing is EXCLUDED -> all encrypted
#   encrypted_regex     matches nothing -> nothing is SELECTED -> all literal
#
# and both are what sops produced for the same flags, measured in section 5.

sub all_encrypted_document {
    my $doc = File::SOPS->encrypt(
        data       => { foo => 'topsecret', bar => 'hunter2' },
        recipients => [ $PUBLIC ],
    );
    # The default rule. It excludes nothing here, exactly as the swapped-in
    # pattern excludes nothing at sops.
    $doc =~ s/^(\s*)unencrypted_suffix: _unencrypted$/$1unencrypted_regex: "$UNCOMPILABLE"/m
        or die 'fixture: no unencrypted_suffix line to replace';
    return $doc;
}

sub all_literal_document {
    my $doc = File::SOPS->encrypt(
        data             => { foo => 'topsecret', bar => 'hunter2' },
        recipients       => [ $PUBLIC ],
        encrypted_regex  => '^nothing$',
    );
    $doc =~ s/^(\s*)encrypted_regex: \^nothing\$$/$1encrypted_regex: "$UNCOMPILABLE"/m
        or die 'fixture: no encrypted_regex line to replace';
    return $doc;
}

subtest 'decrypt reads a document whose rule RE2 cannot compile' => sub {
    my $doc = all_encrypted_document();

    like $doc, qr/\Qunencrypted_regex: "$UNCOMPILABLE"\E/,
        'the fixture really carries the pattern sops cannot compile';
    unlike $doc, qr/topsecret/, '  and its values really are encrypted';

    my $data;
    is exception {
        $data = File::SOPS->decrypt(
            encrypted  => $doc,
            identities => [ $SECRET ],
        );
    }, undef, 'decrypt goes through instead of refusing the rule';

    is $data->{foo}, 'topsecret',
        '  returning the value, where sops returns it at exit 0';
    is $data->{bar}, 'hunter2', '  and the second one too';
};

subtest 'extract reads one value out of the same document' => sub {
    my $dir = tempdir(CLEANUP => 1);
    write_bytes("$dir/doc.yaml", all_encrypted_document());

    my $value;
    is exception {
        $value = File::SOPS->extract(
            file       => "$dir/doc.yaml",
            path       => '["foo"]',
            identities => [ $SECRET ],
        );
    }, undef, 'extract goes through instead of refusing the rule';
    is $value, 'topsecret', '  and answers with the value';
};

subtest 'decrypt_file reads it, and writes the plaintext out' => sub {
    my $dir = tempdir(CLEANUP => 1);
    write_bytes("$dir/doc.yaml", all_encrypted_document());

    is exception {
        File::SOPS->decrypt_file(
            input      => "$dir/doc.yaml",
            output     => "$dir/plain.yaml",
            identities => [ $SECRET ],
        );
    }, undef, 'decrypt_file goes through';

    my $out = -e "$dir/plain.yaml" ? slurp("$dir/plain.yaml")
                                   : '(decrypt_file wrote nothing)';
    like $out, qr/^foo: topsecret$/m, '  and the value is in the file it wrote';
};

subtest 'the other direction: nothing is selected, so every leaf is a literal'
    => sub {
    # `encrypted_regex` matching nothing is the half that costs a secret on
    # the WRITE path, and on the read path it is simply a document whose
    # values are all literal -- which is what sops wrote for the same flag.
    my $doc = all_literal_document();

    like $doc, qr/^foo: topsecret$/m,
        'the fixture holds every value in plaintext, as sops writes it';

    my $data;
    is exception {
        $data = File::SOPS->decrypt(
            encrypted  => $doc,
            identities => [ $SECRET ],
        );
    }, undef, 'and decrypt goes through here too';

    is $data->{foo}, 'topsecret', '  reading the literal back';
    is $data->{bar}, 'hunter2',   '  including the MAC over it';
};

###############################################################################
# 2. The write path still refuses -- docs/adr/0048's decision, where it was put
###############################################################################
subtest 'encrypt refuses to write under a rule that would match nothing' => sub {
    for my $field (qw( unencrypted_regex encrypted_regex )) {
        my $err = exception {
            File::SOPS->encrypt(
                data       => { foo => 'topsecret' },
                recipients => [ $PUBLIC ],
                $field     => $UNCOMPILABLE,
            );
        };

        like $err, qr/\QCannot use '$UNCOMPILABLE' as the $field\E/,
            "$field: refused, and the message quotes the pattern";
        like $err, qr/silently matches NOTHING/,
            '  and says what sops does with it instead';
    }
};

subtest 'every method that writes a document refuses it' => sub {
    my $dir = tempdir(CLEANUP => 1);

    write_bytes("$dir/in.yaml", "foo: topsecret\n");
    like exception {
        File::SOPS->encrypt_file(
            input             => "$dir/in.yaml",
            output            => "$dir/out.yaml",
            recipients        => [ $PUBLIC ],
            unencrypted_regex => $UNCOMPILABLE,
        );
    }, qr/silently matches NOTHING/, 'encrypt_file refuses';
    ok !-e "$dir/out.yaml", '  and wrote nothing';

    write_bytes("$dir/place.yaml", "foo: topsecret\n");
    like exception {
        File::SOPS->encrypt_in_place(
            file              => "$dir/place.yaml",
            recipients        => [ $PUBLIC ],
            unencrypted_regex => $UNCOMPILABLE,
        );
    }, qr/silently matches NOTHING/, 'encrypt_in_place refuses';
    is slurp("$dir/place.yaml"), "foo: topsecret\n", '  and left the file alone';

    # rotate and edit carry the DOCUMENT's rule rather than the caller's, and
    # they generate a new data key -- so they are writes, and they refuse
    # after a read that now goes through.
    my $doc = all_encrypted_document();
    write_bytes("$dir/rot.yaml", $doc);
    like exception {
        File::SOPS->rotate(file => "$dir/rot.yaml", identities => [ $SECRET ]);
    }, qr/silently matches NOTHING/, 'rotate refuses';
    is slurp("$dir/rot.yaml"), $doc, '  and left the document byte for byte';

    write_bytes("$dir/ed.yaml", $doc);
    like exception {
        File::SOPS->edit(
            file       => "$dir/ed.yaml",
            identities => [ $SECRET ],
            editor     => 'true',
        );
    }, qr/silently matches NOTHING/, 'edit refuses';
    is slurp("$dir/ed.yaml"), $doc, '  and left the document byte for byte';
};

###############################################################################
# 3. k166 -- the refusal is about the RULE, so it names no leaf
###############################################################################
subtest 'the refusal does not come out under some leaf path' => sub {
    # It was raised inside the leaf walk, from _assert_leaves_representable's
    # eval, which re-threw it with _at_path. The message came out as
    # `bar: Cannot use ...` -- `bar` being whichever key the walk reached
    # first, and nothing whatever to do with the rule.
    for my $field (qw( unencrypted_regex encrypted_regex )) {
        my $err = exception {
            File::SOPS->encrypt(
                data       => { foo => 'topsecret', bar => 'hunter2' },
                recipients => [ $PUBLIC ],
                $field     => $UNCOMPILABLE,
            );
        };

        like $err, qr/\ACannot use /,
            "$field: the message starts at the rule";
        unlike $err, qr/\A(?:foo|bar):/,
            '  and not under a leaf it has nothing to do with';
    }

    # Same for a pattern PERL cannot compile, which reached the same eval.
    my $err = exception {
        File::SOPS->encrypt(
            data              => { foo => 'topsecret', bar => 'hunter2' },
            recipients        => [ $PUBLIC ],
            unencrypted_regex => '(?U)fo+',
        );
    };
    like $err, qr/\ACannot use /, 'and for one Perl cannot compile';
};

###############################################################################
# 4. What the read path does NOT reproduce stays refused
###############################################################################
# The split is by RE2's verdict. These are the patterns RE2 COMPILES -- so the
# rule really does select keys over there -- and Perl either reads them
# differently or cannot compile them at all. There is no answer to reproduce.
subtest 'a pattern both dialects read differently is still refused on read'
    => sub {
    for my $pattern ('\v', '\Qa.b\E', 'a\E') {
        my $doc = document_with_rule(unencrypted_regex => $pattern);

        my $err = exception {
            File::SOPS->decrypt(encrypted => $doc, identities => [ $SECRET ]);
        };

        like $err, qr/read DIFFERENTLY/,
            "$pattern: decrypt still refuses it";
    }
};

subtest 'a pattern PERL cannot compile is still refused on read' => sub {
    # (?U) is the only pattern measured to be RE2-OK and Perl-reject. \C, \g
    # and \k are named beside it in docs/adr/0048 and do not belong there:
    # measured on 3.13.3 through the path_regex oracle, RE2 rejects all three
    # (`invalid escape sequence`), so they are the lenient kind. k175.
    for my $pattern ('(?U)fo+') {
        my $doc = document_with_rule(unencrypted_regex => $pattern);

        my $err = exception {
            File::SOPS->decrypt(encrypted => $doc, identities => [ $SECRET ]);
        };

        like $err, qr/\Qis not a valid Perl regular expression\E/,
            "$pattern: decrypt still refuses it";
    }
};

subtest 'and extract refuses the same two kinds' => sub {
    my $dir = tempdir(CLEANUP => 1);

    for my $row ([ '\v' => qr/read DIFFERENTLY/ ],
                 [ '(?U)fo+' => qr/not a valid Perl regular expression/ ]) {
        my ($pattern, $names) = @$row;
        write_bytes("$dir/x.yaml", document_with_rule(unencrypted_regex => $pattern));

        like exception {
            File::SOPS->extract(
                file       => "$dir/x.yaml",
                path       => '["foo"]',
                identities => [ $SECRET ],
            );
        }, $names, "extract refuses $pattern";
    }
};

###############################################################################
# 5. Interop -- the measurement everything above rests on
###############################################################################
SKIP: {
    my $sops_bin = find_sops_bin();
    skip "No sops binary found (checked \$SOPS_BIN, PATH, .sops-bin/sops, "
       . "/tmp/sops) -- that sops reads a document whose rule RE2 cannot "
       . "compile was NOT measured, so section 1 is pinned against "
       . "nothing. Run maint/fetch-sops or set SOPS_BIN.", 1
        unless $sops_bin;

    diag("Using sops binary: $sops_bin");

    subtest 'sops writes it, sops reads it, and so do we' => sub {
        my $dir = tempdir(CLEANUP => 1);
        write_bytes("$dir/key.txt", $SECRET);
        local $ENV{SOPS_AGE_KEY_FILE} = "$dir/key.txt";

        # Both directions of the same silence. The unencrypted_regex half
        # leaves an ordinary encrypted document behind; the encrypted_regex
        # half leaves every value in plaintext, which is why the write path
        # refuses both.
        my %expect_bare = (
            '--unencrypted-regex' => 0,
            '--encrypted-regex'   => 1,
        );

        for my $flag (sort keys %expect_bare) {
            my $file = "$dir/probe.yaml";
            write_bytes($file, "foo: topsecret\nbar: hunter2\n");

            my (undef, $code) = run($sops_bin,
                "-e -i --age '$PUBLIC' $flag '$UNCOMPILABLE' '$file'");
            is $code, 0, "sops encrypts under $flag '$UNCOMPILABLE'";

            my $bare = slurp($file) =~ /topsecret/ ? 1 : 0;
            is $bare, $expect_bare{$flag},
                sprintf('  and the rule matched nothing -- values %s',
                        $expect_bare{$flag} ? 'left in PLAINTEXT' : 'encrypted');

            my (undef, $read) = run($sops_bin, "-d '$file'");
            is $read, 0, '  sops reads its own document back at exit 0';

            # The whole ticket: the same file, through this library.
            my $data;
            is exception {
                $data = File::SOPS->decrypt(
                    encrypted  => slurp($file),
                    identities => [ $SECRET ],
                );
            }, undef, '  and so do we';
            is $data->{foo}, 'topsecret', '  every value of it';
            is $data->{bar}, 'hunter2',   '  the second one included';
        }
    };
}

done_testing;

###############################################################################
# Helpers
###############################################################################

# An all-encrypted document carrying $pattern in $field. Built the same way as
# the fixtures above -- encrypt under the default rule, then swap the field --
# because encrypt() refuses to write any of these patterns, which is section 2.
sub document_with_rule {
    my ($field, $pattern) = @_;

    my $doc = File::SOPS->encrypt(
        data       => { foo => 'topsecret', bar => 'hunter2' },
        recipients => [ $PUBLIC ],
    );
    my $quoted = $pattern;
    $quoted =~ s/(["\\])/\\$1/g;
    $doc =~ s/^(\s*)unencrypted_suffix: _unencrypted$/$1$field: "$quoted"/m
        or die 'fixture: no unencrypted_suffix line to replace';
    return $doc;
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

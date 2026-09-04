#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Config;
use POSIX ();
use File::Temp qw(tempdir);
use File::Spec;
use YAML::XS ();
use Scalar::Util qw(refaddr);

use File::SOPS;
use File::SOPS::Format::YAML;
use Crypt::Age;

# k112 / docs/adr/0027 -- an ACYCLIC alias bomb.
#
# The other half of k110. A document whose aliases are shared but not
# recursive is legitimately acyclic, so _assert_acyclic correctly does not
# fire, and the walks below it expand every alias -- as they must, because
# sops expands them too -- into a tree with 2**N leaves. Measured before the
# guard: 25 levels, 727 bytes of YAML, encrypt_file did not return.
#
# HOW THIS FILE STAYS BOUNDED, and why it is not simply t/41's technique.
#
# t/41 bounds its regression by dying on the first "Deep recursion" warning.
# That net is blind here. k110's runaway was unbounded DEPTH -- a cycle,
# so perl's threshold of 100 was crossed in microseconds. k112's runaway
# is unbounded BREADTH at BOUNDED depth: a 25-level bomb never recurses past
# 27, so the warning is never raised and only a timeout would end it, after
# the walk had climbed about a gigabyte of RSS every three seconds.
#
# So the bound here is the fixture, in three steps:
#
#   1. A cheap probe calls the guard directly. It is O(the DAG), 27 nodes, and
#      cannot hang whatever else is broken. If the guard itself is gone,
#      everything that would expand is skipped rather than run.
#   2. Every entry point is then exercised with a bomb sized just past the
#      threshold -- 9 levels, 8,146 expanded values. If a CALL SITE is missing
#      the call SUCCEEDS, in about 60ms, and the assertion goes red on the
#      spot. No timeout, no memory.
#   3. The 25-level bomb appears only where the point IS the hang, and those
#      cases run in a forked child under an alarm.
#
# Both regressions were rehearsed rather than assumed. With the two call sites
# removed this file reports 20 of 39 failures in 16s; with the guard's body
# removed, 25 of 39 in 14s. Neither hangs and neither thrashes.

plan skip_all => 'this test forks to bound a regression, and fork is not '
    . 'available here'
    unless $Config{d_fork};

my $TIMEOUT = 5;

# Runs $code in a child under alarm. Returns 'OK', "DIE <message>", or 'HANG'.
sub guarded {
    my ($code) = @_;

    pipe(my $read, my $write) or die "pipe: $!";

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if (!$pid) {
        close $read;
        local $SIG{ALRM} = sub {
            print {$write} "HANG\n";
            close $write;
            # _exit, never exit: exit would run Test::More's END block in the
            # child and emit a second, duplicate TAP plan.
            POSIX::_exit(0);
        };
        alarm $TIMEOUT;
        my $ok  = eval { $code->(); 1 };
        my $err = $ok ? '' : $@;
        alarm 0;
        $err =~ s/\s+/ /g;
        print {$write} ($ok ? "OK\n" : "DIE $err\n");
        close $write;
        POSIX::_exit(0);
    }

    close $write;
    my $line = <$read>;
    close $read;
    waitpid $pid, 0;

    $line = 'HANG' unless defined $line;
    chomp $line;
    return $line;
}

my ($public, $secret) = Crypt::Age->generate_keypair();

# Depth $levels of doubling. 25 levels is 727 bytes of YAML and 2**25 leaves
# once expanded; 9 levels is the smallest one sops refuses.
sub bomb_yaml {
    my ($levels) = @_;
    my $y = "l0: &l0\n  v: 1\n";
    $y .= "l$_: &l$_\n  a: *l@{[$_ - 1]}\n  b: *l@{[$_ - 1]}\n"
        for 1 .. $levels;
    return $y;
}

my $BOMB     = bomb_yaml(9);    # refused, and harmless if it is not
my $BIG_BOMB = bomb_yaml(25);   # the document that used to never come back

# ---------------------------------------------------------------------------
# The premise, pinned. The whole design rests on this: YAML::XS resolves an
# alias to the SAME reference rather than to a copy, so the parse returns a
# linear DAG and does NOT explode. If it ever started copying, the expansion
# would happen inside Load, no guard of ours could reach it, and the answer
# would have to be a pre-check on the raw bytes instead.

my $parsed = YAML::XS::Load($BIG_BOMB);
is(refaddr($parsed->{l1}{a}), refaddr($parsed->{l1}{b}),
    'YAML::XS resolves an alias to the same reference, not to a copy');
is(refaddr($parsed->{l1}{a}), refaddr($parsed->{l0}),
    'and that reference is the anchored node itself');

is(guarded(sub { File::SOPS::Format::YAML->parse($BIG_BOMB) }), 'OK',
    'the parse itself still returns: the blowup is in the walks, not the load');

# ---------------------------------------------------------------------------
# Step 1: the probe. Everything below depends on the guard existing at all.

my $guard_holds = do {
    my $ok = eval {
        File::SOPS::_assert_expansion_bounded(YAML::XS::Load($BIG_BOMB));
        1;
    };
    !$ok && $@ =~ /excessive aliasing/;
};
ok($guard_holds, '_assert_expansion_bounded refuses a 25-level alias bomb');

# Asserts that $code refuses. With the guard in place this is instant; with a
# call site missing it succeeds in milliseconds and fails here, because the
# fixture is sized so that expanding it is cheap.
sub refuses {
    my ($name, $code) = @_;
    unless ($guard_holds) {
        fail("$name refuses an alias bomb");
        diag('SKIPPED the call: _assert_expansion_bounded is gone, so this '
            . 'would expand 2**N values. See k112 and docs/adr/0027.');
        return;
    }
    my $ok = eval { $code->(); 1 };
    my $err = $ok ? '' : $@;
    $err =~ s/\s+/ /g;
    if ($ok) {
        fail("$name refuses an alias bomb");
        diag('RETURNED instead of refusing -- the guard exists but this entry '
            . 'point no longer calls it. This is k112 back again.');
        return;
    }
    like($err, qr/excessive aliasing/, "$name refuses an alias bomb")
        or diag("got: $err");
}

# ---------------------------------------------------------------------------
# The encrypt side. Used to expand 2**25 leaves and never come back.

refuses('encrypt', sub {
    File::SOPS->encrypt(
        data       => YAML::XS::Load($BOMB),
        recipients => [$public],
        format     => 'yaml',
    );
});

# JSON has no aliases, but a caller can hand encrypt a shared structure of
# their own. Same blowup, no parser anywhere near it, one guard for both.
refuses('encrypt (format => json)', sub {
    File::SOPS->encrypt(
        data       => YAML::XS::Load($BOMB),
        recipients => [$public],
        format     => 'json',
    );
});

refuses('encrypt (caller-built shared hash refs)', sub {
    my $node = { v => 1 };
    $node = { a => $node, b => $node } for 1 .. 12;
    File::SOPS->encrypt(
        data       => { root => $node },
        recipients => [$public],
        format     => 'yaml',
    );
});

refuses('encrypt (caller-built shared array refs)', sub {
    my $node = [1];
    $node = [ $node, $node ] for 1 .. 12;
    File::SOPS->encrypt(
        data       => { root => $node },
        recipients => [$public],
        format     => 'yaml',
    );
});

# The reproduction. This is the document from the ticket, and the assertion is
# that it now comes back at all.
{
    my $got = guarded(sub {
        File::SOPS->encrypt(
            data       => YAML::XS::Load($BIG_BOMB),
            recipients => [$public],
            format     => 'yaml',
        );
    });
    if ($got eq 'HANG') {
        fail('encrypt returns on the 25-level bomb from k112');
        diag("HUNG -- did not return within ${TIMEOUT}s, which is the defect.");
    }
    else {
        like($got, qr/\ADIE .*excessive aliasing/,
            'encrypt returns on the 25-level bomb from k112')
            or diag("got: $got");
    }
}

# The message quotes sops's own wording and says how far out of proportion the
# document is, because "too big" without a number is not actionable.
my $msg = do {
    eval {
        File::SOPS->encrypt(
            data       => YAML::XS::Load($BOMB),
            recipients => [$public],
            format     => 'yaml',
        );
    };
    my $e = $@ // ''; $e =~ s/\s+/ /g; $e;
};
like($msg, qr/\Qyaml: document contains excessive aliasing\E/,
    'the refusal quotes the wording sops refuses with');
like($msg, qr/expands to \d+ values from the \d+ it holds/,
    'and names both counts');
like($msg, qr/Reusing an anchor is ordinary and is not this/,
    'and says what is NOT this, so a reused anchor is not read as the defect');

# ---------------------------------------------------------------------------
# The decrypt side. A document sops WROTE cannot carry this, because sops
# refuses to write it -- but a hand-written one can, and that is the document
# every read path used to expand.

my $sane = File::SOPS->encrypt(
    data       => { plain => 'x' },
    recipients => [$public],
    format     => 'yaml',
);

sub bomb_document {
    my ($body) = @_;
    my $doc = $sane;
    $doc =~ s/^plain: .*\n/$body/m or die "splice failed";
    return $doc;
}

my $bomb_doc = bomb_document($BOMB);
isnt($bomb_doc, $sane, 'built an encrypted document carrying an alias bomb');

refuses('decrypt', sub {
    File::SOPS->decrypt(encrypted => $bomb_doc, identities => [$secret]);
});

# ignore_mac suppresses verification, not the document's shape. Before the
# guard this was the path that expanded furthest: it skips _verify_mac and
# walks the whole tree in _decrypt_tree regardless.
refuses('decrypt (ignore_mac => 1)', sub {
    File::SOPS->decrypt(
        encrypted  => $bomb_doc,
        identities => [$secret],
        ignore_mac => 1,
    );
});

# The refusal comes AHEAD of the key, which is the order sops answers in:
# measured, `sops -d` on such a file with no identity available reports the
# aliasing, not a failure to get the data key.
my ($other_public, $other_secret) = Crypt::Age->generate_keypair();
refuses('decrypt (with an identity that cannot open the file)', sub {
    File::SOPS->decrypt(
        encrypted  => $bomb_doc,
        identities => [$other_secret],
    );
});

# The read-side reproduction, at the size that used to hang.
{
    my $big_doc = bomb_document($BIG_BOMB);
    my $got = guarded(sub {
        File::SOPS->decrypt(
            encrypted  => $big_doc,
            identities => [$secret],
            ignore_mac => 1,
        );
    });
    if ($got eq 'HANG') {
        fail('decrypt returns on the 25-level bomb from k112');
        diag("HUNG -- did not return within ${TIMEOUT}s, which is the defect.");
    }
    else {
        like($got, qr/\ADIE .*excessive aliasing/,
            'decrypt returns on the 25-level bomb from k112')
            or diag("got: $got");
    }
}

# ---------------------------------------------------------------------------
# The file entry points, all of which funnel through encrypt or decrypt.

my $dir = tempdir(CLEANUP => 1);
sub in_dir { File::Spec->catfile($dir, $_[0]) }

sub write_file {
    my ($path, $content) = @_;
    open my $fh, '>', $path or die "open $path: $!";
    binmode $fh;
    print {$fh} $content;
    close $fh or die "close $path: $!";
    return $path;
}

my $enc_path = write_file(in_dir('bomb.enc.yaml'), $bomb_doc);

refuses('decrypt_file', sub {
    File::SOPS->decrypt_file(
        input      => $enc_path,
        output     => in_dir('out.yaml'),
        identities => [$secret],
    );
});

refuses('extract', sub {
    File::SOPS->extract(
        file       => $enc_path,
        path       => '["l0"]["v"]',
        identities => [$secret],
    );
});

refuses('rotate', sub {
    File::SOPS->rotate(file => $enc_path, identities => [$secret]);
});

{
    local $ENV{EDITOR} = 'true';
    refuses('edit', sub {
        File::SOPS->edit(file => $enc_path, identities => [$secret]);
    });
}

my $plain_path = write_file(in_dir('bomb.yaml'), $BOMB);
my $out_path   = in_dir('bomb.out.yaml');

refuses('encrypt_file', sub {
    File::SOPS->encrypt_file(
        input      => $plain_path,
        output     => $out_path,
        recipients => [$public],
    );
});
ok(!-e $out_path, 'encrypt_file wrote no output on the refusal');

my $in_place_path = write_file(in_dir('in-place.yaml'), $BOMB);
refuses('encrypt_in_place', sub {
    File::SOPS->encrypt_in_place(file => $in_place_path, recipients => [$public]);
});
is(do { open my $fh, '<', $in_place_path or die; local $/; <$fh> }, $BOMB,
    'encrypt_in_place left the original untouched on the refusal');

# ---------------------------------------------------------------------------
# The two guards are ordered, and the order is load-bearing: the census memo
# in _expansion_census is filled on the way OUT, so a cycle would recurse
# forever inside it. _assert_acyclic runs first, and a cyclic document has to
# keep reporting the cycle. This one runs forked, because getting it wrong is
# a hang.
{
    my $got = guarded(sub {
        File::SOPS->encrypt(
            data       => YAML::XS::Load("root: &a\n  b: *a\n"),
            recipients => [$public],
            format     => 'yaml',
        );
    });
    like($got, qr/\ADIE .*contains itself/,
        'a cyclic document still reports the cycle, not the aliasing')
        or diag("got: $got");
}

# ---------------------------------------------------------------------------
# The guard must not OVER-refuse, and the threshold is not ours: it is
# go-yaml's, reproduced. Bisected against sops 3.13.3, which decides this.
#
# The pair that matters most is the second and the third below. sops ACCEPTS a
# 206,104-node expansion and REFUSES a 8,146-node one, because what it budgets
# is how far the expansion exceeds the document that produced it -- a RATIO,
# not a count. Anyone who "simplifies" this into a cap on expanded nodes
# refuses files sops accepts, and these assertions are what says so.

sub accepts_or_refuses {
    my ($name, $yaml, $want) = @_;
    # A 265-deep DAG legitimately recurses past perl's threshold of 100, and
    # every walk in this distribution does the same on such a document. The
    # warning is muted rather than avoided, so the fixture can sit at the
    # depth sops's boundary actually sits at.
    local $SIG{__WARN__} = sub {
        warn $_[0] unless $_[0] =~ /\ADeep recursion/;
    };
    my $tree = YAML::XS::Load($yaml);
    my $ok = eval { File::SOPS::_assert_expansion_bounded($tree); 1 };
    is($ok ? 'ACCEPT' : 'REFUSE', $want, $name)
        or diag($ok ? 'accepted' : "refused: $@");
}

# Depth $depth, each level referencing the previous $width times, over a base
# anchor of $pairs pairs.
sub chain_yaml {
    my ($depth, $width, $pairs) = @_;
    my $y = "l0: &l0\n";
    $y .= "  k$_: $_\n" for 1 .. $pairs;
    for my $i (1 .. $depth) {
        $y .= "l$i: &l$i\n";
        $y .= "  r$_: *l@{[$i - 1]}\n" for 1 .. $width;
    }
    return $y;
}

# One anchor of $pairs pairs, referenced $refs times.
sub flat_yaml {
    my ($pairs, $refs) = @_;
    my $y = "base: &b\n";
    $y .= "  k$_: $_\n" for 1 .. $pairs;
    $y .= "a$_: *b\n" for 1 .. $refs;
    return $y;
}

accepts_or_refuses('doubling, 8 levels: sops accepts (4,054 expanded)',
    chain_yaml(8, 2, 1), 'ACCEPT');
accepts_or_refuses('doubling, 9 levels: sops refuses (8,146 expanded)',
    chain_yaml(9, 2, 1), 'REFUSE');

accepts_or_refuses('one anchor, 2,000 references: sops accepts (206,104 expanded)',
    flat_yaml(50, 2000), 'ACCEPT');
accepts_or_refuses('one anchor, 4,500 references: sops refuses (463,604 expanded)',
    flat_yaml(50, 4500), 'REFUSE');

accepts_or_refuses('two levels, 80 wide: sops accepts (32,650 expanded)',
    chain_yaml(2, 80, 1), 'ACCEPT');
accepts_or_refuses('two levels, 81 wide: sops refuses (33,463 expanded)',
    chain_yaml(2, 81, 1), 'REFUSE');

accepts_or_refuses('plain chain, 264 deep: sops accepts (106,002 expanded)',
    chain_yaml(264, 1, 1), 'ACCEPT');
accepts_or_refuses('plain chain, 265 deep: sops refuses (106,801 expanded)',
    chain_yaml(265, 1, 1), 'REFUSE');

# The counters are go-yaml's counters in go-yaml's units, and the message
# reports them. If the units drift the ratio is no longer its ratio, so pin
# the two numbers on one measured document rather than only the verdict.
{
    my $tree = YAML::XS::Load(chain_yaml(9, 2, 1));
    eval { File::SOPS::_assert_expansion_bounded($tree) };
    like($@, qr/expands to 8146 values from the 60 it holds/,
        'the census counts what go-yaml counts, to the node');
}

# ---------------------------------------------------------------------------
# And the ordinary documents this must never touch.

my $DAG = "base: &b\n  p: 1\nother: *b\n";

my $enc = File::SOPS->encrypt(
    data       => YAML::XS::Load($DAG),
    recipients => [$public],
    format     => 'yaml',
);
my $back = File::SOPS->decrypt(encrypted => $enc, identities => [$secret]);
is($back->{base}{p},  '1', 'a reused anchor still round-trips (the anchor)');
is($back->{other}{p}, '1', 'and the alias, expanded into an independent value');

# A large document with no sharing at all amplifies nothing and is accepted
# however big it gets. This is the case an absolute node cap would break.
{
    my %big;
    $big{"key$_"} = { a => $_, b => "value $_", c => [ 1, 2, 3 ] }
        for 1 .. 5000;
    my $ok = eval { File::SOPS::_assert_expansion_bounded(\%big); 1 };
    ok($ok, 'a 45,000-node document that shares nothing is accepted');
}

# A deep diamond is the shape ADR 0025's $clean set exists for, and the census
# needs its own memo for the same reason: 2**30 paths, 61 nodes. Forked,
# because a census without a memo does not return.
{
    my $diamond = { v => 1 };
    $diamond = { l => $diamond, r => $diamond } for 1 .. 30;
    my $verdict = guarded(sub {
        File::SOPS::_assert_expansion_bounded($diamond);
    });
    like($verdict, qr/\ADIE .*excessive aliasing/,
        'a 30-level diamond is counted in one pass, not walked')
        or diag("got: $verdict");
}

done_testing;

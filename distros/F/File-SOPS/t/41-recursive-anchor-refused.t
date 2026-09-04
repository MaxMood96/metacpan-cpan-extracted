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

# k110 / docs/adr/0025 -- a document that contains itself.
#
# YAML::XS resolves a recursive anchor into a real Perl cycle, so every tree
# walk in File::SOPS used to recurse until the process was killed. All eight
# public entry points were affected, in both directions.
#
# EVERY assertion that could hang runs in a FORKED CHILD, and the child reports
# back down a pipe. That is deliberate and it is what keeps a regression RED
# instead of hanging the suite. Three things hold it, because one is not
# enough:
#
#   1. The child lowers $File::SOPS::MAX_DEPTH to 200, so a runaway walk hits
#      the library's own depth bound instead of running. That is the FAST net
#      and the only one that bounds MEMORY: every walk in File::SOPS refuses
#      to go deeper than that variable, so a regression is refused in about
#      2ms with no allocation to speak of (measured, all three cycle shapes in
#      this file). Without it the walk climbs about 1 GB of RSS every three
#      seconds (measured), and long before any timeout the machine is
#      thrashing -- a regression took 130s per case to be reported that way.
#
#      This USED to be perl's own "Deep recursion" warning, which it raises at
#      a fixed depth of 100. k117 silenced that warning in the walks: it
#      fires on documents sops accepts, once per crossing, and turned a correct
#      encrypt of a 265-level document into 505 warning lines on STDERR. The
#      bound that replaced it is this library's, and unlike perl's it can be
#      moved -- which is what this file does. The fixtures stay far below it
#      either way; the deepest here is 40.
#   2. An alarm, as the backstop for a runaway that somehow does not recurse.
#   3. The fork itself, so whatever the child did allocate dies with it.
#
# On the passing path none of the three ever fires: the guard croaks
# immediately and no document here is anywhere near 200 levels deep.

plan skip_all => 'this test forks to bound a regression, and fork is not '
    . 'available here'
    unless $Config{d_fork};

# Generous: every guarded call below is a single encrypt or decrypt and takes
# tens of milliseconds. This is a hang detector, not a benchmark.
my $TIMEOUT = 5;

# Runs $code in a child under alarm. Returns 'OK', "DIE <message>", or 'HANG'.
sub guarded {
    my ($code) = @_;

    pipe(my $read, my $write) or die "pipe: $!";

    my $pid = fork();
    die "fork: $!" unless defined $pid;

    if (!$pid) {
        close $read;
        # The fast net. A runaway walk trips the library's depth bound here
        # rather than at 10000, before it has allocated anything worth
        # worrying about. refuses() below tells that death apart from the
        # refusal being asserted, so a regression reads as a regression and
        # not as a wrong message.
        local $File::SOPS::MAX_DEPTH = 200;
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

# Asserts that $code refuses, rather than hanging or succeeding.
sub refuses {
    my ($name, $code) = @_;
    my $got = guarded($code);
    if ($got eq 'HANG' || $got =~ /nests containers more than/) {
        fail("$name refuses a document that contains itself");
        diag($got eq 'HANG'
            ? "HUNG -- did not return within ${TIMEOUT}s."
            : "RAN AWAY -- walked the cycle until the depth bound stopped it, "
              . "instead of refusing it as a cycle.");
        diag("This is k110 back again; see docs/adr/0025.");
        return;
    }
    like($got, qr/\ADIE .*contains itself/,
        "$name refuses a document that contains itself")
        or diag("got: $got");
}

my ($public, $secret) = Crypt::Age->generate_keypair();

my $RECURSIVE = "root: &a\n  b: *a\n";

# ---------------------------------------------------------------------------
# The premise, pinned. If YAML::XS ever stops building the cycle, the rest of
# this file would pass for the wrong reason, so say out loud what it does.

my $parsed = YAML::XS::Load($RECURSIVE);
is(refaddr($parsed->{root}), refaddr($parsed->{root}{b}),
    'YAML::XS resolves a recursive anchor into a real Perl cycle');

# And the parse itself still RETURNS -- the refusal is the API's, not the
# parser's, which is why it also catches a cycle no parser was involved in.
is(guarded(sub { File::SOPS::Format::YAML->parse($RECURSIVE) }), 'OK',
    'Format::YAML->parse still returns the cyclic tree');

# ---------------------------------------------------------------------------
# The encrypt side. Used to hang in _sorted_leaves, via _compute_mac.

refuses('encrypt', sub {
    File::SOPS->encrypt(
        data       => YAML::XS::Load($RECURSIVE),
        recipients => [$public],
        format     => 'yaml',
    );
});

# Same guard with no YAML anywhere near it: JSON has no anchors, but a caller
# can hand encrypt a cycle of their own. One message has to serve both.
refuses('encrypt (format => json)', sub {
    File::SOPS->encrypt(
        data       => YAML::XS::Load($RECURSIVE),
        recipients => [$public],
        format     => 'json',
    );
});

refuses('encrypt (caller-built hash cycle)', sub {
    my $h = { a => 1 };
    $h->{self} = $h;
    File::SOPS->encrypt(data => $h, recipients => [$public], format => 'yaml');
});

refuses('encrypt (caller-built array cycle)', sub {
    my $list = [1];
    push @$list, $list;
    File::SOPS->encrypt(
        data       => { list => $list },
        recipients => [$public],
        format     => 'yaml',
    );
});

# The message names the path at which the cycle closes, not just the fact.
my $msg = guarded(sub {
    File::SOPS->encrypt(
        data       => YAML::XS::Load($RECURSIVE),
        recipients => [$public],
        format     => 'yaml',
    );
});
like($msg, qr/\broot:b\b/, 'the refusal names the path where the cycle closes');

# ---------------------------------------------------------------------------
# The decrypt side. Used to hang in _decrypt_tree.
#
# Build a real encrypted document, then splice the recursive anchor into its
# data section. The substitution is asserted: if the emitted layout ever
# changes, this has to fail rather than quietly test a document with no cycle
# in it.

my $sane = File::SOPS->encrypt(
    data       => { plain => 'x' },
    recipients => [$public],
    format     => 'yaml',
);

my $cyclic_doc = $sane;
my $spliced = ($cyclic_doc =~ s/^plain: .*\n/root: &a\n  b: *a\n/m);
ok($spliced, 'built an encrypted document carrying a recursive anchor');

refuses('decrypt', sub {
    File::SOPS->decrypt(encrypted => $cyclic_doc, identities => [$secret]);
});

# ignore_mac suppresses verification, not the document's shape. This is the
# path that has to be checked separately: it is the one that skips the most.
refuses('decrypt (ignore_mac => 1)', sub {
    File::SOPS->decrypt(
        encrypted  => $cyclic_doc,
        identities => [$secret],
        ignore_mac => 1,
    );
});

# The refusal comes AHEAD of the key, which is the order sops answers in: the
# same document with no usable identity reports the cycle, not the key.
my ($other_public, $other_secret) = Crypt::Age->generate_keypair();
refuses('decrypt (with an identity that cannot open the file)', sub {
    File::SOPS->decrypt(
        encrypted  => $cyclic_doc,
        identities => [$other_secret],
    );
});

# ---------------------------------------------------------------------------
# The file entry points. All of them funnel through encrypt or decrypt, and
# this is what says so.

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

my $enc_path = write_file(in_dir('cyclic.enc.yaml'), $cyclic_doc);

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
        path       => '["root"]',
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

my $plain_path = write_file(in_dir('cyclic.yaml'), $RECURSIVE);
my $out_path   = in_dir('cyclic.out.yaml');

refuses('encrypt_file', sub {
    File::SOPS->encrypt_file(
        input      => $plain_path,
        output     => $out_path,
        recipients => [$public],
    );
});
ok(!-e $out_path, 'encrypt_file wrote no output on the refusal');

my $in_place_path = write_file(in_dir('in-place.yaml'), $RECURSIVE);
refuses('encrypt_in_place', sub {
    File::SOPS->encrypt_in_place(file => $in_place_path, recipients => [$public]);
});
is(do { open my $fh, '<', $in_place_path or die; local $/; <$fh> }, $RECURSIVE,
    'encrypt_in_place left the original untouched on the refusal');

# ---------------------------------------------------------------------------
# The guard must not OVER-refuse. Everything below here is a document sops
# accepts, and a plain visited set -- the other obvious way to make the walks
# terminate -- would have refused or truncated all of it.

my $DAG = "base: &b\n  p: 1\nother: *b\n";

my $dag_round_trip = guarded(sub {
    my $enc = File::SOPS->encrypt(
        data       => YAML::XS::Load($DAG),
        recipients => [$public],
        format     => 'yaml',
    );
    my $back = File::SOPS->decrypt(encrypted => $enc, identities => [$secret]);
    die "base missing\n"  unless $back->{base}{p}  eq '1';
    die "other missing\n" unless $back->{other}{p} eq '1';
});
is($dag_round_trip, 'OK',
    'a reused anchor is not a cycle: the shared subtree still round-trips')
    or diag("got: $dag_round_trip");

# sops expands a reused anchor into independent values rather than emitting an
# alias, and so does this. Both keys are present and separately encrypted.
my $dag_enc = File::SOPS->encrypt(
    data       => YAML::XS::Load($DAG),
    recipients => [$public],
    format     => 'yaml',
);
like($dag_enc, qr/^base:/m,  'the shared subtree is written under its own key');
like($dag_enc, qr/^other:/m, 'and under the alias key as well');

# The $clean set in _assert_acyclic is load-bearing, not an optimisation: a
# diamond has exponentially many PATHS and linearly many NODES, so a guard
# that walked paths would never return on this and would be the very defect it
# was added to remove.
my $diamond = { v => 1 };
$diamond = { l => $diamond, r => $diamond } for 1 .. 40;
is(guarded(sub { File::SOPS::_assert_acyclic($diamond, [], {}, {}) }), 'OK',
    'a 40-level diamond (2**40 paths, 81 nodes) clears the guard');

done_testing;

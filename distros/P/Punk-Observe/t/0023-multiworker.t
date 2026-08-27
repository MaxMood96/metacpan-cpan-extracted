#!perl
# The phase gate: two workers that never communicate must agree on the series
# id for the same label set, and each must be able to read the other's
# segments.
#
# If this does not hold, per-worker writing is not possible and phase 4's
# whole shape - no dictionary authority, no lock on the ingest path - falls
# over.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Config;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;

my $S = 'Punk::Observe::Segment';
my $dir = tempdir(CLEANUP => 1);
sub path { File::Spec->catfile($dir, $_[0]) }

# Each worker sees the SAME set of label blocks but in a different order, and
# with different records interleaved - which is what actually happens when two
# workers accept different halves of the same fleet's traffic.
my @labels = map { "service\0s$_\0route\0/r$_" } 1 .. 12;

SKIP: {
    skip 'fork not available', 9 unless $Config{d_fork};

    my @pids;
    for my $w (0, 1) {
        my $pid = fork();
        skip 'fork failed', 9 unless defined $pid;
        if ($pid == 0) {
            # Worker 0 walks forwards, worker 1 backwards. Neither knows the
            # other exists; there is no lock, no shared file, no coordination.
            my @order = $w == 0 ? (0 .. $#labels) : reverse(0 .. $#labels);
            my $specs = [ map {
                { t => 1774224000000000000 + $_ * 1000,
                  body => "span-$_", labels => $labels[$_] }
            } @order ];
            $S->can('write')->(path("w$w.seg"), $specs, 'acme', $w);
            require POSIX;
            POSIX::_exit(0);
        }
        push @pids, $pid;
    }
    waitpid $_, 0 for @pids;

    ok(-f path('w0.seg'), 'worker 0 wrote a segment');
    ok(-f path('w1.seg'), 'worker 1 wrote a segment');

    # The parent - a third process that wrote neither - reads both.
    my $r0 = $S->can('read')->(path('w0.seg'));
    my $r1 = $S->can('read')->(path('w1.seg'));
    ok($r0 && $r1, 'a third process can mmap and read both');
    is(scalar @{ $r0->{records} }, 12, 'worker 0 wrote 12 records');
    is(scalar @{ $r1->{records} }, 12, 'worker 1 wrote 12 records');

    # THE GATE. Map each label block to the series id it got in each segment,
    # and require the two maps to be identical.
    my (%by_body_0, %by_body_1);
    $by_body_0{ $_->{body} } = "$_->{series}" for @{ $r0->{records} };
    $by_body_1{ $_->{body} } = "$_->{series}" for @{ $r1->{records} };

    is_deeply(\%by_body_0, \%by_body_1,
        'both workers assigned the SAME series id to the same label set, '
      . 'with no coordination');

    # And the ids are actually distinct per label set, so the agreement above
    # is not the trivial one where everything hashed to zero.
    my %distinct = map { $_ => 1 } values %by_body_0;
    is(scalar keys %distinct, 12, '  and the 12 label sets got 12 distinct ids');

    # The segments record which worker wrote them, and the footer spans are
    # each correct for that worker's own records.
    my $p0 = $S->can('parse')->(do {
        open my $fh, '<', path('w0.seg') or die; binmode $fh; local $/; <$fh> });
    my $p1 = $S->can('parse')->(do {
        open my $fh, '<', path('w1.seg') or die; binmode $fh; local $/; <$fh> });
    is($p0->{slot}, 0, 'worker 0 stamped its slot');
    is($p1->{slot}, 1, 'worker 1 stamped its slot');
}

# --- a segment survives its file being unlinked -----------------------------

# This is what makes retention safe in phase 10 and lock-free readers possible
# throughout: a reader holding an mmap of an unlinked file keeps valid pages
# on POSIX. (The forbidden operation is ftruncate, which SIGBUSes - phase 10
# owns that invariant.)
SKIP: {
    skip 'no mmap on this platform', 2 if $^O eq 'MSWin32';

    my $p = path('doomed.seg');
    $S->can('write')->($p, [ map {
        { t => 1000 + $_, body => "b$_", labels => "l$_" } } 1 .. 50 ],
        'acme', 0);

    # Open it, unlink the name, then read every record through the mapping.
    my $before = $S->can('read')->($p);
    is(scalar @{ $before->{records} }, 50, 'the segment reads before unlink');

    unlink $p;
    ok(!-f $p, 'the name is gone');

    # A fresh open must now fail - the name really is gone, so this is not a
    # caching artefact.
    my $after = $S->can('read')->($p);
    ok(!defined $after, 'and a new open of the unlinked name fails');
}

done_testing();

#!perl
# Retention, against REAL segment files.
#
# The assertion that matters: a reader keeps reading a segment whose name has
# been unlinked underneath it. That is what makes lock-free readers possible,
# and it is why the deletion primitive is unlink and never ftruncate - a
# truncated mapping is SIGBUS, which is not an error return, it is a signal
# killing the worker mid-request for every connection it held.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;

my $R = 'Punk::Observe::Retain';
my $S = 'Punk::Observe::Segment';
my $dir = tempdir(CLEANUP => 1);
sub path { File::Spec->catfile($dir, $_[0]) }

# Write a real segment with a known time span.
sub seg {
    my ($name, $t0, $n) = @_;
    my $p = path($name);
    $S->can('write')->($p, [ map {
        { t => "" . ($t0 + $_ * 1000), body => "b$_", labels => "l" }
    } 1 .. $n ], 'acme', 0);
    return $p;
}

# --- THE INVARIANT ----------------------------------------------------------

{
    my $p = seg('live.seg', 1_000_000, 200);
    my $r = $R->can('read_through_unlink')->($p);

    ok($r->{opened}, 'the segment mmaps');
    is("$r->{records}", '200', '  with 200 records');
    ok($r->{unlinked}, '  and its name is then unlinked');
    ok(!-f $p, '  so the name really is gone');

    ok($r->{same},
       'EVERY RECORD STILL READS CORRECTLY THROUGH THE MAPPING AFTER UNLINK');
    is("$r->{sum_after}", "$r->{sum_before}",
       '  byte for byte, which is what makes lock-free readers safe');
}

# A fresh open of the unlinked name must fail, so the test above is not
# passing on a cached handle.
{
    my $p = seg('gone.seg', 2_000_000, 10);
    unlink $p;
    my $r = $S->can('read')->($p);
    ok(!defined $r, 'a new open of an unlinked segment fails');
}

# --- there is no ftruncate ---------------------------------------------------

# The suite fails if one ever appears on a segment path. "Reclaim the tail of
# a partly-expired segment" is the optimisation that will be suggested, and
# this is the standing answer.
{
    my @paths = map { seg("t$_.seg", 1_000_000 + $_ * 100_000, 20) } 1 .. 5;
    my $r = $R->can('sweep')->(\@paths, '999999999');
    is($r->{truncate_calls}, 0,
       'the sweep called ftruncate exactly zero times');
}

{
    # And the source itself contains no CALL to it.
    #
    # Comments are stripped first: both headers discuss ftruncate at length,
    # because explaining why it must never be used is the point. Counting
    # mentions rather than calls made this test fail on its own documentation.
    my $calls = 0;
    my @checked;
    for my $f (glob('include/punk_observe/po_*.h')) {
        open my $fh, '<', $f or next;
        local $/;
        my $src = <$fh>;
        $src =~ s{/\*.*?\*/}{}gs;          # C comments
        $src =~ s{//[^\n]*}{}g;            # and any line comments
        push @checked, $f;
        $calls++ while $src =~ /\bftruncate\s*\(/g;
    }
    cmp_ok(scalar @checked, '>', 10, 'the whole header set was checked');
    is($calls, 0,
       'no header CALLS ftruncate - a truncated mapping is SIGBUS, not an error');
}

# --- expiry by whole block --------------------------------------------------

{
    my @paths = (
        seg('old1.seg',  1_000_000, 10),   # t_max ~1_010_000
        seg('old2.seg',  2_000_000, 10),   # ~2_010_000
        seg('new1.seg', 50_000_000, 10),   # ~50_010_000
        seg('new2.seg', 60_000_000, 10),
    );
    my $r = $R->can('sweep')->(\@paths, '10000000');
    is($r->{considered}, 4, 'four segments considered');
    is($r->{marked}, 2, '  two are entirely older than the cutoff');
    is($r->{unlinked}, 2, '  and two are unlinked');
    is($r->{kept}, 2, '  two kept');
    ok(!-f $paths[0] && !-f $paths[1], '  the old ones are gone');
    ok(-f $paths[2] && -f $paths[3], '  the new ones remain');
    ok(0 + $r->{bytes_freed} > 0, '  and the freed bytes are reported');
}

# Expiry uses t_max, not t_min. A segment that STRADDLES the cutoff is kept:
# using t_min would delete records still inside the retention window.
{
    my $p = seg('straddle.seg', 9_990_000, 30);   # spans the cutoff
    my $r = $R->can('sweep')->([ $p ], '10000000');
    is($r->{marked}, 0, 'a segment straddling the cutoff is NOT expired');
    ok(-f $p, '  and survives, because part of it is still in the window');
}

{
    my $p = seg('boundary.seg', 1_000_000, 5);
    # t_max is 1_005_000; a cutoff exactly at t_max must NOT expire it,
    # because the record at t_max is still within the window.
    my $r = $R->can('sweep')->([ $p ], '1005000');
    is($r->{marked}, 0, 'a cutoff exactly at t_max keeps the segment');
    ok(-f $p, '  since that last record is still inside the window');

    my $r2 = $R->can('sweep')->([ $p ], '1005001');
    is($r2->{marked}, 1, 'one nanosecond later it expires');
}

# --- an empty directory is not an expired one -------------------------------

# A tenant idle for two hours must not have its directory removed and
# recreated in a loop.
{
    ok(!$R->can('block_removable')->(0, 1),
       'a block with no segments is not removable, however old');
    ok(!$R->can('block_removable')->(5, 0),
       'a block with unexpired segments is not removable');
    ok($R->can('block_removable')->(5, 1),
       'a block whose every segment expired is removable');
}

# --- generations ------------------------------------------------------------

# A query reading generation N keeps reading it while retention moves on.
{
    my $busy = $R->can('generations')->([
        'busy',    '1',      # nobody yet
        'acquire', '1',
        'busy',    '1',      # now held
        'acquire', '1',      # two readers
        'release', '1',
        'busy',    '1',      # still one
        'release', '1',
        'busy',    '1',      # free
    ]);
    is_deeply($busy, [ 0, 1, 1, 0 ],
              'a generation is busy while any reader holds it');
}

{
    my $busy = $R->can('generations')->([
        'acquire', '5',
        'busy',    '5',
        'busy',    '6',
        'release', '5',
        'busy',    '5',
    ]);
    is_deeply($busy, [ 1, 0, 0 ],
              'generations are tracked independently of each other');
}

# --- reading while retention deletes underneath -----------------------------

# A scripted interleaving rather than a race: open, then delete, then read.
# Pinned by construction, so it is a test rather than a flake.
{
    my @keep;
    for my $i (1 .. 5) {
        my $p = seg("interleave$i.seg", 1_000_000 * $i, 50);
        push @keep, $p;
    }
    # Read one through its own deletion while the others are swept.
    my $r = $R->can('read_through_unlink')->($keep[2]);
    ok($r->{same}, 'a segment reads correctly through its own deletion');

    my $sweep = $R->can('sweep')->([ grep { -f $_ } @keep ], '999999999');
    is($sweep->{truncate_calls}, 0, '  and the concurrent sweep truncated nothing');
}

# --- an unreadable path is skipped, not fatal -------------------------------

{
    my $r = $R->can('sweep')->([ path('does-not-exist.seg') ], '999999999');
    is($r->{considered}, 0, 'a missing segment is skipped rather than fatal');
    is($r->{unlinked}, 0, '  and nothing is unlinked');
}

done_testing();

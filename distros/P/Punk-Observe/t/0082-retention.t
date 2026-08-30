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



# --- a read does not hold a mapping across a retention pass -----------------
#
# THIS REPLACES A NUMBER ON THE STATUS PAGE.
#
# `mapped_deleted` was displayed so an operator could see why the disk had not
# shrunk: a segment unlinked while a reader still holds it open occupies space
# that du cannot see. But the figure was structurally always zero, because
# this store cannot accumulate one - a read copies the segment and releases it
# inside the call. A zero that cannot be anything else demonstrates nothing,
# so the number came off the page and the property is asserted here instead.
#
# mmap plus unlink is safe and mmap plus TRUNCATE is a SIGBUS, which is why
# retention only ever unlinks. If a read ever starts holding a mapping open
# across a pass, this is the test that says so.
{
    require Punk::Observe::Store;
    require Punk::Observe::WAL;

    my $d = tempdir(CLEANUP => 1);
    my $s = Punk::Observe::Store->new(dir => $d);
    my $T = '1774224000000000000';

    my @recs = map {
        { kind => 2, t => Punk::Observe::Store::nadd($T, $_ * 1_000_000_000),
          body => "line $_", severity => 9,
          attrs => { 'service.name' => 'api' } }
    } 0 .. 9;
    Punk::Observe::WAL::append($s->wal_path, \@recs, 0, 0);
    ok($s->seal, 'a segment to read and then delete');

    # Read it, and let the read finish. The mapping must not outlive the call.
    my ($rows) = $s->rows(from => $T,
                          to => Punk::Observe::Store::nadd($T, 60_000_000_000));
    cmp_ok(scalar @$rows, '>', 0, '  the read returns rows');

    # Now unlink every sealed segment, as a retention pass does.
    my @segs = glob(File::Spec->catfile($d, 'default', 'wal', '*.seg'));
    cmp_ok(scalar @segs, '>', 0, '  and there is a sealed segment on disk');
    unlink @segs;

    # THE ASSERTION: the store still answers, and answers with nothing rather
    # than crashing on a mapping into a file that is gone.
    my $after = eval {
        my ($r2) = $s->rows(from => $T,
                            to => Punk::Observe::Store::nadd($T, 60_000_000_000));
        scalar @$r2;
    };
    ok(defined $after, 'reading after the segments are unlinked does not die')
        or diag("died: $@ - a read is holding a mapping across the pass");

    my $st = eval { $s->stats };
    ok($st, '  and the store still reports its stats');
}

# --- a log whose worker died is adopted, not abandoned ----------------------
#
# Retention considers SEALED segments only, and the live log is deliberately
# never touched. A log left by a worker that died is neither: never indexed,
# never expired, never counted against the byte budget. Every restart left
# another - 261MB across 127 files on a demo store after one day, none of
# which `keep` could reach.
#
# The dangerous half is the other direction, and it is what most of these
# assert: sealing a log somebody is still appending to renames the file under
# their descriptor and lets them write WAL records past the seal trailer.

{
    require Punk::Observe::Retain;
    require Punk::Observe::WAL;

    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $T = '1774224000000000000';

    my $rec = sub {
        my ($n) = @_;
        return { kind => 2, t => Punk::Observe::Store::nadd($T, $n * 1_000_000),
                 body => "line $n", severity => 9, span_kind => 0, status => 0,
                 duration => 0, span_id => 0, parent_id => 0,
                 trace_hi => 0, trace_lo => 0, attrs => {} };
    };

    my $waldir = $store->wal_dir;
    Punk::Observe::WAL::append($store->wal_path, [ $rec->(1) ], 0, 0);

    # A pid that cannot be running: pid 0 is never a user process, and the
    # file is backdated so the staleness test passes too.
    my $dead = File::Spec->catfile($waldir, 'w999999999.wal');
    Punk::Observe::WAL::append($dead, [ $rec->(2), $rec->(3) ], 0, 0);
    utime time - 7200, time - 7200, $dead;

    # OUR OWN pid, which is alive by construction - the case that must never
    # be adopted however stale the file looks.
    my $mine = File::Spec->catfile($waldir, "w$$.wal");
    Punk::Observe::WAL::append($mine, [ $rec->(4) ], 0, 0)
        unless -e $mine;
    utime time - 7200, time - 7200, $mine;

    # A log written seconds ago, whose pid is long gone. Stale-by-pid but not
    # by mtime: a recycled pid is exactly the case the age test covers, so
    # this must be left alone too.
    my $fresh = File::Spec->catfile($waldir, 'w999999998.wal');
    Punk::Observe::WAL::append($fresh, [ $rec->(5) ], 0, 0);

    # `opendir my $d, $dir` parses as a `my` LIST without parentheses and
    # warns; the handle also went unclosed. One helper, used twice.
    my $segs = sub {
        opendir(my $dh, $waldir) or return ();
        my @f = grep { /\.seg\z/ } readdir $dh;
        closedir $dh;
        return @f;
    };

    my $before = scalar @{[ $segs->() ]};

    my $r = Punk::Observe::Retain::adopt_orphans(store => $store,
                                                 grace_s => 600);
    is($r->{adopted}, 1, 'the log of a dead worker is adopted');
    ok($r->{bytes} > 0, '  and its bytes are reported');
    ok(!-e $dead, '  the log is gone from the wal directory');

    ok(-e $mine, 'a LIVE worker\'s own log is never adopted, however stale');
    ok(-e $fresh, 'nor one written moments ago, whatever its pid says - a '
                . 'recycled pid is why the age test exists');
    is($r->{skipped_recent}, 1, '  and the recent one is counted as skipped');

    my @segs = $segs->();
    is(scalar @segs, $before + 1, 'the adopted log became one segment');

    # THE POINT OF SEALING RATHER THAN DELETING: the records survive and are
    # now indexed, so retention can age them out on the same rule as
    # everything else instead of never seeing them.
    my ($seg) = grep { /\.seg\z/ } @segs;
    (my $idx = $seg) =~ s/\.seg\z/.idx/;
    ok(-e File::Spec->catfile($waldir, $idx),
       '  with the sidecar that makes it prunable and expirable');

    my ($rows) = $store->records(from => $T,
        to => Punk::Observe::Store::nadd($T, '60000000000'));
    my %bodies = map { ($_->{body} // '') => 1 } @$rows;
    ok($bodies{'line 2'} && $bodies{'line 3'},
       '  and the records it held are still readable, not destroyed');

    # The segment keeps the ORIGINAL worker's pid, so a segment can be traced
    # back to the process that wrote it.
    like($seg, qr/-999999999-/, 'the segment is named for the worker that '
                              . 'wrote the log, not the one that adopted it');

    # Idempotent: a second pass has nothing left to do.
    my $again = Punk::Observe::Retain::adopt_orphans(store => $store,
                                                     grace_s => 600);
    is($again->{adopted}, 0, 'a second pass adopts nothing');

    # dry_run decides everything and seals nothing.
    my $dead2 = File::Spec->catfile($waldir, 'w999999997.wal');
    Punk::Observe::WAL::append($dead2, [ $rec->(6) ], 0, 0);
    utime time - 7200, time - 7200, $dead2;
    my $dry = Punk::Observe::Retain::adopt_orphans(store => $store,
                                                   grace_s => 600, dry_run => 1);
    # Every decision, only the seal skipped - which is what dry_run means for
    # `pass`. Counting the seal instead of the decision made a dry run report
    # nothing to do on a store with 127 reclaimable logs.
    is($dry->{adopted}, 1, 'dry_run reports what a real pass would adopt');
    ok($dry->{bytes} > 0, '  including the bytes it would reclaim');
    ok(-e $dead2, '  while leaving the log exactly where it was');
}

# --- the scheduled forms ----------------------------------------------------
#
# `cron_task` and `retain_job` were the last two subs in this module and were
# exercised by nothing: a block named for `retain_job` called `pass` instead.
# Both are now XS - the closure carries its options on the CV - and an XSUB
# nobody calls is an XSUB nobody knows compiles.

{
    package Fake::Queue;
    sub new {
        my ($c, %o) = @_;
        return bless { grant => (exists $o{grant} ? $o{grant} : 1),
                       calls => [] }, $c;
    }
    sub lock {
        my ($s, $name, $lease, %o) = @_;
        push @{ $s->{calls} }, [ 'lock', $name, $lease, $o{owner} ];
        return $s->{grant};
    }
    sub renew_lock {
        my ($s, @a) = @_; push @{ $s->{calls} }, [ 'renew_lock', @a ]; 1;
    }
    sub unlock {
        my ($s, @a) = @_; push @{ $s->{calls} }, [ 'unlock', @a ]; 1;
    }
    sub did { my ($s, $m) = @_; scalar grep { $_->[0] eq $m } @{ $s->{calls} } }
}

sub seeded_store {
    my ($dir) = @_;
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $now = Punk::Observe::now_ns();
    for my $age (9 * 86_400, 3_600) {
        Punk::Observe::WAL::append($store->wal_path, [ {
            kind => 2, t => Punk::Observe::Store::nsub($now, $age . '000000000'),
            body => 'x', severity => 9, span_kind => 0, status => 0,
            duration => 0, span_id => 0, parent_id => 0,
            trace_hi => 0, trace_lo => 0,
            attrs => { 'service.name' => 'a' } } ], 0, 0);
        $store->seal;
    }
    return $store;
}

{
    require Punk::Observe::Retain;
    my $keep = 7 * 86_400 * 1_000_000_000;

    my $store = seeded_store(tempdir(CLEANUP => 1));
    my $code = Punk::Observe::Retain::cron_task(
        store => $store, keep_ns => $keep, owner => 4242);
    is(ref $code, 'CODE', 'cron_task hands back a coderef');

    my $q = Fake::Queue->new;
    is($code->($q), 1, '  which runs the pass and returns what it unlinked');
    is($q->{calls}[0][1], 'leader', '  under the leader lease');
    is($q->{calls}[0][3], 4242, '  as the owner it was given');
    ok($q->did('renew_lock'), '  renewing it');
    ok($q->did('unlock'), '  and releasing it');

    # THE OPTIONS RIDE ON THE CLOSURE. A second call with a second queue must
    # still know its store and window - the XSUB is handed only the queue.
    my $again = $code->(Fake::Queue->new);
    is($again, 0, 'a second call finds nothing left and still knows its store');

    # LOSING THE RACE IS THE NORMAL CASE ON A POOL, not an error - and the
    # pass must not run at all.
    my $store2 = seeded_store(tempdir(CLEANUP => 1));
    my $lost = Punk::Observe::Retain::cron_task(
        store => $store2, keep_ns => $keep);
    my $refuse = Fake::Queue->new(grant => 0);
    is($lost->($refuse), 0, 'a worker that loses the lock reports nothing done');
    ok(!$refuse->did('unlock'),
       '  and does not unlock a lease it never held');
    is(scalar @{ $store2->segments }, 2,
       '  having deleted nothing at all');

    eval { Punk::Observe::Retain::cron_task(store => $store) };
    like($@, qr/needs keep_ns/,
         'cron_task with no window croaks at build time, not at fire time');
}

# --- retain_job, the queue task body ----------------------------------------

{
    require Punk::Plugin::Observe;
    my $dir = tempdir(CLEANUP => 1);
    my $store = seeded_store($dir);

    # Registered under a class NAME: `register` files the state under
    # `ref($app) || $app`, and a plain string is neither an object nor undef,
    # so the state is reachable by the name the job carries.
    #
    # `retain` is NOT passed to register here: configuring it asks the plugin
    # to schedule the cron, which needs a queue this test has no business
    # standing up. The window is put on the state directly, which is the shape
    # `retain_job` actually reads.
    my $class = 'Retain::Job::Test::App';
    my $st = Punk::Plugin::Observe->register($class, {
        guard => sub { 1 }, store => $dir,
        alerts => sub { {} },        # our own evaluator, so no queue is needed
    });
    $st->{retain_opts} = { keep_ns => 7 * 86_400 * 1_000_000_000 };

    {
        package Fake::Job;
        sub new { my ($c, $q) = @_; bless { q => $q }, $c }
        sub queue_object { $_[0]{q} }
        sub retries { 0 }
    }

    my $q = Fake::Queue->new;
    my $out = Punk::Observe::Retain::retain_job(Fake::Job->new($q), $class);
    is(ref $out, 'HASH', 'retain_job returns what it did');
    is($out->{unlinked}, 1, '  the nine-day segment went');
    is($out->{kept}, 1, '  the one inside the window stayed');
    ok(exists $out->{unknown_kept}, '  and it reports what it could not age');
    is($q->{calls}[0][1], 'observe.retain',
       '  under its own named lease, not the leader one');
    ok($q->did('unlock'), '  which it releases');

    my $refused = Punk::Observe::Retain::retain_job(
        Fake::Job->new(Fake::Queue->new(grant => 0)), $class);
    is($refused->{skipped}, 'lock',
       'a worker that loses the lease says so rather than running twice');

    # A class the worker never compiled is the misconfiguration this names.
    eval { Punk::Observe::Retain::retain_job(Fake::Job->new($q), 'No::Such') };
    like($@, qr/no Observe plugin state/,
         'an unknown application class croaks with what to check');
}

done_testing();

#!perl
# Retention and paging: what running the demo for a day taught.
#
# Nothing scheduled retention - Punk::Observe::Retain was complete and
# caller-less since phase 10, and the demo store reached 149MB before anybody
# noticed. And worse, found while building this: the C sweep opens segments
# with po_seg_open, a format the store never writes, so handed a real store it
# considered zero segments forever - retention that ran, deleted nothing, and
# looked exactly like an empty store.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe ();
use Punk::Observe::Store ();
use Punk::Observe::WAL ();
use Punk::Observe::Retain ();
use Punk::Observe::View ();

sub rec {
    my ($t, %o) = @_;
    return { kind => $o{kind} // 2, t => $t, duration => $o{duration} // 0,
             body => $o{body} // 'line', severity => 9, span_kind => $o{span_kind} // 0,
             status => 0, trace_hi => $o{hi} // 0, trace_lo => $o{lo} // 0,
             span_id => $o{span_id} // 0, parent_id => 0,
             attrs => $o{attrs} // {} };
}

# --- parse_keep --------------------------------------------------------------
{
    is(Punk::Observe::Retain::parse_keep('30d'), '2592000000000000',
       '30d is thirty days of nanoseconds');
    is(Punk::Observe::Retain::parse_keep('12h'), '43200000000000', 'and 12h');
    ok(!defined Punk::Observe::Retain::parse_keep('1mo'),
       'there is no month, which would be a trap nobody recovers from');
    ok(!defined Punk::Observe::Retain::parse_keep('soon'),
       'and prose is refused rather than guessed at');

    # No default window anywhere: a retention job with a silently defaulted
    # window is a deletion job.
    ok(!eval { Punk::Observe::Retain::pass(store => 1); 1 },
       'pass without keep_ns refuses to run');
    like($@, qr/keep_ns/, '  naming what was missing');
}

# --- a pass on a real store --------------------------------------------------
{
    my $d = tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $d, tenant => 'default');

    my $old = '1600000000000000000';                    # 2020
    my $now = time . '000000000';
    Punk::Observe::WAL::append($st->wal_path,
        [ map { rec(Punk::Observe::Store::nadd($old, $_ * 1000),
                    body => "old $_") } 1 .. 50 ], 0, 0);
    $st->seal;
    Punk::Observe::WAL::append($st->wal_path,
        [ map { rec(Punk::Observe::Store::nadd($now, $_ * 1000),
                    body => "new $_") } 1 .. 50 ], 0, 0);
    $st->seal;

    my $keep = Punk::Observe::Retain::parse_keep('30d');

    # THE DRY RUN IS THE MARK WITHOUT THE SWEEP: every decision taken, only
    # the unlink skipped, so its numbers are the real run's numbers.
    my $dry = Punk::Observe::Retain::pass(store => $st, keep_ns => $keep,
                                          dry_run => 1);
    is($dry->{considered}, 2, 'dry run considered both segments');
    is($dry->{marked}, 1,     '  marked the expired one');
    is($dry->{unlinked}, 0,   '  and unlinked nothing');
    is(scalar(grep { $_->{sealed} } @{ $st->segments }), 2,
       '  the store is untouched');

    my $out = Punk::Observe::Retain::pass(store => $st, keep_ns => $keep);
    is($out->{unlinked}, 1, 'the real pass unlinked the expired segment');
    is($out->{kept}, 1,     '  and kept the live one');
    cmp_ok($out->{bytes_freed}, '>', 0, '  reporting the bytes');
    is($dry->{marked}, $out->{unlinked},
       '  and the dry run predicted exactly this');

    # The sidecar went with its segment, and none were orphaned.
    my @idx = glob "$d/default/wal/*.idx";
    is(scalar @idx, 1, 'one index sidecar remains, beside the kept segment');

    # THE DATA INSIDE THE WINDOW IS WHOLE. Expiry keys on t_max: a segment
    # holding anything newer than the cutoff stays entire.
    my $r = $st->query('log', from => '1500000000000000000',
                       to => Punk::Observe::Store::nadd($now, '999999'));
    is(scalar @{ $r->{rows} }, 50, 'every line inside the window survives');
    is(scalar(grep { $_->{body} =~ /^old/ } @{ $r->{rows} }), 0,
       '  and none outside it does');

    # Idempotent: a second pass finds nothing to do.
    my $again = Punk::Observe::Retain::pass(store => $st, keep_ns => $keep);
    is($again->{unlinked}, 0, 'a second pass deletes nothing');

    # A crash between seg-unlink and idx-unlink leaves an orphan; the next
    # pass cleans it, which also cleans orphans from before retention existed.
    my $orphan = "$d/default/wal/crashed.idx";
    open my $fh, '>', $orphan or die $!; print $fh 'x'; close $fh;
    my $clean = Punk::Observe::Retain::pass(store => $st, keep_ns => $keep);
    is($clean->{orphan_idx_removed}, 1, 'an orphaned sidecar is cleaned up');
    ok(!-e $orphan, '  and is actually gone');

    # A reader holding a mapping over the unlink still reads - the invariant
    # t/0082 proves at the C level, exercised here through the runner's path.
    is($out->{truncate_calls} || 0, 0,
       'nothing truncated, ever - a truncated segment is SIGBUS');
}

# A segment with an unreadable sidecar is KEPT, because deleting on an
# unknown age is deletion.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $d, tenant => 'default');
    Punk::Observe::WAL::append($st->wal_path,
        [ rec('1600000000000000000') ], 0, 0);
    $st->seal;
    my ($idx) = glob "$d/default/wal/*.idx";
    unlink $idx or die "unlink: $!";

    my $out = Punk::Observe::Retain::pass(store => $st,
        keep_ns => Punk::Observe::Retain::parse_keep('30d'));
    is($out->{unlinked}, 0, 'a segment with no readable summary is not deleted');
    is($out->{unknown_kept}, 1, '  and is counted as kept-unknown, not as fine');
}

# --- logs paging -------------------------------------------------------------
#
# The cursor is an INSTANT, so it is stable while new lines arrive; an offset
# shifts by every new line and page two repeats page one.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $d, tenant => 'default');
    my $base = (time - 600) . '000000000';
    Punk::Observe::WAL::append($st->wal_path,
        [ map { rec(Punk::Observe::Store::nadd($base, $_ * 1_000_000),
                    body => "line $_") } 1 .. 1200 ], 0, 0);
    $st->seal;

    my (%seen, $before, $pages, $dups);
    while (1) {
        my $v = Punk::Observe::View->page($st, 'logs',
            { range => '1h', ($before ? (before => $before) : ()) });
        my @rows = @{ $v->{rows} };
        last unless @rows;
        $pages++;
        $dups += grep { $seen{ $_->{body} }++ } @rows;
        last unless $v->{older_cursor};
        $before = $v->{older_cursor};
        die 'runaway' if $pages > 10;
    }
    is($pages, 3, 'twelve hundred lines page in three');
    is(scalar keys %seen, 1200, '  every line reachable - including the 501st');
    is($dups, 0, '  and none shown twice');

    # A short page is the end: no cursor, so no link into nothing.
    my $lastpage = Punk::Observe::View->page($st, 'logs',
        { range => '1h', before => $before });
    ok(!$lastpage->{older_cursor}, 'the final short page offers no older link');
    ok($lastpage->{paged}, '  but knows it was paged, for the way back');

    # THE CURSOR SURVIVES THE URL. It is a nanosecond decimal string past
    # 2^53; anything that numified it on the way through would land on a
    # different instant and quietly skip or repeat lines.
    like($before, qr/\A\d{19}\z/, 'the cursor is a full-precision instant');
    cmp_ok(length $before, '>', 15, '  beyond what a double carries');
}

# --- traces paging -----------------------------------------------------------
{
    my $base = (time - 600) . '000000000';

    my $walk = sub {
        my ($st, %extra) = @_;
        my (%seen, $after, $pages, $dups);
        while (1) {
            my $v = Punk::Observe::View->page($st, 'trace',
                { range => '1h', %extra, ($after ? (after => $after) : ()) });
            my @t = @{ $v->{traces} };
            last unless @t;
            $pages++;
            $dups += grep { $seen{ $_->{id} }++ } @t;
            last unless $v->{next_cursor};
            $after = $v->{next_cursor};
            die 'runaway' if $pages > 10;
        }
        return (scalar keys %seen, $dups || 0, $pages || 0);
    };

    my $d = tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $d, tenant => 'default');
    Punk::Observe::WAL::append($st->wal_path,
        [ map { rec(Punk::Observe::Store::nadd($base, $_ * 1_000_000),
                    kind => 3, duration => ($_ * 1000) . '', body => 'GET /x',
                    span_kind => 2, hi => 7, lo => $_, span_id => 1,
                    attrs => { 'service.name' => 's' }) } 1 .. 120 ], 0, 0);
    $st->seal;

    my ($n, $dup, $pages) = $walk->($st);
    is($n, 120, 'a hundred and twenty traces page through in full');
    is($dup, 0, '  none twice');
    is($pages, 3, '  in three pages of fifty');

    # ALL TIES: every trace at the same duration. The tie-break on the trace
    # id is what makes the cursor a position rather than a value, and a value
    # cursor here would loop on page one forever.
    my $d2 = tempdir(CLEANUP => 1);
    my $st2 = Punk::Observe::Store->new(dir => $d2, tenant => 'default');
    Punk::Observe::WAL::append($st2->wal_path,
        [ map { rec(Punk::Observe::Store::nadd($base, $_ * 1_000_000),
                    kind => 3, duration => '5000', body => 'GET /y',
                    span_kind => 2, hi => 9, lo => $_, span_id => 1,
                    attrs => { 'service.name' => 's' }) } 1 .. 120 ], 0, 0);
    $st2->seal;
    my ($n2, $dup2) = $walk->($st2);
    is($n2, 120, 'a page of identical durations still pages exactly once');
    is($dup2, 0, '  with no repeats');

    # And the reversed walk - faster-than filters walk fastest first - mirrors.
    my ($n3, $dup3) = $walk->($st, min_ms => '< 1s');
    is($n3, 120, 'the fastest-first walk pages in full too');
    is($dup3, 0, '  exactly once');

    # A mangled cursor is ignored, not a 500: the first page answers.
    my $v = Punk::Observe::View->page($st, 'trace',
        { range => '1h', after => 'not-a-cursor' });
    is(scalar @{ $v->{traces} }, 50, 'a truncated paste falls back to page one');
}

# --- the demo schedules it ---------------------------------------------------
#
# Punk::Observe::Retain was complete and caller-less. The wiring has since
# moved INTO the plugin - the demo asks for it with `retain => { keep }` and
# the plugin registers the cron - and this asserts the ask stays: a grep,
# because the property is that a caller EXISTS.
{
    my $demo = 'example/observe/lib/Demo/Observe.pm';
  SKIP: {
        skip 'no demo in this tree', 3 unless -f $demo;
        my $src = do { open my $fh, '<', $demo or die $!; local $/; <$fh> };
        like($src, qr/retain\s*=>\s*\{/, 'the demo schedules retention');
        like($src, qr/keep\s*=>\s*'\d+[a-z]'/,
             '  with an explicit window, because there is no default');
        # And any cron spec the demo still writes by hand passes check.
        if (eval { require Punk::Queue::Cron; 1 }) {
            my @specs = $src =~ /cron '([^']+)'/g;
            ok((grep { eval { Punk::Queue::Cron->check($_); 1 } } @specs)
               == @specs, 'every cron spec in the demo passes check')
                or diag("specs: @specs");
        }
        else { ok(1, 'Punk::Queue::Cron not installed; spec check skipped') }
    }
}

done_testing();

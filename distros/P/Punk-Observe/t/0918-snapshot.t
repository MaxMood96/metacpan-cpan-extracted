#!perl
# The segment snapshot: what every read knows about the sealed segments,
# discovered once instead of once per call.
#
# Before it existed, every records/rows/query/stats call re-did a readdir, a
# string sort of every segment name and a sidecar open PER SEGMENT - on a
# 758-segment store that was most of every page load. The snapshot is keyed
# on the wal directory's mtime, which every set-changing event (seal, new
# live log, retention unlink) touches - and NOT on anything about the live
# logs, whose appends touch only the file.
#
# The mtime key is seconds, so a second change in the same second would be
# invisible. The guard: a snapshot whose key second is within two seconds of
# now is rebuilt regardless. These tests script that exact interleaving
# rather than hoping a sleep lands on the right side of a tick.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;

my $S  = 'Punk::Observe::Store';
my $T0 = '1774224000000000000';

sub nadd {
    my ($a, $b) = @_;
    my @a = reverse split //, "$a";
    my @b = reverse split //, "$b";
    my ($carry, @out) = (0);
    for my $i (0 .. (@a > @b ? $#a : $#b)) {
        my $d = ($a[$i] || 0) + ($b[$i] || 0) + $carry;
        $carry = $d >= 10 ? 1 : 0;
        push @out, $d % 10;
    }
    push @out, $carry if $carry;
    return join '', reverse @out;
}

sub logline {
    my (%o) = @_;
    return {
        kind => 2, t => $o{t}, body => $o{body},
        severity => 9, duration => 0,
        trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
        attrs => { 'service.name' => $o{service} || 'svc' },
    };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

# Three sealed segments with disjoint, known spans, one line each.
my @segs;
for my $i (0 .. 2) {
    my $t = nadd($T0, $i * 1_000_000_000);
    Punk::Observe::WAL::append($store->wal_path,
                               [ logline(t => $t, body => "line $i") ], 0, 0);
    push @segs, scalar $store->seal;
}
ok(-d $wdir, 'the wal directory exists');
is(scalar(grep { $_ && -f $_ } @segs), 3, 'three sealed segments');

# Age the directory so the snapshot is REUSABLE: the racy guard rebuilds
# while the key second is within two seconds of now, and these files were
# all just written.
sub age { ok(utime($_[0], $_[0], $wdir), "the wal dir mtime is set back") }

my $past = time - 60;
age($past);

# --- repeat-call identity, and the build happens once ------------------------
{
    my ($r1) = $store->records;
    is(scalar @$r1, 3, 'the first call answers everything');
    my $b1 = $store->{_snap}{builds};
    is($b1, 1, '  and built the snapshot once');

    my ($r2) = $store->records;
    is_deeply([ map { $_->{body} } @$r2 ],
              [ map { $_->{body} } @$r1 ],
              'a second call answers identically');
    is($store->{_snap}{builds}, $b1,
       '  from the SAME snapshot - no rebuild without a directory change');
}

# --- the window skip runs off the snapshot -----------------------------------
{
    my ($r, $meta) = $store->records(from => nadd($T0, 2_000_000_000),
                                     to   => nadd($T0, 3_000_000_000));
    is(scalar @$r, 1, 'a narrow window answers one record');
    is($r->[0]{body}, 'line 2', '  the right one');
    is($meta->{skipped}, 2, '  and the other two segments were never opened');
}

# --- a seal between calls is seen --------------------------------------------
#
# The mutant this kills skips the stat and trusts whatever snapshot exists:
# the new segment's record then never appears.
{
    my $t = nadd($T0, 9_000_000_000);
    Punk::Observe::WAL::append($store->wal_path,
                               [ logline(t => $t, body => 'sealed later') ],
                               0, 0);
    $store->seal;

    my ($r) = $store->records;
    is(scalar @$r, 4, 'a seal after the snapshot was built is found');
    is($r->[0]{body}, 'sealed later', '  and is the newest answer');
    cmp_ok($store->{_snap}{builds}, '>', 1, '  because the key rebuilt');
}

# --- the racy window: a same-second change cannot go stale -------------------
#
# The seal above set the directory mtime to NOW, and the key is seconds. A
# second seal in the same second leaves the key unchanged, so validity must
# not rest on the key alone: within two seconds of the key, every call
# rebuilds. Kill the guard and `after racy seal` fails.
{
    my $b = $store->{_snap}{builds};
    my ($r) = $store->records;
    is(scalar @$r, 4, 'a call inside the racy window still answers');
    cmp_ok($store->{_snap}{builds}, '>', $b,
           '  and rebuilt rather than trusting a same-second key');

    my $t = nadd($T0, 10_000_000_000);
    Punk::Observe::WAL::append($store->wal_path,
                               [ logline(t => $t, body => 'after racy seal') ],
                               0, 0);
    $store->seal;
    ($r) = $store->records;
    is($r->[0]{body}, 'after racy seal',
       'a seal in the same second as the snapshot key is still found');
}

# --- an unlink between build and read is tolerated ---------------------------
#
# The scripted race: the snapshot names a segment, the segment vanishes, and
# the directory mtime is put back to the EXACT second the key holds - so the
# snapshot stays valid and the read meets a name with no file behind it.
# That is retention unlinking under a reader's feet, pinned. The read skips
# it; nothing dies.
{
    age($past);
    my ($r) = $store->records;    # snapshot rebuilt against $past, 5 segs
    is(scalar @$r, 5, 'five records before the unlink');

    my ($victim) = grep { -f $_ } @segs;
    (my $vidx = $victim) =~ s/\.seg\z/.idx/;
    unlink $victim, $vidx;
    age($past);                   # same key: the snapshot is NOT rebuilt

    my ($r2, $meta) = $store->records;
    is(scalar @$r2, 4, 'a vanished segment is skipped, not fatal');
    ok(!(grep { $_->{body} eq 'line 0' } @$r2), '  its record is gone');

    # And once the change is allowed to show, the rebuild drops the name.
    age($past + 5);
    my $b = $store->{_snap}{builds};
    $store->records;
    cmp_ok($store->{_snap}{builds}, '>', $b, 'the rebuild noticed');
    is(scalar @{ $store->{_snap}{segs} }, 4, '  and dropped the name');
}

# --- a segment with no sidecar is never skipped ------------------------------
#
# An interrupted seal leaves a .seg with no .idx. Its span is unknown, so no
# window may skip it: the mutant that skips on "no sidecar" silently loses
# whatever the segment held.
{
    my $t = nadd($T0, 4_000_000_000);
    Punk::Observe::WAL::append($store->wal_path,
                               [ logline(t => $t, body => 'unindexed') ], 0, 0);
    my $seg = $store->seal;
    (my $idx = $seg) =~ s/\.seg\z/.idx/;
    ok(unlink($idx), 'the sidecar is removed');
    age($past + 10);

    my ($r) = $store->records(from => nadd($T0, 4_000_000_000),
                              to   => nadd($T0, 5_000_000_000));
    is(scalar @$r, 1, 'a window still reads the unindexed segment');
    is($r->[0]{body}, 'unindexed', '  and finds its record');

    # stats says so, from the same snapshot.
    my $st = $store->stats;
    is($st->{unindexed}, 1, 'stats counts it as unindexed');
}

# --- stats answers from the snapshot -----------------------------------------
{
    # An orphaned index: the other half of an interrupted retention pass.
    my $orph = File::Spec->catfile($wdir, 's9999999999-1-9.idx');
    open my $fh, '>', $orph or die $!;
    print $fh "records\t1\nt_min\t1\nt_max\t2\n";
    close $fh;
    age($past + 20);

    my $st = $store->stats;
    is($st->{segments}, 5, 'stats counts the sealed segments');
    # Four, not five: the unindexed segment has no sidecar to read a count
    # from, and `unindexed` is how stats says the total is short.
    is($st->{records}, 4, '  and their records, from the sidecars');
    is($st->{orphan_index}, 1, '  and the orphaned index');
    ok($st->{service}{svc}, '  and merges the per-segment service tables');

    # CREATING a live log touches the directory (a new name), so it needs a
    # rebuild to be seen...
    Punk::Observe::WAL::append($store->wal_path,
                               [ logline(t => nadd($T0, 5_000_000_000),
                                         body => 'live') ], 0, 0);
    age($past + 30);
    my $st2 = $store->stats;
    is($st2->{wal_depth}, 1, 'a new live log is seen after its rebuild');
    is($st2->{records}, 5, '  and its records are counted');

    # ...but an APPEND to it touches only the file, and must be counted with
    # no rebuild at all: nothing about a live log is ever cached.
    my $b = $store->{_snap}{builds};
    Punk::Observe::WAL::append($store->wal_path,
                               [ logline(t => nadd($T0, 6_000_000_000),
                                         body => 'live 2') ], 0, 0);
    my $st3 = $store->stats;
    is($st3->{records}, 6, 'a live append is counted');
    is($store->{_snap}{builds}, $b, '  without any rebuild');
}

done_testing();

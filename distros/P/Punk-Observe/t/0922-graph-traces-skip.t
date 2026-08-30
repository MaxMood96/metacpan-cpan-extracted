#!perl
# The window skip for graph() and traces().
#
# Both used to slurp every file in the store on every call - deliberately,
# because a graph derived from one file at a time attributes cross-file
# children to the synthetic root. The invariant stays: everything INSIDE the
# window is still gathered into one span set. What changed is that a sealed
# segment provably OUTSIDE the window, or provably span-free, is no longer
# read at all - and the result says so in `files`/`skipped`, so these tests
# assert the pruning happened rather than inferring it from timing.
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

sub span {
    my (%o) = @_;
    return {
        kind => 3, t => $o{t}, duration => $o{dur} || '1000000',
        body => $o{name}, severity => 0, status => $o{status} || 0,
        span_kind => $o{span_kind} || 2,
        trace_hi => $o{hi}, trace_lo => $o{lo},
        span_id => $o{id}, parent_id => $o{parent} || 0,
        attrs => { 'service.name' => $o{service} },
    };
}
sub logline {
    my (%o) = @_;
    return { kind => 2, t => $o{t}, body => $o{body} || 'x', severity => 9,
             duration => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
             parent_id => 0, attrs => { 'service.name' => $o{service} || 'q' } };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

# Segment 0: the PARENT span, in-window. Segment 1: its CHILD, also
# in-window but in a different file - the cross-file case the one-set
# invariant exists for. Segment 2: a whole trace far OUTSIDE the window.
# Segment 3: logs only - no spans to gather at all.
my $IN  = nadd($T0, 100_000_000_000);
Punk::Observe::WAL::append($store->wal_path,
    [ span(t => $IN, name => 'GET /checkout', service => 'shop',
           hi => 1, lo => 1, id => 1) ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ span(t => nadd($IN, 1_000_000), name => 'POST /authorize',
           service => 'cards', hi => 1, lo => 1, id => 2, parent => 1,
           span_kind => 3) ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ span(t => $T0, name => 'old thing', service => 'attic',
           hi => 9, lo => 9, id => 1) ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ logline(t => $IN, service => 'quiet') ], 0, 0);
$store->seal;
utime(time - 60, time - 60, $wdir) or die "utime: $!";

my ($FROM, $TO) = (nadd($T0, 90_000_000_000), nadd($T0, 110_000_000_000));

# --- graph: cross-file merge survives the skip -------------------------------
{
    my $g = $store->graph(from => $FROM, to => $TO);

    # The content assertion kills the over-skip mutant: parent and child sit
    # in different files, and only one edge may come out.
    my ($edge) = grep { $_->{caller} eq 'shop' } @{ $g->{edges} };
    ok($edge, 'the cross-file edge exists');
    is($edge && $edge->{callee}, 'cards', '  parent file met child file');
    ok(!(grep { $_->{callee} eq 'attic' } @{ $g->{edges} }),
       'the out-of-window trace is not drawn');

    # The counter kills the no-skip mutant: the attic segment is outside the
    # window and the quiet segment has no spans; neither was slurped for the
    # gather.
    is($g->{skipped}, 2, 'two segments were never read for spans');
    is($g->{files}, 2, '  and two were');

    # The services table stays the STORE's, not the window's - per-record,
    # from every sidecar, as it always was.
    ok($g->{services}{attic}, 'services still count the out-of-window segment');
    ok($g->{services}{quiet}, '  and the span-free one');
}

# --- traces: same window, same set -------------------------------------------
{
    my $t = $store->traces(from => $FROM, to => $TO, limit => 10);
    is(scalar @{ $t->{traces} }, 1, 'one trace in the window');
    is($t->{traces}[0]{spans}, 2, '  with both its cross-file spans');
    is($t->{skipped}, 2, '  two segments pruned');

    # A windowed answer equals the unwindowed one over the same in-window
    # data: the skip changed what was READ, never what was found.
    my $all = $store->traces(limit => 10);
    my ($win_t)  = grep { $_->{trace_lo} eq '1' } @{ $t->{traces} };
    my ($full_t) = grep { $_->{trace_lo} eq '1' } @{ $all->{traces} };
    is_deeply($win_t, $full_t,
              'the windowed summary IS the full-scan summary of that trace');
    is(scalar @{ $all->{traces} }, 2, '  and the full scan sees the attic too');
}

# --- one trace, assembled, ignores no file -----------------------------------
{
    my $tr = $store->trace(1, 1);
    ok($tr, 'the trace assembles');
    is(scalar @{ $tr->{spans} }, 2, '  from both files, unbounded by design');
}

done_testing();

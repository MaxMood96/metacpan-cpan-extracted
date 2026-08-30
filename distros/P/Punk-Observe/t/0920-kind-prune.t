#!perl
# The kind skip: a sidecar counting zero of the wanted kind proves the
# segment holds none, so a metrics read never opens a segment of logs.
#
# The proof only holds when the sidecar's per-kind counts are COMPLETE -
# they add up to `records`. A sidecar written before a counter existed reads
# zero for it, and zero-meaning-unrecorded must never prune: that mutant
# silently loses every record the segment holds.
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

sub rec {
    my ($kind, $off, $body) = @_;
    my $t = $T0; substr($t, -length($off)) = $off if $off;
    return {
        kind => $kind, t => $t, body => $body,
        severity => ($kind == 2 ? 9 : 0),
        duration => ($kind == 3 ? '1000000' : 0),
        ($kind == 3 ? (status => 0, span_kind => 2) : ()),
        trace_hi => ($kind == 3 ? 7 : 0), trace_lo => ($kind == 3 ? 7 : 0),
        span_id => ($kind == 3 ? 1 : 0), parent_id => 0,
        attrs => { 'service.name' => 'svc' },
    };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

# Segment 0: logs only. Segment 1: metrics only. Segment 2: mixed.
Punk::Observe::WAL::append($store->wal_path,
    [ rec(2, 0, 'log a'), rec(2, 0, 'log b') ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ rec(1, 0, 'metric.one') ], 0, 0);
$store->seal;
my @mixed = (rec(2, 0, 'log c'), rec(1, 0, 'metric.two'), rec(3, 0, 'GET /'));
Punk::Observe::WAL::append($store->wal_path, \@mixed, 0, 0);
my $mixed_seg = $store->seal;
utime(time - 60, time - 60, $wdir) or die "utime: $!";

# --- the prune ---------------------------------------------------------------
{
    my ($r, $m) = $store->records(kind => 1);
    is(scalar @$r, 2, 'a metrics read finds both metric records');
    is($m->{files}, 2, '  and never opened the logs-only segment');
    cmp_ok($m->{skipped}, '>=', 1, '  which the metadata counts as skipped');

    ($r, $m) = $store->records(kind => 3);
    is(scalar @$r, 1, 'a spans read finds the one span');
    is($m->{files}, 1, '  from the one segment that has any');

    # The over-skip mutant prunes any segment that is not PURELY the wanted
    # kind; the mixed segment's records are the canary.
    ($r, $m) = $store->records(kind => 2);
    is(scalar @$r, 3, 'a logs read still reads the MIXED segment');
    ok((grep { $_->{body} eq 'log c' } @$r),
       '  and its log line is in the answer');
}

# --- an incomplete sidecar never prunes --------------------------------------
#
# Rewrite the mixed segment's sidecar with the per-kind lines missing, as a
# sidecar from before those counters existed: records says 3, the kinds say
# nothing. Every kind must still read it.
{
    (my $idx = $mixed_seg) =~ s/\.seg\z/.idx/;
    open my $in, '<', $idx or die $!;
    my @keep = grep { !/^(?:logs|metrics|spans)\t/ } <$in>;
    close $in;
    open my $out, '>', $idx or die $!;
    print $out @keep;
    close $out;
    utime(time - 50, time - 50, $wdir) or die "utime: $!";

    # A FRESH store object: the incremental snapshot rebuild reuses a cached
    # entry by name (sealed segments and their sidecars are immutable in
    # production), so the running object would keep the original counts and
    # never re-read the rewritten sidecar. A new object parses it cold, the
    # way a new worker meets an old store.
    my $cold = $S->new(dir => $dir, tenant => 'acme');

    my ($r, $m) = $cold->records(kind => 3);
    is(scalar @$r, 1,
       'a sidecar without kind counts still has its segment read');
    is($r->[0]{body}, 'GET /', '  and the span is found');
}

done_testing();

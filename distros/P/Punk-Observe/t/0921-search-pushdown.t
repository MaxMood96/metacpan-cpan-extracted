#!perl
# The needle pushdown: a query with a `search` term or a metric name skips
# whole segments in which the bytes appear NOWHERE, before a single row hash
# is built.
#
# The needle is a conservative superset of the executor's filter and it may
# only ever say "nothing here" - never "this one matches". Each block below
# pins one side of that asymmetry, and names the mutant it kills.
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

sub logline {
    my ($body, %o) = @_;
    return { kind => 2, t => $T0, body => $body, severity => 9, duration => 0,
             trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
             attrs => { 'service.name' => $o{service} || 'svc', %{ $o{attrs} || {} } } };
}
sub metric {
    my ($name) = @_;
    return { kind => 1, t => $T0, body => $name, severity => 0, duration => 0,
             value => 1, trace_hi => 0, trace_lo => 0, span_id => 0,
             parent_id => 0, attrs => { 'service.name' => 'svc' } };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

# Three segments. Only segment 1 contains "refused" anywhere; segment 2
# carries the bytes CASE-DIFFERENTLY; segment 0 not at all.
Punk::Observe::WAL::append($store->wal_path,
    [ logline('checkout complete'), metric('a.b.c') ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ logline('card refused: insufficient funds'), metric('a.b') ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ logline('order REFUSED by risk desk') ], 0, 0);
$store->seal;
utime(time - 60, time - 60, $wdir) or die "utime: $!";

# --- search skips segments without the bytes ---------------------------------
{
    my $r = $store->query('log | search "refused"');
    is($r->{ok}, 1, 'the search query runs');
    is(scalar @{ $r->{rows} }, 2, 'both refusals are found');

    # Kills the no-pushdown mutant: segment 0 has no "refused" in any case,
    # so its records are never decoded - `files` still counts it (its bytes
    # WERE read; the needle spares the decode, not the disk), but `scanned`
    # holds only the two needle-bearing segments' three records, not five.
    is($r->{store}{scanned}, 3, 'the segment without the bytes was not decoded');

    # Kills the fold-removal mutant: "REFUSED" only matches case-folded, at
    # the segment level AND in the executor.
    ok((grep { $_->{body} =~ /REFUSED/ } @{ $r->{rows} }),
       'the case-differing match survived the segment-level check');
}

# --- the needle never decides a row ------------------------------------------
#
# "refused" appears in segment 1's BODY but a search for "funds" also only
# appears there; a query whose `where` disagrees must still filter row by
# row. The mutant that treats a segment-level hit as a row-level match
# returns the checkout line here.
{
    my $r = $store->query(
        'log | where service = "nosuch" | search "refused"');
    is(scalar @{ $r->{rows} }, 0,
       'a segment-level hit still loses to the row-level where');
}

# --- the metric name prunes exactly, and exactly is a superset ---------------
{
    my $r = $store->query('metric a.b | count');
    is($r->{ok}, 1, 'the metric query runs');

    # `a.b` occurs as bytes inside segment 0's `a.b.c` too, so the needle
    # must NOT exclude segment 0 (substring, not equality)... and the
    # executor's exact body compare must then reject a.b.c. The mutant that
    # matches exactly at the segment level gives the same count with fewer
    # files - so BOTH numbers are pinned.
    is($r->{store}{files}, 2, 'both segments containing the bytes were read');
    my ($g) = @{ $r->{groups} || [] };
    is($g ? $g->{count} : undef, 1, 'and exactly one point counted');

    # And a name in no segment decodes nothing at all.
    my $none = $store->query('metric zz.not.here | count');
    is($none->{store}{scanned}, 0, 'a name in no segment decodes no record');
}

done_testing();

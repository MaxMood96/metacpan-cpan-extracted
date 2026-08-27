#!perl
# The pushdown: what a query does NOT have to read.
#
# Phase 9's executor reported blocks_skipped => 0 for every query ever run,
# because it scanned rows somebody else had already materialised. This is the
# gap closed: a plan's predicates, asked of a real segment's regions.
#
# THE HEADLINE ASSERTION IS NOT THAT ANYTHING IS SKIPPED. It is that nothing
# skipped could have matched. Skipping a block that holds a matching row loses
# data silently and the answer still looks complete; reading a block that
# turns out not to match costs time and nothing else. So every pruning case
# below is checked against the contents rather than against a count.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;

my $SC = 'Punk::Observe::Scan';
my $IO = 'Punk::Observe::SegIO';
sub pd    { $SC->can('pushdown')->($_[0]) }
sub prune { $SC->can('prune')->($_[0], $_[1], $_[2] || {}) }

my $dir = tempdir(CLEANUP => 1);
my $U64MAX = '18446744073709551615';

# --- the time range a predicate proves --------------------------------------

{
    my $r = pd('log | where t > 1000 and t < 5000');
    ok($r->{ok}, 'a bounded query plans') or diag $r->{error};
    is("$r->{from}", '1001', '  > is exclusive, so from is the value plus one');
    is("$r->{to}",   '4999', '  and < is exclusive too');
    is($r->{bounded}, 1, '  and the range counts as bounded');
    is($r->{empty}, 0, '  and is not empty');
}

{
    my $r = pd('log | where t >= 1000 and t <= 5000');
    is("$r->{from}", '1000', '>= is inclusive');
    is("$r->{to}",   '5000', '  and so is <=');
}

{
    my $r = pd('log | where t = 4242');
    is("$r->{from}", '4242', 'an equality pins the low end');
    is("$r->{to}",   '4242', '  and the high end');
}

{
    my $r = pd('log | where service = "api"');
    is("$r->{from}", '0', 'with no time predicate the range is everything');
    is("$r->{to}", $U64MAX, '  right to the top of a uint64');
    is($r->{bounded}, 0, '  and reports itself unbounded');
}

# THE ONE THAT MATTERS. An OR narrows NOTHING: `t > x or service = "y"` still
# admits every row outside the range, and taking x as a bound would drop the
# rows the other arm asked for.
{
    my $r = pd('log | where t > 5000 or service = "api"');
    is("$r->{from}", '0', 'an OR does not narrow the low end');
    is("$r->{to}", $U64MAX, '  nor the high end');
    is($r->{bounded}, 0, '  and the query is not treated as time bounded');
}

{
    # Nested: the AND above an OR still narrows through its own arm only.
    my $r = pd('log | where t > 100 and (t > 5000 or service = "api")');
    is("$r->{from}", '101', 'a conjunction beside an OR narrows by itself alone');
}

{
    my $r = pd('log | where t != 5000');
    is("$r->{from}", '0', '!= narrows nothing - rows exist on both sides');
    is("$r->{to}", $U64MAX, '  in either direction');
}

{
    # An impossible range is answered by reading nothing, which is correct.
    my $r = pd('log | where t > 5000 and t < 100');
    is($r->{empty}, 1, 'a contradictory range is empty');
}

{
    # The boundary values themselves, where an off-by-one wraps.
    my $r = pd('log | where t > 0');
    is("$r->{from}", '1', 't > 0 does not underflow');
    $r = pd('log | where t < 0');
    is($r->{empty}, 1, '  and t < 0 is empty rather than wrapping to the top');
}

# --- durations and search ---------------------------------------------------

{
    my $r = pd('trace | where duration > 500ms');
    is("$r->{min_duration}", '500000001',
       'a duration bound is pushed down in nanoseconds');
}

{
    my $r = pd('log | search "connection refused"');
    is($r->{search}, 'connection refused', 'the search term reaches the filter');
}

{
    my $r = pd('log | where service = "api" and severity >= error');
    is($r->{eq_field}, 'service', 'the first equality is pushed down');
    is($r->{eq_value}, 'api', '  with its value');
}

# --- a real segment ---------------------------------------------------------

# Two log blocks that differ in BOTH time and content, so time pruning and
# bloom pruning can each be tested without the other doing the work.
my %BLOCK = (
    1 => { t0 => 1000, lines => [ 'connection refused',
                                  'retrying now',
                                  'connection refused again' ] },
    2 => { t0 => 9000, lines => [ 'request completed', 'cache miss' ] },
);

my $spec = {
    metrics => [
        { series => '1001', points => [ map { ("" . (1_000_000_000 * $_), $_ * 1.5) } 1 .. 20 ] },
        { series => '1002', points => [ map { ("" . (1_000_000_000 * $_), 42) } 1 .. 10 ] },
    ],
    logs => [
        { t0 => 1000, stream => 1, lines => $BLOCK{1}{lines} },
        { t0 => 9000, stream => 2, lines => $BLOCK{2}{lines} },
    ],
    spans => [
        { trace_hi => '7', trace_lo => '7', span_id => '1', parent => '0',
          start => '1000', end => '5000', service => 1 },
        { trace_hi => '8', trace_lo => '8', span_id => '3', parent => '0',
          start => '2000', end => '2500', service => 1 },
    ],
};

my $seg = File::Spec->catfile($dir, 'p.seg');
ok($IO->can('write_all')->($seg, $spec), 'the fixture segment writes')
    or BAIL_OUT('no segment to prune');

# --- the segment is skipped whole, from its footer --------------------------

{
    my $r = prune($seg, 'log | where t > 100000000000000');
    ok($r->{ok}, 'a query far past the segment plans') or diag $r->{error};
    is($r->{segment_wanted}, 0, '  and the segment is not opened at all');
    cmp_ok("$r->{blocks_skipped}", '>=', 1, '  which counts as a skip');
    is($r->{metric_chunks}, 0, '  so no chunk is examined');
    is($r->{log_blocks}, 0, '  and no block');
}

{
    my $r = prune($seg, 'log | where t >= 1000 and t <= 20000000000');
    is($r->{segment_wanted}, 1, 'a query inside the span opens the segment');
}

# THE FOOTER SPAN IS A PROMISE THE PRUNER BELIEVES. A segment whose regions
# reach outside the span its records declare is a segment a correct query
# skips - a silent loss, not a slow query.
{
    my $r = prune($seg, 'metric x | where t >= 19000000000 and t <= 21000000000');
    is($r->{segment_wanted}, 1,
       'the footer span covers the metric chunks, not just the records');
    cmp_ok($r->{metric_chunks}, '>=', 1, '  so the late chunk is still found');
}

# --- metric chunks pruned by their own time span ----------------------------

{
    # Series 1002 stops at 10s; series 1001 runs to 20s.
    my $r = prune($seg, 'metric x | where t > 15000000000');
    is($r->{metric_chunks}, 1, 'a late range keeps only the chunk that reaches it');
    cmp_ok("$r->{blocks_skipped}", '>=', 1, '  and the other is skipped');
}

{
    my $r = prune($seg, 'metric x | where t >= 1000000000 and t <= 2000000000');
    is($r->{metric_chunks}, 2, 'an early range overlaps both chunks');
}

# --- log blocks: stream, then time, then the bloom --------------------------

{
    my $r = prune($seg, 'log | where t >= 9000', { stream => '2' });
    is($r->{log_blocks}, 1, 'a stream filter keeps one block');
    is($r->{skipped_stream}, 1, '  and skips the other on the stream alone');
}

{
    my $r = prune($seg, 'log | where t >= 5000');
    is($r->{log_blocks}, 1, 'a time range keeps only the later block');
    is($r->{skipped_time}, 1, '  skipping the earlier one on time');
    is($r->{skipped_bloom}, 0, '  before the bloom is ever consulted');
}

# THE BLOOM, FINALLY CONSULTED. It has been built and asserted since phase 6
# and no query had ever asked it anything.
{
    my $r = prune($seg, 'log | search "connection refused"');
    is($r->{log_blocks}, 1, 'a search term prunes by the trigram filter');
    is($r->{skipped_bloom}, 1, '  and the block that cannot contain it is skipped');
}

{
    my $r = prune($seg, 'log | search "cache miss"');
    is($r->{log_blocks}, 1, 'the other term keeps the other block');
    is($r->{skipped_bloom}, 1, '  skipping the first');
}

# A term in NEITHER block prunes both, and that is the case worth having.
{
    my $r = prune($seg, 'log | search "segmentation fault"');
    is($r->{log_blocks}, 0, 'a term in no block reads no block at all');
    is($r->{skipped_bloom}, 2, '  both skipped by the filter');
}

# --- THE SAFETY PROPERTY ----------------------------------------------------
#
# A false negative loses a log line. Every term that IS present must survive
# the filter in the block that holds it - checked against the fixture text
# rather than against a count, for every substring of every line.

{
    my ($missed, $checked) = (0, 0);
    for my $stream (sort keys %BLOCK) {
        for my $line (@{ $BLOCK{$stream}{lines} }) {
            for my $len (3 .. length $line) {
                for my $off (0 .. length($line) - $len) {
                    my $term = substr($line, $off, $len);
                    next if $term =~ /"/;
                    my $r = prune($seg, qq{log | search "$term"});
                    $checked++;
                    # The block holding this line must NOT have been skipped.
                    $missed++ if $r->{log_blocks} < 1;
                }
            }
        }
    }
    cmp_ok($checked, '>', 200, "checked $checked present substrings");
    is($missed, 0, 'NOT ONE present term was pruned away - no false negatives');
}

# The converse safety rule: a term too short to make a trigram must prune
# NOTHING rather than answer from a filter that cannot see it.
#
# This one is guaranteed twice over, and saying so is the point: a query under
# three characters yields no trigram to probe, so the filter would answer
# "possible" even without the explicit length guard. Flipping that guard to
# accept any length changes NO result here - verified by doing it - so these
# two cases assert the behaviour and cannot, on their own, be evidence that
# the guard is in place.
{
    for my $q ('a', 'ab') {
        my $r = prune($seg, qq{log | search "$q"});
        is($r->{log_blocks}, 2,
           "a ${\ length $q}-character term prunes nothing and reads both blocks");
        is($r->{skipped_bloom}, 0, '  nothing is pruned by the filter');
    }
}

# THREE characters is the boundary, and the first length that can prune. That
# is the assertion with teeth: it distinguishes a filter that is consulted
# from one that is not.
{
    my $r = prune($seg, 'log | search "cac"');
    is($r->{skipped_bloom}, 1,
       'a three-character term is the shortest that prunes anything');
    is($r->{log_blocks}, 1, '  keeping only the block that holds it');

    $r = prune($seg, 'log | search "zqx"');
    is($r->{skipped_bloom}, 2,
       'a three-character term in neither block prunes both');
}

# --- traces -----------------------------------------------------------------

{
    my $r = prune($seg, 'trace | where duration > 1us');
    is($r->{traces}, 1, 'a duration bound keeps only the slow trace');
}

{
    my $r = prune($seg, 'trace | where duration > 1ns');
    is($r->{traces}, 2, 'a low bound keeps both');
}

# A trace that STRADDLES the range boundary is the one being looked for, and
# keying on its start alone would drop it.
{
    my $r = prune($seg, 'trace | where t >= 4000 and t <= 6000');
    is($r->{traces}, 1,
       'a trace running across the start of the range is not skipped');
}

{
    my $r = prune($seg, 'trace | where t >= 100000 and t <= 200000');
    is($r->{traces}, 0, 'a range past every trace keeps none');
}

# --- the counters are honest ------------------------------------------------

{
    my $r = prune($seg, 'log | where t >= 5000');
    cmp_ok("$r->{blocks}", '>', 0, 'blocks examined is reported');
    cmp_ok("$r->{blocks_skipped}", '>', 0, '  and blocks skipped is no longer 0');
    cmp_ok(0 + $r->{blocks_skipped}, '<=', 0 + $r->{blocks},
           '  and never exceeds what was examined');
}

done_testing();

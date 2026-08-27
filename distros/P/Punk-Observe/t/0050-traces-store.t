#!perl
# Spans, and the tree assembled when they are READ.
#
# The headline property: a trace is never complete, so nothing waits for one.
# A span arriving out of order, in a later batch, or an hour late still joins.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $T = 'Punk::Observe::Trace';
sub analyse { $T->can('analyse')->($_[0]) }

# Services are symbol ids in a segment; the test uses small integers.
use constant { SVC_GATEWAY => 1, SVC_CHECKOUT => 2, SVC_DB => 3 };
use constant { ST_UNSET => 0, ST_OK => 1, ST_ERROR => 2 };

is($T->can('span_size')->(), 64, 'a span head is the declared 64 bytes');

# --- assembly ---------------------------------------------------------------

# A three-level trace, given DELIBERATELY OUT OF ORDER and with the root last.
# A backend that decided rootness at write time would report three roots.
{
    my $spans = [
        { trace_hi => '111', trace_lo => '222', span_id => '30', parent => '20',
          start => '3000', end => '3500', service => SVC_DB },
        { trace_hi => '111', trace_lo => '222', span_id => '20', parent => '10',
          start => '2000', end => '4000', service => SVC_CHECKOUT },
        { trace_hi => '111', trace_lo => '222', span_id => '10', parent => '0',
          start => '1000', end => '5000', service => SVC_GATEWAY },
    ];
    my $r = analyse($spans);
    is($r->{spans}, 3, 'three spans');
    is($r->{traces}, 1, 'one trace');
    is($r->{roots}, 1, 'EXACTLY ONE root, even though the root arrived last');
    is($r->{cycles}, 0, 'no cycles');
    is($r->{orphans}, 0, 'no orphans');

    # Sorted by (trace, start), so the tree is already in waterfall order.
    my @depth = map { $_->{depth} } @{ $r->{tree} };
    is_deeply(\@depth, [ 0, 1, 2 ],
              'depths are 0,1,2 in start order after the seal sort');
}

# The same trace split across two "batches" - which is what actually happens,
# since spans come from different processes.
{
    my $first  = [ { trace_hi => '1', trace_lo => '1', span_id => '20',
                     parent => '10', start => '2000', end => '3000',
                     service => SVC_CHECKOUT } ];
    my $r1 = analyse($first);
    is($r1->{roots}, 1, 'a child alone is a root FOR NOW');
    is($r1->{orphans}, 1, '  and is counted as an orphan, so the gap is visible');

    my $both = [ @$first,
        { trace_hi => '1', trace_lo => '1', span_id => '10', parent => '0',
          start => '1000', end => '4000', service => SVC_GATEWAY } ];
    my $r2 = analyse($both);
    is($r2->{roots}, 1, 'once the parent arrives there is still one root');
    is($r2->{orphans}, 0, '  and no orphan');
    is($r2->{tree}[1]{depth}, 1, '  the late child is now at depth 1');
}

# --- cycles -----------------------------------------------------------------

# Broken instrumentation produces these, and a naive walk recurses forever.
{
    my $spans = [
        { trace_hi => '9', trace_lo => '9', span_id => '1', parent => '2',
          start => '1000', end => '2000', service => 1 },
        { trace_hi => '9', trace_lo => '9', span_id => '2', parent => '1',
          start => '1001', end => '2000', service => 1 },
    ];
    my $r = eval { analyse($spans) };
    ok(defined $r, 'a two-span parent cycle does not hang');
    is($r->{cycles}, 2, '  both spans are reported as cyclic');
    is($r->{roots}, 0, '  and neither is called a root');
}

{
    # A long chain that is NOT a cycle must not be mistaken for one.
    my @s;
    for my $i (1 .. 50) {
        push @s, { trace_hi => '7', trace_lo => '7', span_id => "$i",
                   parent => ($i == 1 ? '0' : "" . ($i - 1)),
                   start => "" . (1000 + $i), end => "" . (9000 - $i),
                   service => 1 };
    }
    my $r = analyse(\@s);
    is($r->{cycles}, 0, 'a 50-deep chain is not mistaken for a cycle');
    is($r->{roots}, 1, '  and has one root');
    is($r->{tree}[49]{depth}, 49, '  with the deepest span at depth 49');
}

# --- clock steps ------------------------------------------------------------

# end < start means the wall clock stepped. In a u64 that subtraction is
# ~1.8e19, not a small negative number.
{
    my $r = analyse([
        { trace_hi => '1', trace_lo => '2', span_id => '1', parent => '0',
          start => '1774224000000000000', end => '1774223999000000000',
          service => 1 } ]);
    is($r->{clamped}, 1, 'a backwards duration is clamped and counted');
    is("$r->{by_duration}[0]{duration}", '0', '  and stored as zero, not 1.8e19');
}

# --- several traces ---------------------------------------------------------

{
    my @s;
    for my $t (1 .. 20) {
        for my $sp (1 .. 5) {
            push @s, {
                trace_hi => "$t", trace_lo => "" . ($t * 7),
                span_id  => "" . ($t * 100 + $sp),
                parent   => ($sp == 1 ? '0' : "" . ($t * 100 + $sp - 1)),
                start    => "" . (1_000_000 + $t * 1000 + $sp),
                end      => "" . (1_000_000 + $t * 1000 + 500),
                service  => ($sp % 3) + 1,
                status   => ($t % 4 == 0 && $sp == 3) ? ST_ERROR : ST_OK,
            };
        }
    }
    my $r = analyse(\@s);
    is($r->{spans}, 100, '100 spans');
    is($r->{traces}, 20, 'across 20 traces');
    ok($r->{any_error}, 'the segment records that it holds an error span');

    my $with_err = grep { $_->{errors} > 0 } @{ $r->{by_duration} };
    is($with_err, 5, 'five traces carry an error');

    my $total = 0; $total += $_->{spans} for @{ $r->{by_duration} };
    is($total, 100, 'every span is accounted for in exactly one trace');
}

# A segment with no error span says so, which is what lets an error query skip
# it without opening anything.
{
    my $r = analyse([
        { trace_hi => '1', trace_lo => '1', span_id => '1', parent => '0',
          start => '1000', end => '2000', service => 1, status => ST_OK } ]);
    ok(!$r->{any_error}, 'a segment with no error span reports none');
}

# --- the empty case ---------------------------------------------------------

{
    my $r = analyse([]);
    is($r->{spans}, 0, 'no spans');
    is($r->{traces}, 0, '  no traces');
    is_deeply($r->{edges}, [], '  and no edges');
}

done_testing();

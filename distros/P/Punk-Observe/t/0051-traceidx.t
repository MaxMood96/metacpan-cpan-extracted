#!perl
# The trace-id index and duration search.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $T = 'Punk::Observe::Trace';

sub spans_for {
    my ($n, $per) = @_;
    my @s;
    for my $t (1 .. $n) {
        for my $sp (1 .. $per) {
            # Exact small integers. The first draft multiplied by a 64-bit
            # constant and took a modulus, which in Perl overflows to an NV
            # and collapsed 1000 ids down to 12 - a broken FIXTURE that looked
            # exactly like a broken hash table.
            push @s, {
                trace_hi => "" . ($t * 2 + 1),
                trace_lo => "" . ($t * 7919),
                span_id  => "" . ($t * 1000 + $sp),
                parent   => ($sp == 1 ? '0' : "" . ($t * 1000 + $sp - 1)),
                start    => "" . (1_000_000_000 + $t * 1000 + $sp),
                end      => "" . (1_000_000_000 + $t * 1000 + $sp + $t * 13),
                service  => ($sp % 3) + 1,
            };
        }
    }
    return \@s;
}

# --- every id is found, none falsely ---------------------------------------

{
    my $spans = spans_for(1000, 3);
    my %ids;
    $ids{"$_->{trace_hi}/$_->{trace_lo}"} = 1 for @$spans;
    my @lookups = map { split m{/} } sort keys %ids;

    my $r = $T->can('index_probe')->($spans, \@lookups);
    is($r->{distinct}, 1000, '1000 distinct traces indexed');
    is($r->{found}, 1000, '  every one is found');
    is($r->{missing}, 0, '  none missing');

    my $bad = grep { $_ != 3 } @{ $r->{counts} };
    is($bad, 0, '  and each reports its three spans');

    # The table must not have degenerated into a scan.
    my $avg = $r->{probes} / $r->{lookups};
    diag(sprintf('%d slots for %d traces, %.2f probes per lookup',
                 $r->{slots}, $r->{distinct}, $avg));
    cmp_ok($avg, '<', 2.0, 'lookups average under two probes');
}

# Absent ids must not be found. A hash that returned a neighbour would merge
# two traces, which is the most confusing failure this system can produce.
{
    my $spans = spans_for(500, 2);
    my @absent;
    push @absent, ("" . (900000000 + $_), "" . (800000000 + $_)) for 1 .. 200;
    my $r = $T->can('index_probe')->($spans, \@absent);
    is($r->{found}, 0, 'not one of 200 absent trace ids is found');
    is($r->{missing}, 200, '  all reported missing');
}

# --- the full 16 bytes are compared ----------------------------------------

# Ids sharing one half must stay distinct. Storing or comparing only 64 bits
# would merge these.
{
    my @s;
    my @pairs = ( ['12345','1'], ['12345','2'], ['1','12345'], ['2','12345'] );
    for my $i (0 .. $#pairs) {
        push @s, { trace_hi => $pairs[$i][0], trace_lo => $pairs[$i][1],
                   span_id => "" . ($i + 1), parent => '0',
                   start => "" . (1000 + $i), end => "" . (2000 + $i),
                   service => 1 };
    }
    my $r = $T->can('index_probe')->(\@s, [ map { @$_ } @pairs ]);
    is($r->{distinct}, 4, 'four ids sharing a half are four distinct traces');
    is($r->{found}, 4, '  and all four are found');
    my $bad = grep { $_ != 1 } @{ $r->{counts} };
    is($bad, 0, '  each with its own single span, not merged');
}

# --- sizing comes from the DISTINCT trace count ----------------------------

# A segment with many spans across few traces needs few slots. Sizing from the
# span count would waste almost all of them.
{
    my $few  = $T->can('index_probe')->(spans_for(10, 100), []);
    my $many = $T->can('index_probe')->(spans_for(1000, 1), []);
    is($few->{distinct}, 10, '10 traces of 100 spans is 10 distinct');
    is($many->{distinct}, 1000, '1000 traces of 1 span is 1000 distinct');
    cmp_ok($few->{slots}, '<', $many->{slots},
           'the table is sized from the TRACE count, not the span count');
    cmp_ok($few->{slots}, '<=', 64,
           '  so 1000 spans across 10 traces needs only a tiny table');
}

# --- duration search --------------------------------------------------------

# `duration > X` must be a binary search into a sorted ordinal array, giving a
# contiguous range - not a filtered scan.
{
    my @s;
    for my $t (1 .. 100) {
        push @s, { trace_hi => "$t", trace_lo => '1', span_id => "$t",
                   parent => '0', start => '1000',
                   end => "" . (1000 + $t * 10), service => 1 };
    }
    # durations are 10, 20, ... 1000

    my $r = $T->can('slower_than')->(\@s, '500');
    is($r->{total}, 100, '100 traces');
    is($r->{from}, 49, '  the range starts at ordinal 49');
    is(scalar @{ $r->{durations} }, 51, '  and holds 51 traces at or above 500');
    is("$r->{durations}[0]", '500', '  the first is exactly the boundary');
    is("$r->{durations}[-1]", '1000', '  the last is the slowest');

    # The results must be in ascending duration order, which is what makes a
    # top-N a suffix rather than a sort.
    my @d = map { 0 + $_ } @{ $r->{durations} };
    my @sorted = sort { $a <=> $b } @d;
    is_deeply(\@d, \@sorted, '  and the range is already in duration order');
}

{
    my @s = map { { trace_hi => "$_", trace_lo => '1', span_id => "$_",
                    parent => '0', start => '1000', end => "" . (1000 + $_ * 10),
                    service => 1 } } 1 .. 10;
    my $none = $T->can('slower_than')->(\@s, '99999');
    is(scalar @{ $none->{durations} }, 0, 'a threshold above everything returns nothing');
    is($none->{from}, 10, '  with the range starting past the end');

    my $all = $T->can('slower_than')->(\@s, '0');
    is(scalar @{ $all->{durations} }, 10, 'a threshold of zero returns everything');
    is($all->{from}, 0, '  from the start');
}

# --- segment pruning --------------------------------------------------------

# Answered from the footer alone: no index, no mmap of the data.
{
    my $may = $T->can('seg_may_match');

    # t_min t_max dur_max any_error | from to min_dur want_error
    ok( $may->('1000','2000','500', 0, '1500','2500','0', 0),
        'an overlapping range matches');
    ok(!$may->('1000','2000','500', 0, '3000','4000','0', 0),
        'a range after the segment does not');
    ok(!$may->('1000','2000','500', 0, '0','999','0', 0),
        'a range before it does not');

    ok(!$may->('1000','2000','500', 0, '0','9999','1000', 0),
        'a segment whose slowest trace is 500 is skipped for "slower than 1000"');
    ok( $may->('1000','2000','500', 0, '0','9999','400', 0),
        '  but not for "slower than 400"');

    ok(!$may->('1000','2000','500', 0, '0','9999','0', 1),
        'a segment with NO error span is skipped for an error query');
    ok( $may->('1000','2000','500', 1, '0','9999','0', 1),
        '  while one that has errors is opened');
    ok( $may->('1000','2000','500', 0, '0','9999','0', 0),
        '  and a non-error query opens it regardless');
}

done_testing();

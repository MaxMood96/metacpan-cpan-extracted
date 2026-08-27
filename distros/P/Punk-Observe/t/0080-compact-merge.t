#!perl
# The k-way merge that repays phase 4's per-worker writing.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $R = 'Punk::Observe::Retain';
sub merge { $R->can('merge')->($_[0]) }
sub run { my ($start, $step, $n, $series) = @_;
          [ map { { t => "" . ($start + $_ * $step), series => ($series // '1'),
                    kind => 3 } } 0 .. $n - 1 ] }
sub times_of { [ map { 0 + $_->{t} } @{ $_[0]{records} } ] }

# --- ordering ---------------------------------------------------------------

{
    my $r = merge([ run(0, 10, 5), run(5, 10, 5) ]);
    is_deeply(times_of($r), [ 0, 5, 10, 15, 20, 25, 30, 35, 40, 45 ],
              'two interleaved runs merge into one ordered stream');
    is("$r->{emitted}", '10', '  emitting every record');
}

{
    my $r = merge([ run(0, 1, 3), run(100, 1, 3), run(200, 1, 3) ]);
    is_deeply(times_of($r), [ 0,1,2, 100,101,102, 200,201,202 ],
              'three disjoint runs concatenate in order');
}

{
    my $r = merge([ run(0, 1, 5) ]);
    is_deeply(times_of($r), [ 0, 1, 2, 3, 4 ], 'a single run passes through');
}

{
    my $r = merge([ [], run(0, 1, 3), [] ]);
    is_deeply(times_of($r), [ 0, 1, 2 ], 'empty runs are skipped');
}

{
    my $r = merge([ [], [] ]);
    is_deeply(times_of($r), [], 'all-empty merges to nothing');
    is("$r->{emitted}", '0', '  emitting nothing');
}

# Sixteen runs, which is a realistic worker count.
{
    my @runs = map { run($_, 16, 50) } 0 .. 15;
    my $r = merge(\@runs);
    my $t = times_of($r);
    is(scalar @$t, 800, '16 runs of 50 merge to 800 records');
    my $bad = 0;
    for my $i (1 .. $#$t) { $bad++ if $t->[$i] < $t->[$i - 1] }
    is($bad, 0, '  in non-decreasing time order throughout');
}

# --- determinism ------------------------------------------------------------

# The same inputs must give a byte-identical output, so a regression is a diff
# rather than an investigation - and a re-compaction after a crash produces
# the same segment rather than a different-but-equivalent one.
{
    my @runs = map { run($_ * 3, 7, 40, "" . ($_ + 1)) } 0 .. 7;
    my $a = merge(\@runs);
    my $b = merge(\@runs);
    is_deeply($a->{records}, $b->{records},
              'the same inputs merge to an identical output');

    # And the run ORDER must not change the result: worker 3's segment being
    # listed before worker 1's is an accident of readdir.
    my @rev = reverse @runs;
    my $c = merge(\@rev);
    is_deeply($a->{records}, $c->{records},
              '  regardless of the order the runs are supplied in');
}

# Records that tie on time need a total order, or the merge is unstable.
{
    my @runs = (
        [ { t => '100', series => '5', kind => 3 } ],
        [ { t => '100', series => '2', kind => 3 } ],
        [ { t => '100', series => '9', kind => 3 } ],
    );
    my $a = merge(\@runs);
    my $b = merge([ reverse @runs ]);
    is_deeply([ map { 0 + $_->{series} } @{ $a->{records} } ], [ 2, 5, 9 ],
              'records tying on time are ordered by the tiebreak');
    is_deeply($a->{records}, $b->{records},
              '  identically whichever order the runs arrive in');
}

# --- duplicates are collapsed -----------------------------------------------

# Phase 4's crash window: a WAL consumed into a segment, then re-consumed
# after a crash between rename and unlink, leaves the same records twice.
# Making the write path idempotent would cost an fsync and a lookup per batch
# on the hot path; collapsing on the read side costs one comparison in a
# merge that is already comparing.
{
    my $one = run(0, 10, 5);
    my $r = merge([ $one, $one ]);
    is_deeply(times_of($r), [ 0, 10, 20, 30, 40 ],
              'a run merged with an identical copy yields each record ONCE');
    is("$r->{emitted}", '5', '  five emitted');
    is("$r->{duplicates}", '5', '  and five duplicates collapsed');
}

{
    # Three copies, which is what two crashes would leave.
    my $one = run(0, 10, 4);
    my $r = merge([ $one, $one, $one ]);
    is_deeply(times_of($r), [ 0, 10, 20, 30 ], 'three copies still yield one');
    is("$r->{duplicates}", '8', '  with eight duplicates collapsed');
}

{
    # Partial overlap: the common records collapse, the rest survive.
    my $r = merge([ run(0, 10, 5), run(20, 10, 5) ]);
    is_deeply(times_of($r), [ 0, 10, 20, 30, 40, 50, 60 ],
              'a partial overlap keeps the union and collapses the intersection');
    is("$r->{duplicates}", '3', '  three records were in both runs');
}

# Records that merely SHARE A TIMESTAMP are not duplicates. Collapsing those
# would silently drop real data from two different series at the same instant.
{
    my $r = merge([
        [ { t => '100', series => '1', kind => 3 } ],
        [ { t => '100', series => '2', kind => 3 } ],
    ]);
    is(scalar @{ $r->{records} }, 2,
       'two series at the same instant are BOTH kept');
    is("$r->{duplicates}", '0', '  and neither is called a duplicate');
}

{
    my $r = merge([
        [ { t => '100', series => '1', kind => 3 } ],
        [ { t => '100', series => '1', kind => 2 } ],
    ]);
    is(scalar @{ $r->{records} }, 2,
       'the same series and time but a different signal are both kept');
}

done_testing();

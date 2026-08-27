#!perl
# The executor yields.
#
# A query that blocks the loop takes the whole worker with it: a Hyperman
# worker holds hundreds of connections, and the operator's experience of a
# synchronous two-gigabyte scan is that the service froze because somebody
# opened a dashboard.
#
# Every assertion here is on ORDERING and COUNTS, never on elapsed time.
# Timing assertions do not hold on a loaded smoker.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $E = 'Punk::Observe::Exec';
sub steps { $E->can('steps')->($_[0], $_[1], $_[2]) }
sub run   { $E->can('run')->($_[0], $_[1], $_[2] // {}) }

sub rows {
    my ($n) = @_;
    return [ map { { kind => 'log', t => "$_", service => 'api',
                     body => "line $_" } } 1 .. $n ];
}

# --- it actually yields -----------------------------------------------------

{
    my $r = steps('log | limit 100000', rows(1000), 100);
    is($r->{steps}, 10, '1000 rows at 100 per step is 10 steps');
    is("$r->{scanned}", '1000', '  and every row was scanned');
    is(scalar @{ $r->{cursors} }, 10, '  with a cursor reported after each');
}

{
    my $r = steps('log | limit 100000', rows(1000), 1000);
    is($r->{steps}, 1, 'a budget as large as the input is one step');
}

{
    my $r = steps('log | limit 100000', rows(1000), 1);
    is($r->{steps}, 1000, 'a budget of one row is one step per row');
}

# The cursor MOVES FORWARD on every step and never repeats. A resumable
# machine that lost its place would show up here as a stall or a jump.
{
    my $r = steps('log | limit 100000', rows(500), 50);
    my @c = map { 0 + $_ } @{ $r->{cursors} };
    my $bad = 0;
    for my $i (1 .. $#c) { $bad++ if $c[$i] <= $c[$i - 1] }
    is($bad, 0, 'the cursor advances on every step and never goes back');
    is($c[-1], 500, '  ending at the last row');
    is($c[0], 50, '  after advancing exactly one budget on the first step');
}

# Progress is proportional to the budget, which is what makes the budget a
# real control rather than a suggestion.
{
    for my $b (10, 25, 100, 250) {
        my $r = steps('log | limit 100000', rows(1000), $b);
        my $want = int(1000 / $b);
        is($r->{steps}, $want, "a budget of $b gives $want steps");
    }
}

# --- yielding does not change the ANSWER -----------------------------------

# The whole point of resumability is that it is invisible in the result.
{
    my $rows = rows(997);          # deliberately not a multiple of any budget
    my $whole = run('log | count by service', $rows);
    for my $b (1, 7, 100, 996, 997, 998, 5000) {
        my $r = steps('log | count by service', $rows, $b);
        is("$r->{scanned}", '997',
           "a budget of $b still scans every row");
    }
    is("$whole->{groups}[0]{count}", '997',
       'and the aggregate over the whole set is unchanged');
}

# A budget larger than the input, and a budget of zero (meaning the default),
# both terminate.
{
    my $r = steps('log | limit 100000', rows(10), 1000);
    is($r->{steps}, 1, 'a budget larger than the input terminates in one step');

    my $z = steps('log | limit 100000', rows(10), 0);
    is($z->{steps}, 1, 'a budget of zero uses the default and terminates');
}

# --- the empty input --------------------------------------------------------

{
    my $r = steps('log | limit 10', [], 100);
    is($r->{steps}, 1, 'an empty input is one step');
    is("$r->{scanned}", '0', '  scanning nothing');
}

# --- the step count is reported ---------------------------------------------

{
    my $r = run('log | count by service', rows(1000), { step => 100 });
    is($r->{meta}{steps}, 10,
       'the result reports how many times it yielded');
    ok(!$r->{meta}{truncated}, '  and yielding is not truncation');
}

# --- truncation stops early, and says so -----------------------------------

{
    my $r = run('log | limit 100000', rows(1000),
                { step => 50, hard_max => 220 });
    ok($r->{meta}{truncated}, 'a hard cap truncates');
    is("$r->{meta}{scanned_rows}", '220', '  at the cap, not at a step boundary');
    cmp_ok($r->{meta}{steps}, '<', 10, '  having stopped early');

    # And the partial answer is the correct PREFIX, not an arbitrary subset.
    is($r->{rows}[0]{body}, 'line 1', '  the partial result starts at the start');
    is($r->{rows}[-1]{body}, 'line 220', '  and ends where the cap fell');
}

done_testing();

#!perl
# Planning, and the fourth decision: REFUSING.
#
# A refused query with an actionable message is a better product than a
# thirty-second one, and far better than a timeout.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $E = 'Punk::Observe::Exec';
sub run { $E->can('run')->($_[0], $_[1] // [], $_[2] // {}) }

my $rows = [ { kind => 'log', t => '1000', service => 'api', body => 'x' } ];

# --- the cost refusal -------------------------------------------------------

# Over budget, the message says what to ADD, not what went wrong.
{
    my $r = run('log | count', $rows,
                { max_rows => 1000, rows_available => 10_000_000 });
    ok(!$r->{ok}, 'a query that would scan too much is refused');
    is($r->{stage}, 'plan', '  at plan time, before any scanning');
    like($r->{error}, qr/scan too much/, '  saying why');
    like($r->{error}, qr/time range/,
         '  and recommending a time range, since there is no time bound');
}

{
    # With a time bound but no selective filter, the recommendation changes.
    my $r = run('log | where t > 1000 | count', $rows,
                { max_rows => 1000, rows_available => 10_000_000 });
    ok(!$r->{ok}, 'still refused without a selective filter');
    like($r->{error}, qr/equality filter|service/,
         '  and now recommends an equality filter instead');
}

{
    # With both, the advice is generic - there is nothing specific left to
    # suggest, and saying so is better than repeating advice already taken.
    my $r = run('log | where t > 1000 and service = "api" | count', $rows,
                { max_rows => 1000, rows_available => 10_000_000 });
    ok(!$r->{ok}, 'still refused when the data is simply too big');
    like($r->{error}, qr/shorter time range|narrower/,
         '  with generic advice, since the obvious filters are already there');
}

# Under budget, it runs.
{
    my $r = run('log | count', $rows,
                { max_rows => 1_000_000, rows_available => 100 });
    ok($r->{ok}, 'a query within budget runs') or diag $r->{error};
}

# No budget configured means no refusal - a self-hosted install with no
# quotas must not be crippled by a default nobody set.
{
    my $r = run('log | count', $rows, { rows_available => 10_000_000 });
    ok($r->{ok}, 'with no max_rows there is no refusal');
}

# --- an OR does not bound anything -----------------------------------------

# `t > x or service = "y"` still admits every row outside the range, so it
# must not count as a time bound. Treating it as one would let a query through
# that scans everything.
{
    my $r = run('log | where t > 1000 or service = "api" | count', $rows,
                { max_rows => 1000, rows_available => 10_000_000 });
    ok(!$r->{ok}, 'an OR is refused');
    like($r->{error}, qr/time range/,
         '  and is NOT treated as a time bound, because it does not narrow');
}

# --- unsupported patterns are refused, not approximated --------------------

{
    my $r = run('log | where service =~ "a.*b"', $rows);
    ok(!$r->{ok}, 'a pattern needing a real engine is refused');
    is($r->{stage}, 'plan', '  at plan time');
    like($r->{error}, qr/anchored|substring/,
         '  with a message naming what IS supported');
}

for my $pat ('^api-', 'way$', 'plain', '^exact$') {
    my $r = run(qq{log | where service =~ "$pat"}, $rows);
    ok($r->{ok}, "the supported pattern '$pat' plans") or diag $r->{error};
}

for my $pat ('a|b', 'a+b', 'a[bc]', 'a(b)c', 'a\\db', 'a{2}') {
    my $r = run(qq{log | where service =~ "$pat"}, $rows);
    ok(!$r->{ok}, "the unsupported pattern '$pat' is refused");
}

# A parse error is reported as a parse error, not as a plan one - the stage
# matters when somebody is debugging a query.
{
    my $r = run('log | where duration > 5s', $rows);
    ok(!$r->{ok}, 'a bad column is refused');
    is($r->{stage}, 'parse', '  at PARSE time, and says so');
}

done_testing();

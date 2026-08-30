#!perl
# The query language's uncovered corners.
#
# Every case here was found by running the engine, not by reading it: the
# grammar's own surface (null, ==, time, the selector) held constructs no
# test had ever executed - and one of them was WRONG. `log {service="api"}
# | where severity >= error` parsed both filters and ran only the first: a
# dropped filter, answering with the right shape and the wrong rows. The
# first block pins the fix; the rest pin what running each corner taught.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $E = 'Punk::Observe::Exec';
my $Q = 'Punk::Observe::Query';
sub run   { $E->can('run')->($_[0], $_[1], $_[2] // {}) }
sub parse { $Q->can('parse')->($_[0]) }

# Scripted rows: every branch below picks specific rows by construction.
my @logs = (
    { kind => 'log', t => '1000', severity => 9,  service => 'api',
      body => 'hello world', attrs => { tag => 'x', 'http.route' => '/a' } },
    { kind => 'log', t => '2000', severity => 17, service => 'api',
      body => 'he said "hi"', attrs => { 'http.route' => '/b' } },
    { kind => 'log', t => '3000', severity => 13, service => 'db',
      body => 'warn thing', attrs => { tag => 'x', empty => '' } },
);
my @spans = map {
    { kind => 'span', t => (1000 + $_ * 100) . '',
      duration => (($_ % 4 + 1) * 1_000_000) . '',
      service => ($_ % 2 ? 'api' : 'db'), body => 'GET /' . ($_ % 3),
      trace_hi => "$_", trace_lo => '1',
      attrs => { 'http.route' => '/r' . ($_ % 2) } }
} 1 .. 8;

sub bodies { return [ map { $_->{body} } @{ $_[0]{rows} || [] } ] }

# --- every where runs: they are a conjunction --------------------------------
{
    my $r = run('log | where tag = "x" | where severity = 13', \@logs);
    is_deeply(bodies($r), ['warn thing'],
              'two where stages both filter - the second was silently '
            . 'dropped once');

    # The where alone keeps TWO rows (severities 17 and 13); only the
    # selector drops the db one - so this fails if either half is dropped,
    # not just the where.
    $r = run('log {service="api"} | where severity >= warn', \@logs);
    is_deeply(bodies($r), ['he said "hi"'],
              'the selector and a where stage both filter');

    $r = run('log | where tag = "x" | where severity = 13 | where t = 3000',
             \@logs);
    is_deeply(bodies($r), ['warn thing'], 'three, likewise');

    $r = run('log | where t = 3000 | where severity = 9', \@logs);
    is_deeply(bodies($r), [], 'an unsatisfiable conjunction answers nothing');

    # The cap refuses BY NAME rather than dropping the ninth.
    my $many = 'log' . (' | where t > 0' x 9);
    $r = run($many, \@logs);
    is($r->{ok}, 0, 'nine where stages are refused');
    like($r->{error}, qr/too many where stages/, '  by name');
    like($r->{error}, qr/combine them with `and`/, '  with the fix');

    # And eight still run - the cap is the array, not one less.
    $r = run('log' . (' | where t > 0' x 8), \@logs);
    is($r->{ok}, 1, 'eight where stages run');
    is(scalar @{ $r->{rows} }, 3, '  and filter correctly');
}

# --- null: the existence test ------------------------------------------------
{
    my $r = run('log | where tag = null', \@logs);
    is_deeply(bodies($r), ['he said "hi"'],
              '= null keeps the rows WITHOUT the attribute');

    $r = run('log | where tag != null', \@logs);
    is_deeply([ sort @{ bodies($r) } ], [ 'hello world', 'warn thing' ],
              '!= null keeps the rows with it');

    # An attribute that exists holding "" is PRESENT: existence is about the
    # key, and an empty value is a value.
    $r = run('log | where empty != null', \@logs);
    is_deeply(bodies($r), ['warn thing'],
              'an empty-string attribute exists');

    # null composes like any predicate.
    $r = run('log | where tag != null and severity >= error', \@logs);
    is_deeply(bodies($r), [], 'null in a conjunction');
    $r = run('log | where tag = null or service = "db"', \@logs);
    is(scalar @{ $r->{rows} }, 2, 'null in a disjunction');

    # A reserved column is always present, so = null selects nothing - the
    # answer is empty, never an error.
    $r = run('log | where severity = null', \@logs);
    is_deeply(bodies($r), [], 'a column the row always has is never null');

    # The refusals name what null is for.
    my $p = parse('log | where a > null');
    is($p->{ok}, 0, 'null does not order');
    like($p->{error}, qr/null only compares with = and !=/,
         '  and the message says what it does instead');
    $p = parse('log | where null = a');
    is($p->{ok}, 0, 'null is a value, not a field');
}

# --- == is =, time is t ------------------------------------------------------
{
    my $eq  = run('log | where service = "api"',  \@logs);
    my $eq2 = run('log | where service == "api"', \@logs);
    is_deeply(bodies($eq2), bodies($eq), '== filters exactly as =');
    is(scalar @{ $eq->{rows} }, 2, '  and both actually selected');

    my $t    = run('log | where t > 1500',    \@logs);
    my $time = run('log | where time > 1500', \@logs);
    is_deeply(bodies($time), bodies($t), 'time filters exactly as t');
    is(scalar @{ $t->{rows} }, 2, '  and both actually selected');
}

# --- strings: escapes, emptiness ---------------------------------------------
#
# The lexer always skipped `\"` when finding a string's end, but the value
# was copied raw - so `where body = "he said \"hi\""` parsed cleanly and
# could never match the body it plainly named. The two halves agree now.
{
    my $r = run('log | where body = "he said \"hi\""', \@logs);
    is_deeply(bodies($r), ['he said "hi"'],
              'an escaped quote reaches the comparison as a quote');

    $r = run('log | where body = "back\\\\slash"',
             [ { kind => 'log', t => '1', severity => 9, service => 'a',
                 body => 'back\\slash', attrs => {} } ]);
    is(scalar @{ $r->{rows} }, 1,
       'an escaped backslash reaches it as one backslash');

    $r = run('log | search "said \"hi"', \@logs);
    is_deeply(bodies($r), ['he said "hi"'],
              'search resolves the same escapes as where');

    $r = run('log | where empty = ""', \@logs);
    is_deeply(bodies($r), ['warn thing'], 'the empty string is comparable');

    # Only the QUOTING escapes resolve. `\d` in a pattern is somebody
    # reaching for a regex class, and the greedy rule that resolved it to
    # `d` turned the plan's honest refusal into a silent substring match
    # for a string they never wrote.
    $r = run('log | where service =~ "a\db"', \@logs);
    is($r->{ok}, 0, 'a regex-class escape still reaches the refusal');
    like($r->{error}, qr/full regular expression engine/, '  by name');
}

# --- numbers at the edge never wrap ------------------------------------------
{
    # Past u64: if the literal wrapped, t > (small number) would match
    # everything - the exact failure mode that matters.
    my $r = run('log | where t > 99999999999999999999', \@logs);
    is_deeply(bodies($r), [], 'a literal past u64 matches nothing, not everything');

    $r = run('log | where t <= 18446744073709551615', \@logs);
    is(scalar @{ $r->{rows} }, 3, 'u64 max itself is a working bound');
}

# --- a pattern the matcher cannot honour refuses at plan ---------------------
{
    my $r = run('log | where service =~ "("', \@logs);
    is($r->{ok}, 0, 'an unanchorable pattern is refused, not approximated');
    like($r->{error}, qr/full regular expression engine/, '  saying why');
    like($r->{error}, qr/anchored prefix/, '  and what to try');

    # In the SECOND where too: a refusal that only read the first slot
    # would run the bad pattern - or worse, drop it.
    $r = run('log | where t > 0 | where service =~ "("', \@logs);
    is($r->{ok}, 0, 'a bad pattern in a later where is still refused');
}

# --- limit 0 means the default cap, not zero rows ----------------------------
{
    my $r = run('log | limit 0', \@logs);
    is(scalar @{ $r->{rows} }, 3,
       'limit 0 falls back to the default cap - nobody asks for zero rows');
}

# --- sort orders, both ways, on both kinds of field --------------------------
{
    my $r = run('log | sort t asc', \@logs);
    is_deeply([ map { $_->{t} } @{ $r->{rows} } ], [ 1000, 2000, 3000 ],
              'sort t asc is oldest first');
    $r = run('log | sort severity desc', \@logs);
    is($r->{rows}[0]{severity}, 17, 'sort severity desc leads with the worst');

    # Sorting on an attribute reads the attribute; a row without it sorts
    # as GREATEST, whichever direction is asked - so it is last ascending
    # and first descending, consistently, rather than shuffling.
    $r = run('log | sort http.route asc', \@logs);
    is_deeply(bodies($r), [ 'hello world', 'he said "hi"', 'warn thing' ],
              'attribute sort asc: /a, /b, then the row without the key');
    $r = run('log | sort http.route desc', \@logs);
    is_deeply(bodies($r), [ 'warn thing', 'he said "hi"', 'hello world' ],
              '  and desc is exactly the reverse');
}

# --- slowest, distinct, top, and compound keys -------------------------------
{
    my $r = run('spans | slowest 3', \@spans);
    is(scalar @{ $r->{rows} }, 3, 'slowest N returns N rows');
    my @d = map { $_->{duration} } @{ $r->{rows} };
    is_deeply([ @d ], [ sort { $b <=> $a } @d ], '  longest first');
    cmp_ok($d[0], '==', 4_000_000, '  and it really is the longest');

    $r = run('log | distinct by service', \@logs);
    my %per = map { $_->{key} => $_->{count} } @{ $r->{groups} };
    is_deeply(\%per, { api => 2, db => 1 },
              'distinct by service: one group per value, with its row count');

    # top N with a tie is DETERMINISTIC: whatever wins, the same query over
    # the same rows names the same winner every time.
    my $t1 = run('spans | count by service | top 1 by count', \@spans);
    my $t2 = run('spans | count by service | top 1 by count', \@spans);
    is(scalar @{ $t1->{groups} }, 1, 'top 1 returns one group');
    is($t1->{groups}[0]{count}, 4, '  with the winning count');
    is($t1->{groups}[0]{key}, $t2->{groups}[0]{key},
       '  and a tie breaks the same way twice');

    # The compound key joins on \x1f - the unit separator - so a value that
    # itself contains "/" or a comma cannot fake a boundary.
    $r = run('spans | p95 by service, http.route', \@spans);
    my @keys = sort map { $_->{key} } @{ $r->{groups} };
    is_deeply(\@keys, [ "api\x1f/r1", "db\x1f/r0" ],
              'two by keys make one compound group key');
}

# --- the selector shorthand carries a metric name ----------------------------
{
    my @points = map {
        { kind => 'metric', t => (1000 + $_) . '', value => "$_",
          service => ($_ % 2 ? 'api' : 'db'), body => 'reqs',
          attrs => { az => ($_ % 2 ? 'a' : 'b') } }
    } 1 .. 4;
    my $r = run('metric reqs{az="a"} | sum', \@points);
    is($r->{groups}[0]{value}, 4, 'metric name + selector + aggregate: 1+3');

    # The name is exact: `req` is not `reqs`.
    $r = run('metric req | sum', \@points);
    ok(!$r->{groups} || !@{ $r->{groups} } || !$r->{groups}[0]{count},
       'a prefix of the name matches nothing');
}

# --- the pushdown reads every where too --------------------------------------
#
# Each where is a conjunct, so a time bound proven by ANY of them narrows
# the read for all of them. The mutant that walks only the first where
# still answers correctly - the executor filters - but reads the segment
# the second where excluded, and `skipped` is how that shows.
{
    require File::Temp;
    require File::Spec;
    require Punk::Observe::Store;
    require Punk::Observe::WAL;

    my $dir   = File::Temp::tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir, tenant => 'acme');
    my $T0    = '1774224000000000000';
    my $LATER = '1774224600000000000';    # ten minutes on

    for my $t ($T0, $LATER) {
        Punk::Observe::WAL::append($store->wal_path, [ {
            kind => 2, t => $t, body => "at $t", severity => 9,
            duration => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
            parent_id => 0, attrs => { 'service.name' => 'svc', tag => 'x' },
        } ], 0, 0);
        $store->seal;
    }
    my $wdir = File::Spec->catdir($dir, 'acme', 'wal');
    utime(time - 60, time - 60, $wdir) or die "utime: $!";

    my $r = $store->query(
        qq{log | where tag = "x" | where t >= $LATER});
    is($r->{ok}, 1, 'the store runs a two-where query');
    is(scalar @{ $r->{rows} }, 1, '  and both filters applied');
    is($r->{rows}[0]{body}, "at $LATER", '  keeping the later record');
    is($r->{store}{skipped}, 1,
       '  and the SECOND where\'s time bound pruned the older segment');
}

# --- a margin note is not a stage --------------------------------------------
{
    my $with    = run("log | where severity >= error # only the bad ones",
                      \@logs);
    my $without = run('log | where severity >= error', \@logs);
    is_deeply(bodies($with), bodies($without),
              'a trailing comment changes nothing');
}

done_testing();

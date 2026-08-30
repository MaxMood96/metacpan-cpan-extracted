#!perl
# Every column the parser admits, filtered on a value that exists.
#
# THIS IS THE TEST THAT WOULD HAVE CAUGHT ALL OF THEM.
#
# A comparison against a field the row cannot answer is false in both
# directions - deliberately, so that a wrong column cannot accidentally match.
# The consequence is that the filter matches nothing, and "no rows matched" is
# exactly what the page says when the filter was right and the data was
# absent. The two are indistinguishable on the screen.
#
# po_row.h already carries a comment about this, written when `status` and
# `kind` were found to be in exactly this state:
#
#   A column the language admits and the row cannot answer is worse than one
#   it rejects: a rejected column is a message, an unanswerable one is an
#   empty result that looks like an answer.
#
# Those two were fixed. `trace_id` and `span_id` were missed in the same
# sweep, and survived a release, because every test on them was a PARSE test -
# and parsing is all they did.
#
# So this file asserts the property directly, for every entry in PO_COLUMNS:
# filter on a value that is genuinely present, and get rows back. It is a
# grid, not a list of cases, precisely so the next column added cannot be
# forgotten.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;

my $T0 = '1774224000000000000';
sub at { Punk::Observe::Store::nadd($T0, $_[0]) }

my $dir = tempdir(CLEANUP => 1);
my $store = Punk::Observe::Store->new(dir => $dir);

# One trace, known ids, spelled out so the test can filter on them by hand.
my ($TR_HI, $TR_LO, $SPAN) = ('100', '200', '4242');

{
    my @recs;
    for my $i (0 .. 4) {
        push @recs,
            # a span: duration, name, status, kind, trace and span ids
            { kind => 3, t => at($i * 1_000_000_000), duration => '5000000',
              body => 'POST /checkout', span_kind => 2,
              status => ($i == 1 ? 2 : 0), severity => 0,
              trace_hi => $TR_HI, trace_lo => $TR_LO, span_id => $SPAN,
              parent_id => 0,
              attrs => { 'service.name' => 'shop', 'http.route' => '/checkout' } },
            # a log line on the same trace: body, severity, trace and span ids
            { kind => 2, t => at($i * 1_000_000_000 + 500_000),
              body => 'card refused', severity => 17,
              trace_hi => $TR_HI, trace_lo => $TR_LO, span_id => $SPAN,
              parent_id => 0,
              attrs => { 'service.name' => 'cards' } },
            # a metric point: value
            { kind => 1, t => at($i * 1_000_000_000 + 900_000),
              body => 'http.server.duration', value => 5.0 + $i,
              severity => 0, span_kind => 0, status => 0,
              trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
              attrs => { 'service.name' => 'shop' } };
    }
    my $r = Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0);
    ok($r->{ok}, 'the fixture reaches the log');
    ok($store->seal, '  and seals');
}

my %W = (from => $T0, to => at(60_000_000_000));

sub rows_for {
    my ($q) = @_;
    my $r = eval { $store->query($q, %W) };
    return (undef, $@ || 'query died') unless $r;
    return (undef, $r->{error} || 'not ok') unless $r->{ok};
    return ($r->{rows} || [], undef);
}

# The grid. Each entry is a column from PO_COLUMNS, a source that admits it,
# and a filter on a value the fixture genuinely contains.
#
# `t` and `time` are the window itself and are covered by every other row
# here, but they are listed because PO_COLUMNS lists them: a column with no
# line in this table is the thing this file exists to prevent.
my @GRID = (
    # UNQUOTED. These are numeric columns, and a numeric column compared
    # against a quoted literal takes the string path, which does not resolve
    # it - so it matches nothing, silently. That is the same defect this file
    # exists for, one level down, and it is not specific to `status`: it is
    # true of t, time, value, duration, severity, status and kind alike.
    [ 't',        'log',   qq{log | where t > $T0} ],
    [ 'time',     'log',   qq{log | where time > $T0} ],
    [ 'service',  'log',   q{log | where service = "cards"} ],
    [ 'service',  'spans', q{spans | where service = "shop"} ],
    [ 'value',    'metric',
                  q{metric http.server.duration | where value >= 5} ],
    [ 'body',     'log',   q{log | where body = "card refused"} ],
    [ 'severity', 'log',   q{log | where severity >= error} ],
    [ 'duration', 'spans', q{spans | where duration >= 1ms} ],
    [ 'name',     'spans', q{spans | where name = "POST /checkout"} ],
    [ 'status',   'spans', q{spans | where status == 2} ],
    [ 'kind',     'spans', q{spans | where kind == 2} ],

    # THE TWO THAT WERE MISSED. Both spellings, because povw_trace_id accepts
    # both and a link pasted out of another tool carries the hex one.
    [ 'trace_id', 'log',   qq{log | where trace_id = "$TR_HI-$TR_LO"} ],
    [ 'trace_id', 'spans', qq{spans | where trace_id = "$TR_HI-$TR_LO"} ],
    [ 'trace_id', 'log',   sprintf('log | where trace_id = "%016x%016x"',
                                   $TR_HI, $TR_LO) ],
    [ 'span_id',  'log',   qq{log | where span_id = "$SPAN"} ],
    [ 'span_id',  'spans', qq{spans | where span_id = "$SPAN"} ],
);

for my $case (@GRID) {
    my ($col, $src, $q) = @$case;
    my ($rows, $err) = rows_for($q);
    if (!$rows) {
        fail("$col on $src: $q");
        diag("  the query did not run: $err");
        next;
    }
    cmp_ok(scalar @$rows, '>', 0, "$col on $src returns rows")
        or diag("  $q\n  matched nothing, on data that contains it - which is "
              . "the same thing the page shows when the filter was right");
}

# ...AND THE NEGATIVE, or the assertions above would pass on a filter that
# matched everything. A column that answers has to answer WRONG for a value
# that is not there.
{
    my @neg = (
        [ 'service',  q{log | where service = "nosuch"} ],
        [ 'body',     q{log | where body = "nosuch"} ],
        [ 'status',   q{spans | where status == 9} ],
        [ 'trace_id', q{log | where trace_id = "1-2"} ],
        [ 'span_id',  q{log | where span_id = "9999"} ],
    );
    for my $case (@neg) {
        my ($col, $q) = @$case;
        my ($rows, $err) = rows_for($q);
        if (!$rows) { fail("$col negative: $q"); diag("  $err"); next }
        is(scalar @$rows, 0, "$col excludes what it should")
            or diag("  $q matched $rows->[0]{body} - the filter is not being "
                  . "applied at all");
    }
}

# A NUMERIC COLUMN COMPARED AGAINST A QUOTED LITERAL MATCHES NOTHING.
#
# Recorded rather than fixed here: it is the general form of the `status =
# "error"` defect, and whether the answer is to refuse the comparison or to
# coerce it is a language decision. What must not happen is it staying
# invisible - so if any of these starts returning rows, this test says so and
# the decision gets made deliberately.
{
    for my $q (qq{log | where t > "$T0"},
               q{spans | where duration >= "1000000"},
               q{log | where severity >= "17"},
               q{spans | where status = "error"}) {
        my ($rows, $err) = rows_for($q);
        next unless $rows;
        is(scalar @$rows, 0, "numeric-vs-string still matches nothing: $q")
            or diag('this now returns rows - the language changed, and the '
                  . 'behaviour above needs a deliberate decision recorded');
    }
}

# EVERY COLUMN IN THE HEADER HAS A LINE ABOVE. The grid is only a guarantee
# while it is complete, and the way it stops being complete is somebody adding
# a column and not a case.
{
    my $h = 'include/punk_observe/po_query.h';
  SKIP: {
        open my $fh, '<', $h or skip "no $h in this tree", 1;
        my $src = do { local $/; <$fh> };
        my ($block) = $src =~ /PO_COLUMNS\[\]\s*=\s*\{(.*?)\n\};/s;
        skip 'PO_COLUMNS not found', 1 unless $block;
        my @declared = $block =~ /\{\s*"([a-z_]+)"/g;
        my %covered = map { $_->[0] => 1 } @GRID;
        my @missing = grep { !$covered{$_} } @declared;
        is_deeply(\@missing, [],
                  'every column in PO_COLUMNS has a case in this file')
            or diag('no case for: ' . join(', ', @missing)
                  . "\na column with no case here is one that can stop "
                  . "answering without anything failing");
    }
}

# `top N by <agg>` RANKS AND LIMITS.
#
# It parsed, validated, was named in three files, and had no case in
# po_plan_build - so the query was accepted and the answer came back neither
# ranked nor limited. The right shape and the wrong contents, with nothing
# saying so. Implemented rather than refused, because `top N by count` is the
# question people actually have.
{
    my $d2 = tempdir(CLEANUP => 1);
    my $s2 = Punk::Observe::Store->new(dir => $d2);
    my %n = (alpha => 9, bravo => 3, charlie => 7, delta => 1, echo => 5);
    my @recs;
    for my $svc (sort keys %n) {
        push @recs, { kind => 3, t => at($_ * 1_000_000), body => 'op',
                      duration => $_ * 1_000_000, span_kind => 2, status => 0,
                      trace_hi => 1, trace_lo => $_, span_id => $_,
                      parent_id => 0, attrs => { 'service.name' => $svc } }
            for 1 .. $n{$svc};
    }
    Punk::Observe::WAL::append($s2->wal_path, \@recs, 0, 0);
    $s2->seal;

    my $groups = sub {
        my $r = $s2->query($_[0], %W);
        return [] unless $r && $r->{ok};
        return $r->{groups} || [];
    };

    my $all = $groups->('spans | by service | count');
    is(scalar @$all, 5, 'five services to rank');

    my $top = $groups->('spans | by service | top 3 by count');
    is(scalar @$top, 3, 'top 3 keeps three')
        or diag('the stage planned to nothing and returned everything');
    is_deeply([ map { $_->{key} } @$top ], [qw(alpha charlie echo)],
              '  the three largest, in descending order');

    # The aggregate it ranks on is the one the stage names.
    my $bymax = $groups->('spans | by service | top 2 by max');
    is_deeply([ map { $_->{key} } @$bymax ], [qw(alpha charlie)],
              'top N ranks on the aggregate it was given');

    # N above the group count is not an error and not a truncation.
    is(scalar @{ $groups->('spans | by service | top 99 by count') }, 5,
       'an N larger than the answer keeps all of it');
}

# STATUS NAMES ARE VALUE LITERALS, resolved at parse time.
#
# The documented SYNOPSIS example was `status = "error"`, which compares a
# numeric column against a string: no row answers it, so the first example a
# person reads returned nothing. Fixed by making the names numbers rather than
# by making the documentation match a worse language.
{
    my $d3 = tempdir(CLEANUP => 1);
    my $s3 = Punk::Observe::Store->new(dir => $d3);
    my @recs;
    for my $i (0 .. 5) {
        push @recs,
            { kind => 3, t => at($i * 1_000_000_000), body => 'POST /checkout',
              duration => 100_000_000, span_kind => 2,
              status => ($i % 3 == 0 ? 2 : 0),
              trace_hi => 1, trace_lo => $i, span_id => $i, parent_id => 0,
              attrs => { 'service.name' => 'shop' } },
            { kind => 2, t => at($i * 1_000_000_000), body => "l$i",
              severity => ($i % 2 ? 17 : 9),
              attrs => { 'service.name' => 'shop' } };
    }
    Punk::Observe::WAL::append($s3->wal_path, \@recs, 0, 0);
    $s3->seal;
    my $n = sub {
        my $r = $s3->query($_[0], %W);
        return -1 unless $r && $r->{ok};
        return scalar @{ $r->{rows} || [] };
    };

    is($n->('spans | where status = error'), 2, 'status = error is the number 2');
    is($n->('spans | where status == 2'), 2, '  the same as the number');
    is($n->('spans | where status = unset'), 4, 'status = unset is 0');
    is($n->('spans | where status = ok'), 0, 'status = ok is 1, and none are');

    # AND `error` STILL MEANS 17 ON SEVERITY. The word is in both
    # vocabularies and is a different number in each; the column decides.
    is($n->('log | where severity >= error'), 3, 'error on severity is still 17');

    # An ordering on a status name is a numeric ordering, which is the whole
    # reason the names resolve at parse time rather than being matched as
    # strings.
    is($n->('spans | where status > unset'), 2, 'orderings on status names work');
}

# `metric <name>` SELECTS THE SERIES.
#
# The name parsed, was stored in the AST, and no planner or executor code ever
# read it - so the source verb chose the signal and nothing chose the metric.
# Every metric query returned every metric point in the store, and `metric
# nosuch` answered with somebody else's data rather than with nothing.
#
# Invisible on any store with one metric name in it, which is what a demo has
# and a production store never does. This is the same family as the columns
# above: an answer with the right shape and the wrong contents.
{
    my $d4 = tempdir(CLEANUP => 1);
    my $s4 = Punk::Observe::Store->new(dir => $d4);
    my @recs;
    for my $n (qw(a.metric b.metric c.metric)) {
        push @recs, { kind => 1, t => at($_ * 1_000_000), body => $n,
                      value => $_, severity => 0, span_kind => 0, status => 0,
                      trace_hi => 0, trace_lo => 0, span_id => 0,
                      parent_id => 0, attrs => { 'service.name' => 'api' } }
            for 1 .. 3;
    }
    Punk::Observe::WAL::append($s4->wal_path, \@recs, 0, 0);
    $s4->seal;

    my $rows = sub {
        my $r = $s4->query($_[0], %W);
        return -1 unless $r && $r->{ok};
        return scalar @{ $r->{rows} || [] };
    };

    is($rows->('metric a.metric'), 3, 'a metric query returns only that metric')
        or diag('it returned every metric point in the store');
    is($rows->('metric b.metric'), 3, '  and the same for another');
    is($rows->('metric nosuch'), 0,
       'a metric nothing has written returns nothing, not everything');

    # EXACTLY, not by prefix: `a.metric` must not answer for `a.metric_total`.
    my @more = ({ kind => 1, t => at(9_000_000), body => 'a.metric_total',
                  value => 1, severity => 0, span_kind => 0, status => 0,
                  trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
                  attrs => { 'service.name' => 'api' } });
    Punk::Observe::WAL::append($s4->wal_path, \@more, 0, 0);
    $s4->seal;
    is($rows->('metric a.metric'), 3, 'the match is exact, not a prefix');
    is($rows->('metric a.metric_total'), 1, '  and the longer name is its own');
}

done_testing();

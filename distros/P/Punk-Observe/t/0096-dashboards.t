#!perl
# A dashboard panel, which is an OQL string with a title.
#
# THE HEADLINE ASSERTION: A PANEL IS VALIDATED BY THE PARSER THAT WILL RUN IT.
# A panel checked by a different rule than the one that executes it is a panel
# that can be saved and cannot be shown, and the person who finds out is a
# reader at three in the morning rather than the author at the form.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $D = 'Punk::Observe::Dashboard';
sub panel { $D->can('check_panel')->($_[0]) }

# --- a valid panel ----------------------------------------------------------

{
    my $p = panel({ title => 'Checkout latency',
                    query => 'metric http.server.duration | p95 by http.route',
                    viz   => 'line', position => 2, span => 3 });
    ok($p->{ok}, 'a panel with a valid query saves') or diag $p->{error};
    is($p->{viz}, 'line', '  keeping its visualisation');
    is($p->{position}, 2, '  and its position');
    is($p->{span}, 3, '  and how many columns it spans');
}

{
    for my $v (qw(line area bar stat table)) {
        my $p = panel({ title => 't', query => 'log | count', viz => $v });
        is($p->{viz}, $v, "the $v visualisation survives");
    }
    # A hint the renderer does not know falls back to a TABLE, which shows the
    # data. Falling back to nothing would hide it.
    my $p = panel({ title => 't', query => 'log | count', viz => 'heatmap3d' });
    is($p->{viz}, 'table', 'an unknown visualisation falls back to a table');
}

# --- THE QUERY IS PARSED, NOT PATTERN-MATCHED ------------------------------

{
    my $p = panel({ title => 't', query => 'metric x | p95 by |' });
    ok(!$p->{ok}, 'a panel with a broken query is REFUSED at save time');
    ok(length $p->{error}, '  with the parser\'s own message');
}

{
    my $p = panel({ title => 't', query => 'nonsense' });
    ok(!$p->{ok}, 'a query that is not OQL at all is refused');
}

{
    # A cross-signal error is the parser's, and the message it produces is the
    # feature: it names the stage to add.
    my $p = panel({ title => 't', query => 'metric x | traces' });
    ok(!$p->{ok}, 'a query the parser rejects is rejected here too');
    like($p->{error}, qr/exemplars/,
         '  and the panel form shows the parser\'s recommendation');
}

# --- titles are untrusted ---------------------------------------------------

{
    my $p = panel({ title => '', query => 'log | count' });
    ok(!$p->{ok}, 'a panel needs a title');
    like($p->{error}, qr/title/, '  and says so');

    $p = panel({ title => 'x' x 200, query => 'log | count' });
    ok(!$p->{ok}, 'an over-long title is refused');

    # Control characters are refused rather than escaped: a title is displayed
    # in a dozen places of which only some are HTML.
    $p = panel({ title => "ok\x00then", query => 'log | count' });
    ok(!$p->{ok}, 'a NUL in a title is refused');
    $p = panel({ title => "line\nbreak", query => 'log | count' });
    ok(!$p->{ok}, 'a newline in a title is refused');
    like($p->{error}, qr/control/, '  naming the reason');

    # A title with markup in it is NOT refused - the template escapes it, and
    # refusing every angle bracket would make "a < b" unsayable.
    $p = panel({ title => 'p95 < 200ms', query => 'log | count' });
    ok($p->{ok}, 'a title containing an angle bracket is allowed');
}

{
    my $p = panel({ title => 't', query => '' });
    ok(!$p->{ok}, 'a panel needs a query');
    like($p->{error}, qr/query/, '  and says which');
}

# --- layout is a number, and it is clamped ---------------------------------
#
# There is no drag grid, deliberately: several hundred lines of JavaScript, a
# collision algorithm, a mobile story and a persistence format, in exchange
# for an arrangement most people set once.

{
    my $p = panel({ title => 't', query => 'log | count', span => 0 });
    is($p->{span}, 1, 'a span below one is clamped to one');
    $p = panel({ title => 't', query => 'log | count', span => 99 });
    is($p->{span}, 6, '  and an absurd one to the maximum');
    $p = panel({ title => 't', query => 'log | count', position => -5 });
    is($p->{position}, 0, 'a negative position is clamped to the top');
}

# --- A PANEL AND THE EXPLORER CANNOT DISAGREE ------------------------------
#
# The same query string, validated here and parsed by the query module, must
# reach the same verdict. If they could differ, a dashboard would be able to
# hold a query the explorer refuses, or vice versa.

{
    my $Q = 'Punk::Observe::Query';
    my $parse = $Q->can('parse');
    my @queries = (
        'log | count',
        'log | where severity >= error | search "refused" | count by service',
        'metric http.server.duration | rate(5m) by http.response.status_code',
        'metric http.server.duration | p99 by http.route | exemplars | traces',
        'trace | where duration > 500ms | slowest 20',
        'metric x | p95 by |',
        'nonsense',
        'log | where',
        'trace | traces',
        '',
    );
    my $disagreed = 0;
    for my $q (@queries) {
        my $p = panel({ title => 't', query => $q });
        my $r = $parse->($q);
        my $parses = ($r && $r->{ok}) ? 1 : 0;
        # An empty query is refused by the panel for a different reason (it
        # has none), which is not a disagreement about OQL.
        next unless length $q;
        $disagreed++ if $parses != ($p->{ok} ? 1 : 0);
    }
    is($disagreed, 0,
       'every query gets the SAME verdict from the panel and the parser');
}

# --- ONE VOCABULARY, and it is the one with a schema behind it --------------
#
# The renderer read `order` and `span`. check_panel read `position` and
# `cols`. The SQL columns were `position` and `span`. Three names for two
# things, which was inert exactly until something wrote a row - and the
# dashboard editor is the thing that writes rows.
#
# Asserted by name, in all three places, because the failure is silent: a
# renderer looking for a key nobody sets reads undef, clamps it to a default,
# and lays the panel out wrongly with nothing to say so.
{
    my $p = panel({ title => 't', query => 'log | count',
                    position => 4, span => 2 });
    is($p->{position}, 4, 'check_panel speaks `position`');
    is($p->{span},     2, '  and `span`');
    ok(!exists $p->{cols},  '  and not `cols`, which was the panel/grid clash');
    ok(!exists $p->{order}, '  and not `order`');

    # The renderer reads the same two names off the panel hashref.
    my $xs = do {
        open my $fh, '<', 'xs/view.xs' or die $!;
        local $/; <$fh>;
    };
    my ($dash) = $xs =~ /(povw__page_dashboard.*?\n    OUTPUT:)/s;
    ok($dash, 'found the dashboard page builder');
    like($dash, qr/hv_fetchs\(\(HV \*\)SvRV\(\*e\), "position"/,
         '  and it orders panels by `position`');
    unlike($dash, qr/"order"/, '  with no trace of the old name');

    # And the schema agrees, which is where the names came from. The DDL
    # lives in per-dialect sqitch projects and is the only description of the
    # schema there is.
    my $sql = do {
        open my $fh, '<', 'sqitch/pg/deploy/alerts.sql' or die $!;
        local $/; <$fh>;
    };
    my ($tbl) = $sql =~ /CREATE TABLE dashboard_panels \((.*?)\n\);/s;
    ok($tbl, 'found the dashboard_panels table');
    like($tbl, qr/\bposition\b/, '  which has a position column');
    like($tbl, qr/\bspan\b/,     '  and a span column');
}

# --- a rows-shaped panel that is not a metric renders a TABLE ---------------
#
# The rows branch fed _series_paths, which plots each row's `value` - a field
# metric rows have and log rows do not. So `log | where severity >= error` on
# a panel dropped every point and rendered a heading over nothing, on a query
# the explorer answers fine. And `viz table`, the first viz the column
# actually selects, forces the table even where a chart is possible.
{
    require File::Temp; require File::Path;
    require Punk::Observe::Store; require Punk::Observe::WAL;
    require Punk::Observe::View;

    my $d = File::Temp::tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $d);
    my $T = '1774224000000000000';
    my @recs;
    # MORE THAN THE PANEL SHOWS, or the cap is never selected and the "and
    # this many more" note is never rendered.
    for my $i (0 .. 29) {
        push @recs,
            { kind => 2, t => Punk::Observe::Store::nadd($T, $i * 1_000_000_000),
              body => "boom $i", severity => 17,
              attrs => { 'service.name' => 'cards' } },
            { kind => 1, t => Punk::Observe::Store::nadd($T, $i * 1_000_000_000),
              body => 'm', value => $i, attrs => { 'service.name' => 'cards' } };
    }
    Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0);
    $store->seal;

    my $page = sub {
        my (%o) = @_;
        # panels_inline: these tests are OF the body build - the path
        # ?full=1 and the per-panel fragment route share.
        return Punk::Observe::View->page($store, q{dashboard}, {
            panels_inline => 1,
            slug => q{x}, from => $T,
            to => Punk::Observe::Store::nadd($T, 60_000_000_000),
            dashboards => sub { { title => 'x', cols => 1, panels => [
                { title => 'p', position => 0, span => 1, %o } ] } },
        });
    };

    my ($p) = @{ $page->(query => 'log | where severity >= error')->{panels} };
    ok($p->{rows} && @{ $p->{rows} },
       'a log-rows panel renders rows rather than nothing')
        or diag('the chart path plots `value`, which a log row does not have');
    is(scalar @{ $p->{rows} }, 20,
       '  twenty of them - a glance, but one worth the panel\'s space');
    is($p->{rows}[0]{service}, 'cards', '  carrying the service');
    like($p->{rows}[0]{body}, qr/^boom/, '  and the line itself');
    cmp_ok($p->{more}, '>', 20, '  saying how many the range really has');
    # The note spells the count, and it used to spell it in the template -
    # where raising the cap left it claiming eight.
    is($p->{shown}, scalar @{ $p->{rows} },
       '  and the count the note prints is the count that was rendered');

    # viz=table forces the table even for metric rows a chart could plot.
    my ($t) = @{ $page->(query => 'metric m', viz => 'table')->{panels} };
    ok($t->{rows} && @{ $t->{rows} }, 'viz table tables a metric answer too');
    ok(!$t->{series}, '  and draws no line beside it');
    is($t->{has_value}, 1, '  with the value column present');

    # ...and the default still charts metric rows.
    my ($l) = @{ $page->(query => 'metric m')->{panels} };
    ok($l->{series} && @{ $l->{series} }, 'metric rows still chart by default');
    ok(!$l->{rows}, '  with no table crowding the panel');
}

done_testing();
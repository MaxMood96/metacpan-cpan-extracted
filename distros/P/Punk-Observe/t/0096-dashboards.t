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
                    viz   => 'line', position => 2, cols => 3 });
    ok($p->{ok}, 'a panel with a valid query saves') or diag $p->{error};
    is($p->{viz}, 'line', '  keeping its visualisation');
    is($p->{position}, 2, '  and its position');
    is($p->{cols}, 3, '  and its column count');
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
    my $p = panel({ title => 't', query => 'log | count', cols => 0 });
    is($p->{cols}, 1, 'a column count below one is clamped to one');
    $p = panel({ title => 't', query => 'log | count', cols => 99 });
    is($p->{cols}, 6, '  and an absurd one to the maximum');
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

done_testing();

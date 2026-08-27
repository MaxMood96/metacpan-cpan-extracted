#!perl
# Colour roles, and where a figure is allowed to carry one.
#
# The server names a colour by ROLE - `series:2`, `sev:error` - because it has
# no idea which theme the reader is in, and plot.js resolves those against the
# stylesheet at the moment of drawing. Two things have to be true of that walk
# and neither is visible in the markup:
#
#   a role is resolved WHEREVER it sits, arrays included, and
#   a piece of DATA that happens to read like a role is left alone.
#
# The two pull in opposite directions, which is why they are tested together.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use File::Raw::JSON ();

my $JS = 'root/static/plot.js';
ok(-f $JS, "$JS exists") or do { done_testing(); exit };

my $node = '';
for my $c (qw(node nodejs)) {
    my $p = `command -v $c 2>/dev/null`;
    chomp $p;
    if ($p && -x $p) { $node = $p; last }
}

SKIP: {
    skip 'no JS runtime found', 14 unless $node;

    my $dir = tempdir(CLEANUP => 1);
    copy($JS, "$dir/plot.js") or die $!;
    # plot.js requires it at load, so the copy has to bring it along or the
    # harness dies before a single assertion runs.
    copy('root/static/nsmath.js', "$dir/nsmath.js") or die $!;

    open my $fh, '>', "$dir/run.js" or die $!;
    print $fh <<'HARNESS';
'use strict';
var P = require('./plot.js');

/* The palette plot.js would have read off the stylesheet. Distinctive values,
 * so a wrong lookup is obvious rather than plausible. */
var T = {
    series: ['#s0', '#s1', '#s2', '#s3', '#s4', '#s5', '#s6', '#s7'],
    sev: { error: '#SEV-ERROR', warn: '#SEV-WARN', info: '#SEV-INFO',
           debug: '#SEV-DEBUG' },
    ink: '#INK', muted: '#MUTED', faint: '#FAINT', line: '#LINE',
    paper: '#PAPER', ok: '#OK', warn: '#WARN', err: '#ERR'
};

var out = {};

/* THE SANKEY. One colour per link, which is an ARRAY the same length as the
 * data - the shape the walk used to step over. */
var sankey = [{
    type: 'sankey',
    node: { label: ['internet', 'cards', 'shop'], color: 'series:2',
            line: { color: 'line', width: 1 } },
    link: { source: [0, 0, 2], target: [1, 2, 1], value: [382, 62577, 17101],
            label: ['382 calls, 44 in error', '62577 calls', '17101 calls'],
            color: ['sev:error', 'series:0', 'sev:error'] }
}];
var painted = P.paint(JSON.parse(JSON.stringify(sankey)), T);
out.link_colors = painted[0].link.color;
out.node_color  = painted[0].node.color;
out.node_line   = painted[0].node.line.color;
out.node_labels = painted[0].node.label;
out.link_labels = painted[0].link.label;
out.link_values = painted[0].link.value;

/* DATA THAT READS LIKE A ROLE. `ok` is an alert state, a span status and a
 * perfectly good service name; `line` and `err` are the same kind of word.
 * None of them is a colour when it is sitting in a label. */
var bars = [{
    type: 'bar',
    name: 'ok',
    x: ['ok', 'pending', 'firing', 'line', 'err', 'muted'],
    y: [1, 2, 3, 4, 5, 6],
    text: ['ok', 'err'],
    marker: { color: ['ok', 'warn', 'err', 'muted', 'sev:error', 'series:1'] }
}];
var pb = P.paint(JSON.parse(JSON.stringify(bars)), T);
out.bar_x       = pb[0].x;
out.bar_text    = pb[0].text;
out.bar_name    = pb[0].name;
out.bar_colors  = pb[0].marker.color;

/* THE SEVERITY CHART ON THE LOGS SCREEN, as the server actually emits it.
 *
 * Four stacked bars, each NAMED for its severity band and COLOURED by role.
 * `warn` is both a severity name and one of resolve()'s bare words, so the
 * legend read "#d99b28" where it should have read "warn" - and only that one
 * entry, because `debug`, `info` and `error` are not words resolve() knows.
 * One wrong label in four is exactly the kind of thing that reads as a
 * rendering glitch rather than as a bug. */
var sev = [
  { type: 'bar', name: 'debug', y: [224, 512], x: [1, 2],
    marker: { color: 'sev:debug' } },
  { type: 'bar', name: 'info',  y: [108, 234], x: [1, 2],
    marker: { color: 'sev:info' } },
  { type: 'bar', name: 'warn',  y: [4, 11],    x: [1, 2],
    marker: { color: 'sev:warn' } },
  { type: 'bar', name: 'error', y: [49, 81],   x: [1, 2],
    marker: { color: 'sev:error' } }
];
var ps = P.paint(JSON.parse(JSON.stringify(sev)), T);
out.sev_names  = ps.map(function (t) { return t.name; });
out.sev_colors = ps.map(function (t) { return t.marker.color; });

/* A colorscale is an array of arrays whose second element is a colour. */
var heat = [{ type: 'heatmap',
              colorscale: [[0, 'paper'], [1, 'sev:error']],
              z: [[1, 2]] }];
var ph = P.paint(JSON.parse(JSON.stringify(heat)), T);
out.colorscale = ph[0].colorscale;

/* And resolve() itself still passes through anything it does not know. */
out.unknown = P.resolve('#123456', T);
out.series_wrap = P.resolve('series:9', T);   /* 9 % 8 */

process.stdout.write(JSON.stringify(out));
HARNESS
    close $fh;

    my $raw = `$node $dir/run.js 2>&1`;
    my $r = eval { File::Raw::JSON::file_json_decode($raw) };
    if (!$r) { diag("harness output: $raw"); fail('the harness ran') for 1 .. 14; last SKIP }

    # A ROLE IN AN ARRAY IS STILL A ROLE. This is the one that was broken:
    # paint() handed each element back to itself, paint() returns anything
    # that is not an object unchanged, so plotly received the literal string
    # "sev:error", made nothing of it, and drew every link black.
    is_deeply($r->{link_colors}, ['#SEV-ERROR', '#s0', '#SEV-ERROR'],
              'a per-point colour array is resolved');
    is($r->{node_color}, '#s2', 'a scalar colour still is');
    is($r->{node_line}, '#LINE', '  including a nested one');

    # ...and everything beside it is left exactly as it was.
    is_deeply($r->{node_labels}, ['internet', 'cards', 'shop'],
              'node labels are not colours');
    is_deeply($r->{link_labels},
              ['382 calls, 44 in error', '62577 calls', '17101 calls'],
              '  nor are link labels');
    is_deeply($r->{link_values}, [382, 62577, 17101], '  nor are the values');

    # THE OTHER DIRECTION. resolve() answers to bare words, and those words
    # are ordinary data: an alert state, a span status, a service name. A
    # category axis reading "#OK" instead of "ok" is the same bug wearing a
    # different hat.
    is_deeply($r->{bar_x}, ['ok', 'pending', 'firing', 'line', 'err', 'muted'],
              'a category axis that reads like roles is left alone');
    is_deeply($r->{bar_text}, ['ok', 'err'], '  and so is point text');
    is($r->{bar_name}, 'ok', '  and a trace named "ok" keeps its name');

    # The same words under a colour key ARE colours.
    is_deeply($r->{bar_colors},
              ['#OK', '#WARN', '#ERR', '#MUTED', '#SEV-ERROR', '#s1'],
              'the same words under a colour key are resolved');

    # The reported case, whole: every band keeps its name and gets its colour.
    is_deeply($r->{sev_names}, ['debug', 'info', 'warn', 'error'],
              'the severity chart keeps all four of its legend names');
    is_deeply($r->{sev_colors},
              ['#SEV-DEBUG', '#SEV-INFO', '#SEV-WARN', '#SEV-ERROR'],
              '  and each band is still coloured by its severity');

    is_deeply($r->{colorscale}, [[0, '#PAPER'], [1, '#SEV-ERROR']],
              'a colorscale resolves through two levels of array');

    is($r->{unknown}, '#123456', 'an explicit colour passes through');
    is($r->{series_wrap}, '#s1', 'a series index wraps rather than falling off');
}

done_testing();

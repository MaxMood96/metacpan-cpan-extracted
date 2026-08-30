#!perl
# What a panel's `viz` actually does.
#
# It was validated against five names, stored in the schema, carried to the
# template, and the string `viz` appeared nowhere in the renderer at all - so
# a panel saved as a bar drew a line, and nothing anywhere said so. The test
# whose absence allowed that is the first one below: five values, five
# distinguishable results.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe::View ();
use Punk::Observe::Plot ();
use Punk::Observe::Backend ();
use Punk::Observe::Config ();
use File::Raw::JSON ();

my $P = 'Punk::Observe::Plot';

# A bucketed answer, IN THE SHAPE THE EXECUTOR ACTUALLY EMITS.
#
# A series is `key` and `points`; a point is an ARRAY of
# [ instant, formatted, value ]. The first version of this fixture invented
# `name` and `{ t => ..., value => ... }` hashes, which no query has ever
# produced - so the stat panel passed its test and rendered "-" over live
# data. A fixture that is not the real shape tests nothing.
#
# Verified against `spans | bucket(30s) count by service` on a real store.
sub buckets {
    return {
        ok => 1, shape => 'buckets', bucket_ns => '30000000000',
        series => [
            { key => 'shop',  points => [
                [ '1787000000000000000', '1', 1 ],
                [ '1787000030000000000', '4', 4 ] ] },
            { key => 'cards', points => [
                [ '1787000000000000000', '2', 2 ],
                [ '1787000030000000000', '3', 3 ] ] },
        ],
        meta => {},
    };
}

# --- five kinds, five results ------------------------------------------------

{
    my %seen;
    for my $viz (qw(line area bar stat table)) {
        my %v = (viz => $viz);
        $P->can('bucket_vars')->(\%v, buckets());

        # The shape of the answer, reduced to what actually differs.
        my $what;
        if (defined $v{stat_value})       { $what = "stat:$v{stat_value}" }
        elsif (defined $v{bucket_rows})   { $what = 'table' }
        elsif (defined $v{series_plot}) {
            my $f = File::Raw::JSON::file_json_decode($v{series_plot});
            my $t = $f->{data}[0];
            $what = join ',', $t->{type}, ($t->{mode} // '-'),
                              ($t->{fill} // '-'),
                              ($f->{layout}{barmode} // '-');
        }
        else { $what = 'nothing' }

        ok(!$seen{$what}++, "viz '$viz' draws something no other viz draws")
            or diag("'$viz' produced the same as an earlier one: $what");
    }
}

# And each is the RIGHT thing, not merely a different thing.
{
    my %v = (viz => 'line');
    $P->can('bucket_vars')->(\%v, buckets());
    my $f = File::Raw::JSON::file_json_decode($v{series_plot});
    is($f->{data}[0]{type}, 'scatter', 'line is a scatter');
    is($f->{data}[0]{mode}, 'lines',   '  in lines mode');
    ok(!defined $f->{data}[0]{fill},   '  with nothing filled under it');
}

{
    my %v = (viz => 'area');
    $P->can('bucket_vars')->(\%v, buckets());
    my $f = File::Raw::JSON::file_json_decode($v{series_plot});
    is($f->{data}[0]{type}, 'scatter', 'area is a scatter too');
    ok($f->{data}[0]{fill},            '  with a fill');
    ok($f->{data}[0]{stackgroup},      '  and stacked, because an area chart '
                                     . 'of overlapping series is unreadable');
}

{
    my %v = (viz => 'bar');
    $P->can('bucket_vars')->(\%v, buckets());
    my $f = File::Raw::JSON::file_json_decode($v{series_plot});
    is($f->{data}[0]{type}, 'bar', 'bar is a bar');
    ok(!defined $f->{data}[0]{mode},
       '  with no mode, which a bar has no use for');
    # STACKED, NOT OVERLAID. Two series of bars on top of each other hide one
    # of them completely and the reader cannot tell that is what happened.
    is($f->{layout}{barmode}, 'stack', '  and the bars stack');
}

{
    my %v = (viz => 'stat');
    $P->can('bucket_vars')->(\%v, buckets());
    is($v{stat_value}, '4', 'stat is the latest value of the first series');
    # The shape is asserted here too, so a fixture that drifts back to an
    # invented one fails rather than passing vacuously.
    is(ref buckets()->{series}[0]{points}[0], 'ARRAY',
       '  and a point is the array the executor emits, not a hash');
    ok(!defined $v{series_plot},
       '  and NOT a figure - one number needs no charting library, and is '
     . 'still there with scripting off');
}

{
    my %v = (viz => 'table');
    $P->can('bucket_vars')->(\%v, buckets());
    ok($v{bucket_rows}, 'table is rows');
    ok(!defined $v{series_plot},
       '  and not a chart with a table under it, which is two answers where '
     . 'one was asked for');
}

# --- a kind the answer cannot take is refused -------------------------------
#
# `area`, `bar` and `stat` are shapes of a time series. Over a bare row set
# there is nothing to put on the x axis, and drawing a line instead - which is
# what happened - is the panel showing something other than what was chosen.
{
    package Shaped::Store;
    sub new { my ($c, $sh) = @_; bless { sh => $sh }, $c }
    sub query { my $s = shift; return { ok => 1, shape => $s->{sh},
                                        rows => [], groups => [], meta => {} } }
    sub records { [] }
    sub stats   { {} }
}

{
    # `bar` over a plain grouped answer is one bar per group - the figure the
    # metrics page has always drawn for that shape - so it is DRAWN, not
    # refused. This row changed when `| viz` landed: refusing bar-on-groups
    # in a panel while the explorer drew it would be two answers to one
    # spelling.
    my %want = (
        rows    => { line => 0, table => 0, area => 1, bar => 1, stat => 1 },
        groups  => { line => 0, table => 0, area => 1, bar => 0, stat => 1 },
        buckets => { line => 0, table => 0, area => 0, bar => 0, stat => 0 },
    );

    for my $shape (sort keys %want) {
        for my $viz (sort keys %{ $want{$shape} }) {
            my $v = Punk::Observe::View->page(
                Shaped::Store->new($shape), 'dashboard',
                { panels_inline => 1, dashboards => { title => 'X', panels =>
                    [ { title => 'p', query => 'log', viz => $viz } ] } });

            my $p = $v->{panels}[0];
            # A REFUSED PANEL STILL REACHES THE PAGE. Skipping it loses the
            # one thing that would tell the reader why it is not there.
            ok($p, "$shape/$viz: the panel is on the page either way");

            if ($want{$shape}{$viz}) {
                like($p->{refusal} || '', qr/bucketed answer/,
                     "  $shape/$viz is refused");
                like($p->{refusal} || '', qr/bucket\(30s\)/,
                     "    naming the stage that would fix it");
            }
            else {
                is($p->{refusal} || '', '', "  $shape/$viz is drawn");
            }
        }
    }
}

# --- an unknown viz is visible, not silently a table -------------------------
#
# po_viz_from maps anything unrecognised onto `table`. Right for a parser and
# wrong for a stored row: one written by a newer version, or by hand, would
# render as a table with nothing saying the chart it asked for was ignored.
{
    my $dir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$dir/c.db");
    $db->migrate;
    my $C = 'Punk::Observe::Config';
    $C->can('save_dashboard')->($db, 'default', { slug => 'o', title => 'O' });
    $C->can('save_panel')->($db, 'default', 'o',
                            { title => 't', query => 'log', viz => 'bar' });

    # Past the API, as a newer release or a person with psql would.
    $db->dbh->do('UPDATE dashboard_panels SET viz = ?', undef, 'sunburst');

    my $d = $C->can('dashboards')->($db, 'default', 'o');
    is($d->{panels}[0]{viz}, 'sunburst',
       'a viz this release does not know is read back as written');
    ok($d->{panels}[0]{viz_unknown},
       '  and flagged, so the editor can show it rather than downgrade it');

    # The picker itself cannot offer one: it is built from the validator.
    my %known = map { $_ => 1 } Punk::Observe::Dashboard::viz_names();
    ok(!$known{sunburst}, '  while the picker still offers only what is known');
}

# --- the brush survives ------------------------------------------------------
#
# brush.js binds drag-to-select on [data-brush], which is the inline-SVG panel.
# A chart change that dropped the attribute would remove range selection from
# the dashboard without removing anything visible.
SKIP: {
    # panelslow.tmpl: the panel BODY moved into the fragment template when
    # the dashboard became a deferred shell - the chart markup went with it.
    my $f = 'root/templates/panelslow.tmpl';
    skip 'no panel template', 2 unless -f $f;
    my $t = do { open my $fh, '<', $f or die $!; local $/; <$fh> };
    like($t, qr/data-brush/, 'the dashboard still offers drag-to-select');
    like($t, qr/data-chart/, '  and still marks its charts for plot.js');
}

# --- `| viz` in the query itself ---------------------------------------------
#
# The stage form: presentation as a property of the query, so it rides a
# saved view, a pasted URL and a panel string. It is a FIELD on the parse
# result, not a stage in the list - a stage kind the planner had no case for
# is exactly how `top N` shipped doing nothing.
{
    require Punk::Observe::Query;
    my $Q = 'Punk::Observe::Query';

    my $r = $Q->can('parse')->('log | by cache.hit | count | viz bar');
    ok($r->{ok}, 'a viz query parses');
    is($r->{viz}, 'bar', '  and the result names the chart');
    is(scalar(grep { $_->{kind} eq 'viz' } @{ $r->{stages} }), 0,
       '  while the stage list stays pure transforms');

    is($Q->can('parse')->("log | count | viz 'line'")->{viz}, 'line',
       'a quoted name works, because values elsewhere are quoted');

    # STRICT AT THE PARSER. po_viz_from's fall-back-to-table is right for a
    # stored row and wrong for a person typing, where an unknown name is a
    # typo to name.
    my $bad = $Q->can('parse')->('log | viz sunburst');
    ok(!$bad->{ok}, 'an unknown chart kind is refused, not silently a table');
    like($bad->{error}, qr/line, area, bar, stat or table/,
         '  naming the five that exist');

    my $twice = $Q->can('parse')->('log | viz bar | viz line');
    ok(!$twice->{ok}, 'viz twice is refused');
    like($twice->{error}, qr/one chart per answer/, '  with the reason');

    # THE PARSER'S LIST IS THE VALIDATOR'S LIST, asserted so the two cannot
    # drift - the parser cannot reach po_viz_from, so it carries a copy, and
    # a copy is only safe with a test on it.
    for my $v (Punk::Observe::Dashboard::viz_names()) {
        ok($Q->can('parse')->("log | viz $v")->{ok},
           "the parser accepts '$v', which the panel validator knows");
    }
}

# And the explorer honours it, end to end over a real store.
{
    require Punk::Observe::Store;
    require Punk::Observe::WAL;
    my $dir = tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $dir, tenant => 'default');
    my $base = (time - 600) . '000000000';
    Punk::Observe::WAL::append($st->wal_path, [ map { {
        kind => 2, t => Punk::Observe::Store::nadd($base, $_ * 1_000_000),
        duration => 0, body => "l$_", severity => 9, span_kind => 0,
        status => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
        parent_id => 0, attrs => { 'cache.hit' => $_ % 2 } } } 1 .. 60 ],
        0, 0);
    $st->seal;

    my $probe = sub {
        my ($q) = @_;
        my $v = Punk::Observe::View->page($st, 'explore',
                                          { q => $q, range => '1h' });
        return "refused: $v->{error}" if $v->{error};
        return 'table' unless $v->{series_plot};
        my $f = File::Raw::JSON::file_json_decode($v->{series_plot});
        return $f->{data}[0]{type};
    };

    is($probe->('log | by cache.hit | count | viz bar'), 'bar',
       'viz bar over groups draws one bar per group in the explorer');
    like($probe->('log | by cache.hit | count | viz line'),
         qr/^refused: line needs a bucketed answer/,
         'and viz line over groups is refused, naming the fix');
    is($probe->('log | bucket(1m) count | viz bar'), 'bar',
       'viz bar over buckets is the stacked time series');
    is($probe->('log | by cache.hit | count | viz table'), 'table',
       'viz table is the table those shapes already are');

    # AND THE LOGS PAGE IS THE SAME FUNCTION, LITERALLY. `| viz bar` typed
    # into the logs box drew nothing while the identical query drew in the
    # explorer - the panel/explorer split all over again, one page ahead.
    # povw_apply_viz is shared now, and this pins that the sharing holds.
    my $lprobe = sub {
        my ($q) = @_;
        my $v = Punk::Observe::View->page($st, 'logs',
                                          { q => $q, range => '1h' });
        return "refused: $v->{error}" if $v->{error};
        return 'table' unless $v->{series_plot};
        my $f = File::Raw::JSON::file_json_decode($v->{series_plot});
        return $f->{data}[0]{type};
    };

    is($lprobe->('log | by cache.hit | count | viz bar'), 'bar',
       'the logs page draws viz bar over groups, exactly as the explorer');
    like($lprobe->('log | by cache.hit | count | viz line'),
         qr/^refused: line needs a bucketed answer/,
         '  and refuses viz line over groups with the same message');
    is($lprobe->('log | bucket(1m) count | viz bar'), 'bar',
       '  and draws a bucketed answer, which used to head an empty panel');
    is($lprobe->('log | by cache.hit | count | viz table'), 'table',
       '  and viz table stays the table');

    # The chart does not eat the numbers: the group table renders beside it.
    my $both = Punk::Observe::View->page($st, 'logs',
        { q => 'log | by cache.hit | count | viz bar', range => '1h' });
    is(scalar @{ $both->{groups} }, 2,
       'the group table still stands beside the bar chart');
}

# In a panel, the query's own viz wins over the column: the one written next
# to the question is the one somebody meant, and it is the one a pasted
# explorer URL carries.
{
    package Groups::Store;
    sub new { bless {}, shift }
    sub query { return { ok => 1, shape => 'groups', viz => 'bar',
                         groups => [ { key => 'a', value => 3, count => 3 } ],
                         meta => {} } }
    sub records { [] }
    sub stats { {} }
}
{
    my $v = Punk::Observe::View->page(Groups::Store->new, 'dashboard',
        { panels_inline => 1, dashboards => { title => 'X', panels =>
            [ { title => 'p', query => 'log | by k | count | viz bar',
                viz => 'line' } ] } });
    my $p = $v->{panels}[0];
    is($p->{refusal} || '', '', 'the panel is not refused');
    ok($p->{series_plot}, '  and draws the bars the query asked for');
    my $f = File::Raw::JSON::file_json_decode($p->{series_plot});
    is($f->{data}[0]{type}, 'bar',
       '  the query\'s viz beat the panel\'s stale column');
}

# --- the cross-signal stages EXECUTE ----------------------------------------
#
# They used to refuse, and before that they lied: `| exemplars | traces |
# logs` parsed, planned, and returned the metric stream unchanged, because
# the planner recorded the re-key and no executor consumed it. What is
# asserted here is the shape of the answer rather than its size - a pipeline
# that silently does nothing returns the right NUMBER of rows, which is
# exactly how it went unnoticed.
{
    require Punk::Observe::Store;
    require Punk::Observe::WAL;
    my $dir = tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $dir, tenant => 'default');
    Punk::Observe::WAL::append($st->wal_path, [ {
        kind => 1, t => (time . '000000000'), duration => 0, body => 'm',
        severity => 0, span_kind => 0, status => 0, trace_hi => 0,
        trace_lo => 0, span_id => 0, parent_id => 0, value => 1,
        attrs => {} } ], 0, 0);
    $st->seal;

    my $now = time;
    my $x = $st->query('metric m | exemplars | traces | logs',
                       from => (($now - 3600) . '000000000'),
                       to   => "${now}000000000");
    ok($x->{ok}, 'the cross-signal pipeline runs') or diag $x->{error};
    # The seeded point carries NO exemplar, so the honest answer is nothing:
    # an empty id set must read as "joins to nothing", never as "no filter",
    # which would return the whole store.
    is(scalar @{ $x->{rows} }, 0,
       '  a point with no exemplar joins to nothing, not to everything');

    my $y = $st->query('metric m | exemplars',
                       from => (($now - 3600) . '000000000'),
                       to   => "${now}000000000");
    ok($y->{ok}, '  `| exemplars` alone runs too') or diag $y->{error};
    is(scalar @{ $y->{rows} }, 0, '    and keeps only points carrying ids');

    # `metric m | spans` is refused ON PURPOSE: a metric row carries no trace
    # id until `| exemplars` puts one on it, and the refusal says exactly
    # that - guidance, where silence used to return the metric unchanged.
    my $z = $st->query('metric m | spans',
                       from => (($now - 3600) . '000000000'),
                       to   => "${now}000000000");
    ok(!$z->{ok}, '  `| spans` straight off a metric is refused');
    like($z->{error}, qr/add \| exemplars first/,
         '    naming the stage that supplies the id');
}

done_testing();

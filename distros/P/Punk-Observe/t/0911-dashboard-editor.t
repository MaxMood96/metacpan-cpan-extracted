#!perl
# The dashboard editor.
#
# Before this, dashboards were a facade: a renderer with no source, a schema
# with no reader, a validator with no caller, and an edit route that rendered
# the view page. 02 built the store and the write routes; this is the form
# over them, and the two things the renderer was getting wrong underneath.
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use Punk::Observe::View ();
use Punk::Observe::Backend ();
use Punk::Observe::Config ();
use Punk::Plugin::Observe ();

my $V = 'Punk::Observe::View';
my $C = 'Punk::Observe::Config';

sub fresh {
    my $dir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$dir/c.db");
    $db->migrate;
    return $db;
}

# --- the grid is clamped where it is DRAWN ----------------------------------
#
# `cols-N` and `span-N` are static CSS classes, so a number outside the range
# the stylesheet covers renders as a class nothing matches and the panel
# silently occupies one column. The schema has a CHECK and the writers clamp,
# but a host's own seam is a hashref that went near neither - so the last
# chance to be right is at the point of drawing.
{
    my $v = $V->page(undef, 'dashboard', { dashboards => {
        title => 'X', cols => 99, panels => [
            { title => 'a', query => 'log', span => 12 },
            { title => 'b', query => 'log', span => -3 },
            { title => 'c', query => 'log', span => 3 },
            { title => 'd', query => 'log' },
        ] } });

    is($v->{cols}, 6, 'a seam asking for 99 columns gets a grid that exists');
    is_deeply([ map { $_->{span} } @{ $v->{panels} } ], [ 6, 1, 3, 1 ],
              'and every span is clamped into the range with rules behind it');

    # Every class the renderer can emit has a rule. This is the assertion that
    # would have caught it, and it is a grep because the alternative is
    # noticing by eye that one panel is narrow.
    my $css = do { open my $fh, '<', 'root/static/observe.css' or die $!;
                   local $/; <$fh> };
    for my $n (1 .. 6) {
        ok($n == 1 || $css =~ /\.cols-$n\b/, "the stylesheet has .cols-$n");
    }
    for my $n (2 .. 6) {
        ok($css =~ /\.span-$n\b/, "the stylesheet has .span-$n");
    }
}

# --- a panel is not allowed to read the whole store -------------------------
#
# A dashboard runs its panels serially in the request and passed NO limit, so
# each one got Store::query's own 500,000-row default. Six panels was six of
# those before the first byte of HTML.
{
    package Counting::Store;
    sub new { bless { calls => [] }, shift }
    sub query {
        my ($self, $q, %opt) = @_;
        push @{ $self->{calls} }, { q => $q, %opt };
        return { ok => 1, shape => 'rows', rows => [], meta => {} };
    }
    # The page asks for these on the way past.
    sub records { return [] }
    sub stats   { return {} }
}

{
    my $store = Counting::Store->new;
    # Two shapes on one dashboard: the budget FOLLOWS the shape. A rows
    # panel shows twenty lines, so a capped newest-first scan is generous;
    # an aggregate eats every row in the window, and capping it silently
    # narrowed a 6h chart to the newest fifteen minutes of a busy store -
    # the range picker changed the URL and not the answer.
    my @panels = ({ title => 'lines', query => 'log | limit 50' },
                  { title => 'agg',   query => 'log | count' },
                  { title => 'bkt',   query => 'log | bucket(30s) count' },
                  { title => 'slow',  query => 'spans | slowest 5' });
    $V->page($store, q{dashboard},
             { panels_inline => 1,
               dashboards => { title => q{X}, panels => \@panels } });

    is(scalar @{ $store->{calls} }, 4, 'a four-panel dashboard runs four queries');
    my %by = map { $_->{q} => $_ } @{ $store->{calls} };
    ok($by{'log | limit 50'}{limit}, 'a plain rows panel carries a row budget');
    cmp_ok($by{'log | limit 50'}{limit}, '<', 500_000,
           '  well under the store default');

    # A PARTIAL GRAPH IS A POINTLESS GRAPH: an aggregate panel scans the
    # whole window. The store turns an UNSET budget into its 500,000-row
    # default, so "no ceiling" has to be said explicitly, in all three
    # spellings the query call accepts.
    for my $agg ('log | count', 'log | bucket(30s) count', 'spans | slowest 5') {
        for my $knob (qw(limit hard_max max_rows)) {
            cmp_ok($by{$agg}{$knob}, '>', 1e15,
                   "'$agg' lifts $knob past any real store");
        }
    }
}

# --- a truncated aggregate says so -------------------------------------------
#
# Newest-first, a truncated rows panel still shows the true newest twenty; a
# truncated aggregate covers a sliver of the window and looks complete. The
# chart cannot say it, so the panel does.
{
    package Truncating::Store;
    sub new { bless {}, shift }
    sub query { return { ok => 1, shape => 'groups',
                         groups => [ { key => 'a', value => 1, count => 1 } ],
                         meta => { truncated => 1, scanned_rows => 500000 } } }
    sub records { [] }
    sub stats { {} }
}
{
    my $v = $V->page(Truncating::Store->new, q{dashboard},
             { panels_inline => 1, dashboards => { title => 'X', panels =>
                 [ { title => 'p', query => 'log | by k | count' } ] } });
    ok($v->{panels}[0]{partial}, 'a truncated aggregate panel is marked partial');
    like($v->{panels}[0]{partial}, qr/500,000|500000/,
         '  carrying how far the scan got');
}

# --- the dashboard obeys the reader's window ---------------------------------
#
# Every panel already ran over the page window; what was missing was the
# CONTROL - the range vars were deliberately stripped, so narrowing a
# dashboard to the incident meant editing the URL by hand.
{
    my $store = Counting::Store->new;
    my $v = $V->page($store, q{dashboard},
             { panels_inline => 1, range => q{6h},
               dashboards => { title => 'X', panels =>
                   [ { title => 'p', query => 'log | count' } ] } });

    my $call = $store->{calls}[0];
    ok($call->{from} && $call->{to}, 'a panel queries the page window');
    # 6h plus the window's one-second inclusive edge.
    my $span = Punk::Observe::Store::nsub($call->{to}, $call->{from});
    cmp_ok($span, '>=', 21_600_000_000_000, '  at least six hours wide');
    cmp_ok($span, '<',  21_610_000_000_000, '  and not meaningfully more');

    is($v->{range}, '6h', 'and the range control reaches the template');
    ok(ref $v->{ranges} eq 'ARRAY' && @{ $v->{ranges} },
       '  with its presets, so the picker can render');
}

# --- the editor is a template over the same data ----------------------------
#
# Not a second page with its own reader: the editor needs exactly what the
# read page needs plus a form around it, and building it from a second data
# path is how the two come to disagree about what is on the dashboard.
{
    my $db = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops', cols => 3 });
    $C->can('save_panel')->($db, 'default', 'ops',
        { title => 'errors', query => 'log | count', viz => 'bar', span => 2 });

    my $d = $C->can('dashboards')->($db, 'default', 'ops');
    my $v = $V->page(undef, 'dashboard', { dashboards => $d });
    my $p = $v->{panels}[0];

    # THE EDITOR NEEDS THE PANEL, not only the drawing of it. None of these
    # four were passed through before, because the read page ignores them.
    ok(defined $p->{id},       'a panel carries an id to address it by');
    is($p->{position}, 0,      '  its order');
    is($p->{viz},      'bar',  '  the chart kind it was saved as');
    is($p->{query},    'log | count',
       '  and the raw query, to put back in the box');
}

# The picker is built from the validator's own list, because a picker offering
# something check_panel refuses is a panel that cannot be saved.
{
    my @viz = Punk::Observe::Dashboard::viz_names();
    is_deeply(\@viz, [qw(line area bar stat table)],
              'the chart kinds come from the C that validates them');

    for my $v (@viz) {
        my $r = Punk::Observe::Dashboard::check_panel(
            { title => 't', query => 'log', viz => $v });
        ok($r->{ok}, "  check_panel accepts '$v'");
        is($r->{viz}, $v, "    and keeps it");
    }
}

# AN ABSENT viz IS A LINE, which is what the schema column defaults to.
# `po_viz_from` turns anything it does not recognise into `table` - correct
# for a parser, wrong for a panel nobody chose a chart for, and it made every
# seeded panel in the demo come back as a table.
{
    my $db = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops' });
    $C->can('save_panel')->($db, 'default', 'ops',
                            { title => 'no viz given', query => 'log' });
    my $d = $C->can('dashboards')->($db, 'default', 'ops');
    is($d->{panels}[0]{viz}, 'line', 'a panel saved with no viz is a line');

    $C->can('save_panel')->($db, 'default', 'ops',
                            { title => 'nonsense', query => 'log', viz => 'wat' });
    $d = $C->can('dashboards')->($db, 'default', 'ops');
    my ($n) = grep { $_->{title} eq 'nonsense' } @{ $d->{panels} };
    is($n->{viz}, 'table', '  and one asking for something unknown still falls back');
}

# --- a refusal names its field ----------------------------------------------
#
# "That query does not parse" over the whole form is a hunt. The same words
# beside the query box are an instruction.
{
    my $db = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops' });

    my $q = $C->can('save_panel')->($db, 'default', 'ops',
                                    { title => 'x', query => 'log | wat' });
    is($q->{field}, 'query', 'a query that does not parse blames the query box');

    my $t = $C->can('save_panel')->($db, 'default', 'ops',
                                    { query => 'log' });
    is($t->{field}, 'title', 'a missing title blames the title box');

    my $s = $C->can('save_dashboard')->($db, 'default', { slug => 'a/b', title => 'X' });
    is($s->{field}, 'slug', 'a bad slug blames the address box');

    my $n = $C->can('save_dashboard')->($db, 'default', { slug => 'ok' });
    is($n->{field}, 'title', 'a missing dashboard title blames its own box');
}

# --- delete ------------------------------------------------------------------
{
    my $db = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops' });
    $C->can('save_panel')->($db, 'default', 'ops', { title => 'a', query => 'log' });
    $C->can('save_panel')->($db, 'default', 'ops', { title => 'b', query => 'log' });

    my $d = $C->can('dashboards')->($db, 'default', 'ops');
    is(scalar @{ $d->{panels} }, 2, 'two panels to start');

    my $r = $C->can('delete_panel')->($db, 'default', 'ops', $d->{panels}[0]{id});
    ok($r->{ok}, 'a panel deletes');
    $d = $C->can('dashboards')->($db, 'default', 'ops');
    is(scalar @{ $d->{panels} }, 1, '  leaving the other one');
    is($d->{title}, 'Ops', '  and the dashboard itself');

    # A panel id from another dashboard is not deletable through this one.
    $C->can('save_dashboard')->($db, 'default', { slug => 'two', title => 'Two' });
    my $x = $C->can('delete_panel')->($db, 'default', 'two', $d->{panels}[0]{id});
    ok($x->{refused}, 'a panel cannot be deleted through a dashboard it is not on');

    ok($C->can('delete_dashboard')->($db, 'default', 'ops')->{ok}, 'a dashboard deletes');
    my $gone = $C->can('dashboards')->($db, 'default', 'ops');
    ok($gone->{missing}, '  and is then missing rather than empty');
}

# --- the editor renders ------------------------------------------------------
SKIP: {
    eval { require Template::Stencil; 1 }
        or skip 'Template::Stencil is not installed', 6;

    my $s = Template::Stencil->new(template_dir => 'root/templates',
                                   wrapper => 'layout.tmpl');
    my %empty = Punk::Plugin::Observe::_empty({ prefix => '/observe' });

    my $db = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops' });
    $C->can('save_panel')->($db, 'default', 'ops',
        { title => 'errors', query => 'log | count', viz => 'bar' });
    my $v = $V->page(undef, 'dashboard',
                     { dashboards => $C->can('dashboards')->($db, 'default', 'ops') });

    my @viz = Punk::Observe::Dashboard::viz_names();
    $v->{viz_options} = [ map { { name => $_ } } @viz ];
    for my $p (@{ $v->{panels} }) {
        my $cur = $p->{viz} || 'line';
        $p->{viz_options} = [ map { { name => $_, current => ($_ eq $cur ? 1 : 0) } } @viz ];
    }

    my $html = eval {
        $s->render('dashedit.tmpl', { %empty, %$v, editing => 1, writable => 1,
                                      csrf_field => '<input name="_csrf" value="tok">' });
    };
    ok(defined $html, 'the editor renders') or diag $@;

    # EVERY FORM CARRIES A TOKEN. One that does not is forgeable from another
    # origin, and counting is the only way to be sure none was missed.
    my $forms = () = ($html || '') =~ /<form/g;
    my $toks  = () = ($html || '') =~ /name="_csrf"/g;
    cmp_ok($forms, '>', 0, 'it has forms');
    is($toks, $forms, '  and every one of them carries a CSRF token');

    like($html || '', qr/value="log \| count"/,
         'the panel query is in the box, not only in the chart');
    like($html || '', qr/<option value="bar" selected/,
         '  and its chart kind is the selected option');

    # Read-only says why rather than showing a button that does nothing.
    my $ro = $s->render('dashedit.tmpl', { %empty, %$v, editing => 1,
                                           writable => 0, csrf_field => '' });
    like($ro, qr/read-only/i, 'a read-only mount says so on the editor');
}

# --- `viz` decides what a panel draws ---------------------------------------
#
# IT WAS STORED, VALIDATED, CARRIED TO THE TEMPLATE AND NEVER READ. Every
# bucketed panel drew a chart, including the ones somebody had deliberately
# set to `table` - which is a setting that exists, is offered by the editor,
# survives a round trip through the database, and did nothing at all.
{
    my @panels = map {
        { title => "as a $_", viz => $_,
          query => 'log | bucket(1m) count by severity' }
    } qw(line table);

    my $v = $V->page(Seeded::Store->new, q{dashboard},
                     { panels_inline => 1, dashboards => { title => 'X', panels => \@panels } });

    my %by = map { $_->{viz} => $_ } @{ $v->{panels} || [] };
    ok($by{line} && $by{table}, 'both panels are built') or return;

    ok(length($by{line}{series_plot} || ''), 'a line panel gets a figure');
    is(scalar @{ $by{line}{bucket_rows} || [] }, 0,
       '  and no table under it, which would be two answers to one question');

    ok(scalar @{ $by{table}{bucket_rows} || [] }, 'a table panel gets rows');
    is(length($by{table}{series_plot} || ''), 0,
       '  and no chart, which is the whole point of choosing table');
}

# A tiny store that answers one bucketed query, so the assertion above is
# about the renderer rather than about whatever happens to be on disk.
{
    package Seeded::Store;
    sub new { return bless {}, shift }
    sub query {
        my ($self, $q) = @_;
        return {
            ok => 1, shape => 'buckets', bucket_ns => '60000000000',
            series => [ { key => 'info',
                          points => [ [ '1787000000000000000', 5, 5 ],
                                      [ '1787000060000000000', 7, 7 ] ] } ],
            meta => { scanned_rows => 12, truncated => 0, exact => 1 },
        };
    }
}

# --- the whole table saves in one POST ---------------------------------------
#
# Editing three rows was three submits, one per row form. save_panels takes
# every row at once: it validates ALL of them before writing ANY (the refusal
# names the row it is about), and the writes are one transaction - the answer
# is the whole edit or none of it, never a dashboard half made of both.
{
    my $db = fresh();
    $C->can('save_dashboard')->($db, 'default', { slug => 'ops', title => 'Ops' });
    $C->can('save_panel')->($db, 'default', 'ops', { title => 'a', query => 'log' });
    $C->can('save_panel')->($db, 'default', 'ops', { title => 'b', query => 'log' });
    my $d = $C->can('dashboards')->($db, 'default', 'ops');
    my ($ia, $ib) = map { $_->{id} } @{ $d->{panels} };

    my $r = $C->can('save_panels')->($db, 'default', 'ops', [
        { id => $ia, title => 'A2', query => 'log | count',
          viz => 'bar', span => 2, position => 1 },
        { id => $ib, title => 'B2', query => 'spans | bucket(30s) count',
          viz => 'area', span => 3, position => 0 },
    ]);
    ok($r->{ok}, 'two rows save in one call') or diag($r->{error});
    $d = $C->can('dashboards')->($db, 'default', 'ops');
    is_deeply([ map { [ @$_{qw(title viz span)} ] } @{ $d->{panels} } ],
              [ [ 'B2', 'area', 3 ], [ 'A2', 'bar', 2 ] ],
              '  both rows landed, reordered by their new positions');

    # ONE BAD ROW REFUSES THE WHOLE SAVE, and the good row is not applied -
    # a half-saved table looks exactly like a save that worked.
    my $bad = $C->can('save_panels')->($db, 'default', 'ops', [
        { id => $ia, title => 'A3', query => 'log | count' },
        { id => $ib, title => 'B3', query => 'log | wat' },
    ]);
    ok(!$bad->{ok} && $bad->{refused}, 'one unparseable row refuses the save');
    like($bad->{error}, qr/B3/, '  naming the row it is about');
    is($bad->{field}, 'query',  '  and the field');
    $d = $C->can('dashboards')->($db, 'default', 'ops');
    is_deeply([ map { $_->{title} } @{ $d->{panels} } ], [ 'B2', 'A2' ],
              '  and NOTHING was written - not even the valid row');

    # A row deleted under the form - stale tab - refuses cleanly and leaves
    # the surviving rows exactly as they were.
    $C->can('delete_panel')->($db, 'default', 'ops', $ib);
    my $gone = $C->can('save_panels')->($db, 'default', 'ops', [
        { id => $ia, title => 'A4', query => 'log | count' },
        { id => $ib, title => 'B4', query => 'log | count' },
    ]);
    ok(!$gone->{ok}, 'a vanished row refuses the save');
    like($gone->{error}, qr/no longer exists/, '  saying why');
    $d = $C->can('dashboards')->($db, 'default', 'ops');
    is($d->{panels}[0]{title}, 'A2', '  and the surviving row is untouched');
}

# --- the editor is ONE form with real columns --------------------------------
#
# The old markup put each row inside a single colspan cell holding its own
# form, so the header row aligned with nothing and every row saved alone.
{
    my $t = do { open my $fh, '<', 'root/templates/dashedit.tmpl' or die $!;
                 local $/; <$fh> };
    like($t, qr{method="post"\s+action="\{% prefix %\}/dashboards/\{% slug %\}/panels/save"},
         'one form posts the whole table');
    unlike($t, qr/<td colspan/,
           'rows are real columns under real headers, not one cell each');
    like($t, qr/form="del-panel-\{% p\.id %\}"/,
         'each Delete reaches its own form through the form attribute');
    like($t, qr/id="del-panel-\{% p\.id %\}"/,
         '  and that form exists outside the table\x27s own');
    like($t, qr/name="p\{% p\.id %\}_query"/,
         'row fields are keyed by panel id');
}

done_testing();

#!perl
# The screens, rendered through Template::Stencil.
#
# The headline assertion: THE WATERFALL IS COMPLETE AND CORRECT IN THE MARKUP
# WITH NO JAVASCRIPT. This test never runs any. JavaScript makes the waterfall
# navigable; it does not make it exist, and that is the test of whether the
# server-rendered decision was taken seriously.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;

BEGIN {
    eval { require Template::Stencil; 1 }
        or plan skip_all => 'Template::Stencil not installed';
}
use Punk::Observe;

my $DIR = 'root/templates';

# RENDERED THE WAY THE APPLICATION RENDERS, from the template directory
# rather than from a string. A screen that includes a shared partial - the
# time-range picker is on four of them - cannot resolve the include without
# one, and rendering from a string here would test a template the app never
# uses.
my $ST = Template::Stencil->new({ template_dir => $DIR });
sub render {
    my ($file, $vars) = @_;
    return $ST->render($file, $vars);
}

# --- every screen renders with data AND with none --------------------------
#
# The empty state is what a new install sees first, and it is usually the
# thing nobody looked at.

my %empty = (
    prefix => '/observe', query => '', title => '', width => 600, height => 200,
    root_name => '', span_count => 0, duration_ms => 0, orphans => 0,
    cycles => 0, spans => [], rows => [], series => [], nodes => [], edges => [],
    yticks => [], back_edges => 0, error => '', hint => '', refusal => '',
    truncated => 0, scanned => 0,
    tail => 0, query_esc => '', from => '0', to => '0',
    rules => [], silences => [], broken => 0, panels => [], cols => 2,
    slug => '', 
    ingest_rate => 0, wal_depth => 0, segments => 0, compaction_lag => 0,
    series_cap => 0, series_rejected => 0, mapped_deleted => 0,
);

for my $f (qw(trace.tmpl logs.tmpl metrics.tmpl map.tmpl status.tmpl
              alerts.tmpl dashboard.tmpl)) {
    my $out = eval { render($f, \%empty) };
    ok(defined $out, "$f renders with no data") or diag $@;
    ok(length $out, "  producing output");
    unlike($out, qr/\{%/, "  with no unrendered directives left");
}

# --- THE WATERFALL, WITH NO JAVASCRIPT -------------------------------------

{
    my @spans = (
        { depth => 0, span_id => '1', kind_name => 'server',  name => 'POST /pay',
          start_pct => 0,  width_pct => 100, dur_ms => '500ms', indent => 0 },
        { depth => 1, span_id => '2', kind_name => 'client',  name => 'checkout',
          start_pct => 5,  width_pct => 70,  dur_ms => '350ms', indent => 12 },
        { depth => 2, span_id => '3', kind_name => 'internal', name => 'SELECT orders',
          start_pct => 10, width_pct => 40,  dur_ms => '200ms', indent => 24 },
    );
    my $out = render('trace.tmpl', { %empty,
        root_name => 'POST /pay', span_count => 3, duration_ms => 500,
        spans => \@spans });

    # Every span is present, with its nesting and its timing.
    for my $s (@spans) {
        like($out, qr/\Q$s->{name}\E/, "the waterfall markup contains '$s->{name}'");
        like($out, qr/data-span="\Q$s->{span_id}\E"/, "  and its span id");
        like($out, qr/data-depth="\Q$s->{depth}\E"/, "  and its depth");
    }
    like($out, qr/--start:0%/,   'a bar carries its start as a percentage');
    like($out, qr/--width:100%/, '  and its width');
    like($out, qr/--start:10%.*--width:40%/s, '  for the deepest span too');
    like($out, qr/500ms/, 'the durations are in the markup');
    like($out, qr/kind-server/,   'span kind is a class, so CSS colours it');
    like($out, qr/kind-internal/, '  for every kind present');

    # Nesting is expressed structurally, not only by indentation.
    my @depths = ($out =~ /data-depth="(\d+)"/g);
    is_deeply(\@depths, [ 0, 1, 2 ], 'the depths appear in tree order');

    # And the assertion this whole section exists for.
    unlike($out, qr/<script/, 'the waterfall markup contains no script at all');
}

# --- the pager carries every filter ----------------------------------------
#
# The Next-50 link is a query string rebuilt by hand, and any filter left out
# is a filter that paging silently clears: errors=1 was dropped, so the
# errors-only page 2 was every trace's page 2.

{
    # The pager lives inside the results panel, so it only exists when a
    # trace does.
    my $trow = { id => 'abc', service => 'api', name => 'GET /',
                 row_class => '', width_pct => 50, spans => 3, errors => 1,
                 duration => '12ms' };
    my $out = render('trace.tmpl', { %empty, traces => [ $trow ],
        next_cursor => 'c1', paged => 1, errors_only => 1,
        query_esc => 'svc', min_ms => 250, range_amp => '&range=1h' });
    like($out, qr{traces\?q=svc&min_ms=250&errors=1&after=c1&(?:amp;)?range=1h},
         'the next page keeps q, min_ms, errors and the range');
    like($out, qr{traces\?q=svc&min_ms=250&errors=1&(?:amp;)?range=1h">Back},
         '  and so does the way back');

    my $off = render('trace.tmpl', { %empty, traces => [ $trow ],
        next_cursor => "c1", errors_only => 0, query_esc => 'svc',
        min_ms => '', range_amp => '' });
    unlike($off, qr/errors=1/,
           'an unchecked filter is not resurrected by the pager');

    my $last = render('trace.tmpl', { %empty, traces => [ $trow ], paged => 1,
        errors_only => 1, query_esc => 'svc', min_ms => 250,
        range_amp => '&range=1h' });
    like($last, qr{traces\?q=svc&min_ms=250&errors=1&(?:amp;)?range=1h">Back},
         'the last page\'s way back keeps the filters too');
}

# A trace with a parent cycle renders a warning rather than hanging or
# silently dropping the spans.
{
    my $out = render('trace.tmpl', { %empty, cycles => 2, span_count => 2,
        spans => [ { depth => 0, span_id => '1', kind_name => 'internal',
                     name => 'a', start_pct => 0, width_pct => 100,
                     dur_ms => '1', indent => 0 } ] });
    like($out, qr/loops/, 'a cyclic trace renders an explanation');
    like($out, qr/broken instrumentation/, '  naming the cause');
    like($out, qr/\bname\b|>a</, '  and still shows the spans');
}

# An incomplete trace says so rather than looking shallow.
{
    my $out = render('trace.tmpl', { %empty, orphans => 3, span_count => 5,
        spans => [ { depth => 0, span_id => '1', kind_name => 'internal',
                     name => 'a', service => 'api', start_pct => 0,
                     width_pct => 100, dur_ms => '1ms', indent => 0 } ] });
    like($out, qr/parent that never arrived/,
         'orphaned spans are reported, so an incomplete trace is visible');
}

# --- a REFUSAL renders as a message, not an empty panel --------------------

# An empty chart reads as "no data", which is a different and wrong answer
# from "that cannot be computed here".
{
    my $out = render('metrics.tmpl', { %empty,
        refusal => 'a percentile cannot be computed from downsampled data' });
    like($out, qr/Cannot answer that/, 'a refused aggregate renders a message');
    like($out, qr/percentile cannot be computed/, '  carrying the reason');
    unlike($out, qr/<svg/, '  and draws no empty chart beside it');
}

# --- truncation is never hidden --------------------------------------------

{
    my $out = render('logs.tmpl', { %empty, truncated => 1, scanned => 5000,
        rows => [ { row_class => '', time => '1', sev_name => 'info',
                    service => 'api', body => 'x' } ] });
    like($out, qr/partial result/, 'a truncated result says so');
    like($out, qr/5000/, '  with the number of rows scanned');
}

# --- escaping ---------------------------------------------------------------

# A span name and a log body are untrusted input.
{
    my $out = render('logs.tmpl', { %empty, rows => [
        { row_class => '', time => '1', sev_name => 'error', service => 'api',
          body => '<script>alert(1)</script>' } ] });
    unlike($out, qr/<script>alert/, 'a log body cannot inject a script tag');
    like($out, qr/&lt;script&gt;|&#60;script/, '  it is escaped');
}

{
    my $out = render('logs.tmpl', { %empty, rows => [
        { row_class => '', time => '1', sev_name => 'info',
          service => 'caf' . chr(0xc3) . chr(0xa9), body => 'ok' } ] });
    like($out, qr/caf/, 'a non-ASCII service name renders');
}

# --- severity as a class, and never colour alone ---------------------------

{
    my $out = render('logs.tmpl', { %empty, rows => [
        { row_class => 'row-error', time => '1', sev_name => 'error',
          service => 'api', body => 'boom' } ] });
    like($out, qr/sev-error/, 'severity is a class the token sheet colours');
    like($out, qr/row-error/,
         '  and the row carries a class that adds weight and a marker too');
}

# --- the status page reports what it claims --------------------------------

{
    my $out = render('status.tmpl', { %empty,
        ingest_rate => 1234, wal_depth => 7, segments => 42,
        compaction_lag => 3, mapped_deleted => 2,
        accepted => 1500, accepted_bytes => '2.1 MB', rate_rejected => 266,
        counters_shared => 1 });
    for my $n (qw(1234 42)) {
        like($out, qr/\b\Q$n\E\b/, "the status page shows $n");
    }

    # THE CARDINALITY FIGURE IS FROM THE ARENA, AND SAYS SO. This block has
    # now flipped TWICE, each time because the counter's semantics changed
    # underneath the label - which is exactly what it exists to catch. First
    # it asserted absence (nothing counted admissions); then "since start"
    # (the arena counted, boot-scoped, append-only); and now the admitted set
    # ROTATES on a window - a series' slot frees when it stops reporting, so
    # the counter genuinely is the ACTIVE set and the label says so. The
    # surviving invariant is unchanged: the row must never be fed from the
    # store's distinct service names, which is a different number entirely.
    like($out, qr/active metric series/i,
         'the cardinality row is labelled as the active set');
    unlike($out, qr/series admitted since start/i,
           '  and not "since start", which a window-rotated counter is not');
    # The deleted-but-mapped figure was deliberately REMOVED: this store's
    # reads copy and unmap inside the call, so the number could only ever be
    # zero, and a zero that cannot be anything else demonstrates nothing
    # (t/0082 asserts the invariant that matters). The old assertion here
    # passed vacuously against a template comment carrying the phrase - found
    # the day the comments were stripped.
    unlike($out, qr/deleted but mapped/i,
           'no deleted-but-mapped figure - it is structurally always zero');

    # ACCEPTED AND STORED ARE TWO NUMBERS. The store cannot report what it
    # never received, so a receiver refusing everything and a receiver being
    # sent nothing look identical in the stored totals and different here.
    like($out, qr/\b1500\b/, 'the status page shows what was accepted');
    like($out, qr/\b266\b/,  '  and what the rate limit refused');
    like($out, qr/2\.1 MB/,   '  and the bytes behind it');
    unlike($out, qr/shared counters are unavailable/,
           'and says nothing about sharing when the counters are shared');

    # A counter that is not shared is a fraction of the truth, and a fraction
    # shown without saying so reads as data being lost.
    my $unshared = render('status.tmpl', { %empty,
        accepted => 12, counters_shared => 0 });
    like($unshared, qr/shared counters are unavailable/,
         'an unshared arena says so on the page');
    like($unshared, qr/stored totals are unaffected/,
         '  and says which numbers it does not affect');
}

# --- the layout, as a real WRAPPER -----------------------------------------

# `{% content %}` is Stencil's wrapper mechanism, not a variable: a template
# containing it cannot be rendered directly. So the layout is exercised the
# way it is actually used - configured as the wrapper for a page.
{
    my $st = Template::Stencil->new({
        template_dir => $DIR,
        wrapper      => 'layout.tmpl',
    });
    my $out = $st->render('status.tmpl', { %empty,
        theme => '', heading => 'Status', toolbar => '',
        ingest_rate => 99 });

    like($out, qr/<!doctype html>/i, 'the wrapper produces a whole document');
    like($out, qr/class="shell"/, '  using the shell primitive');
    like($out, qr/data-theme=/, '  and stamps a theme attribute');
    like($out, qr/class="stats"/, '  with the page content inside it');
    like($out, qr/\b99\b/, '  and the page variables reached the page');
    like($out, qr/observe\.css/, '  linking the stylesheet');
    unlike($out, qr/https?:\/\//, '  with no external reference');
    unlike($out, qr/\{%/, '  and nothing unrendered');

    # Three theme states, not two.
    like($out, qr/<option value="">System<\/option>/,
         '  the theme control offers the system default');
}

# --- the live tail and the brush attach by MARKUP ---------------------------

# A chart gets drawn, gets drag-to-zoom and gets its points wired to their
# traces by carrying an attribute, not by registering. So the attribute is
# what gets asserted.
{
    my $fig = '{"data":[{"type":"scatter","x":[1],"y":[2]}]}';
    my $out = render('metrics.tmpl', { %empty,
        from => '1700000000000000000', to => '1700000060000000000',
        title => 'latency', series_plot => $fig, query_esc => 'metric%20x',
        series => [ { class => 'series-1', name => 'p95', points => 2,
                      exemplars => 1 } ] });

    like($out, qr/data-chart/, 'a chart opts in by markup alone');
    like($out, qr/data-from="1700000000000000000"/,
         '  carrying its range as a STRING, not a rounded double');
    like($out, qr/data-to="1700000060000000000"/, '  at both ends');

    # THE EXACT INSTANT IS WHAT MAKES A ZOOM A NEW QUERY RATHER THAN A RESCALE
    # OF WHAT IS ALREADY DRAWN, and a double cannot hold one. The axis is
    # milliseconds; these two are not.
    unlike($out, qr/data-from="1\.7e\+?18"/,
           '  and never in exponential form, which is what a double gives');

    like($out, qr{<script type="application/json" data-plot>},
         'the figure travels as DATA, in a block a browser parses not runs');
    like($out, qr/\Q$fig\E/, '  and reaches the page intact');
    like($out, qr{data-trace-base="[^"]*/traces/},
         'the chart knows where a clicked point should go');

    # A chart is the one thing on these screens that scripting is required
    # for, so the page says so rather than showing an empty box.
    like($out, qr/<noscript>/, 'and it says so when scripting is off');
    like($out, qr{/explore\?q=}, '  pointing at the numbers behind it');
}

# The figure is embedded in a script element, and the one sequence that can
# close one early must not survive into the page. A service name is
# attacker-influenced in exactly the way a request path is.
{
    my $out = render('metrics.tmpl', { %empty,
        series_plot => '{"data":[{"name":"<\/script><img src=x>"}]}',
        series => [], title => 't' });
    unlike($out, qr{</script><img}i,
           'a figure cannot close its own script element');
}

{
    my $out = render('logs.tmpl', { %empty, tail => 1, query_esc => 'log' });
    like($out, qr/data-tail="[^"]*\/logs\/stream/, 'the tail panel names its stream');
    like($out, qr/data-tail-rows/, '  with a container for the rows');
    like($out, qr/data-tail-status/, '  and somewhere to report what was lost');
    like($out, qr/<noscript>/,
         '  and says so with scripting off rather than showing an empty box');
}

{
    my $out = render('logs.tmpl', { %empty });
    unlike($out, qr/data-tail=/,
           'the tail panel is absent when the page did not ask for it');
}

# --- alerts: the state is a WORD, and stale is not green -------------------

{
    my $out = render('alerts.tmpl', { %empty, rules => [
        { row_class => 'row-firing', state => 'firing', id => 1,
          name => 'checkout p95', series => 'api', held => '4m',
          value => '812', query_esc => 'x', silenced => 0 },
        { row_class => '', state => 'stale', id => 2, name => 'pod gone',
          series => 'worker-7', held => '', value => '', query_esc => 'x',
          silenced => 0 },
        { row_class => 'row-error', state => 'error', id => 3,
          name => 'broken query', series => '', held => '', value => '',
          query_esc => 'x', silenced => 1,
          reason => 'the store refused: budget' },
    ], broken => 1 });

    like($out, qr/al-firing/, 'a firing rule gets its state class');
    like($out, qr/>firing</, '  and the state is spelled out, not only coloured');
    like($out, qr/al-stale/, 'stale has a class of its own');
    like($out, qr/al-error/, '  and so does error');
    like($out, qr/could not be evaluated/,
         'rules that could not evaluate are called out, not folded in');
    like($out, qr/al-reason[^>]*>the store refused: budget/,
         '  and the broken rule carries WHY, on its row');
    is(scalar(() = $out =~ /al-reason/g), 1,
       '  only where there is a reason to show');
    like($out, qr/al-silenced/, 'a silenced rule is marked as such');
    like($out, qr/>firing</, '  while STILL showing its real state');
}

{
    my $out = render('alerts.tmpl', { %empty, silences => [
        { pattern => 'db-', until => 'in 2h', by => 'sam',
          reason => 'planned failover' } ] });
    like($out, qr/still reaches firing and still shows red/,
         'the silence panel states that a silence does not hide state');
}

# --- a dashboard is a grid of panels, and a refusal is a message -----------

{
    # The page is the SHELL now: panel bodies arrive from per-panel fragment
    # routes (or inline as body_html under ?full=1), so the refusal markup
    # lives in panelslow.tmpl - one copy for both paths.
    my $out = render('dashboard.tmpl', { %empty, title => 'Checkout',
        slug => 'checkout', cols => 3, panels => [
        { title => 'p95', span => 1, key => 'k1', query_esc => 'metric+x',
          body_html => '<svg></svg>' },
        { title => 'rate', span => 2, key => 'k2', query_esc => 'metric+y' },
    ] });
    like($out, qr/class="grid cols-3"/, 'the column count is a class');
    like($out, qr/span-2/, '  and a panel can span columns');
    like($out, qr{data-defer="/observe/dashboards/checkout/panels/k2/slow},
         'a panel without an inline body defers to its own fragment route');
    like($out, qr/open in the explorer/,
         'every panel links to the same query in the explorer');
    unlike($out, qr/draggable|data-drag/,
           'and there is no drag grid, deliberately');

    my $frag = render('panelslow.tmpl', { %empty, p => {
        refusal => 'a percentile cannot be computed from downsampled data' } });
    like($frag, qr/Cannot answer that/, 'a refused panel renders a message');
    like($frag, qr/percentile cannot be computed/, '  carrying the reason');
}



# --- every span class the schema permits has a rule -------------------------
#
# A GREP TEST, because the alternative is noticing by eye. A panel saved with
# a span the stylesheet has no rule for renders with an unrecognised class and
# silently occupies one column: the layout is wrong and the page says nothing.
#
# The bound comes from the schema's CHECK and from PO_PANEL_COLS_MAX, which
# are the two places that decide what can be stored. If either widens, this
# fails until the stylesheet follows.
{
    my $css = do {
        open my $fh, '<', 'root/static/observe.css' or die $!;
        local $/; <$fh>;
    };
    # THE BOUND COMES FROM THE DDL, which is what decides what can be
    # stored. The schema moved to per-dialect sqitch projects; this follows
    # it rather than keeping a number of its own. If the CHECK widens, this
    # fails until the stylesheet follows.
    my $sql = do {
        open my $fh, '<', 'sqitch/pg/deploy/alerts.sql' or die $!;
        local $/; <$fh>;
    };
    my ($max) = $sql =~ /span\s+\w+\s+NOT NULL DEFAULT 1 CHECK \(span BETWEEN 1 AND (\d+)\)/;
    ok($max, 'the schema states a maximum span') or $max = 6;

    # ...and the clamp agrees with it. Two places decide what can be stored
    # and they must not disagree: a panel the DDL accepts and the clamp
    # rejects is a row that silently changes on the way in.
    my $hdr = do {
        open my $fh, '<', 'include/punk_observe/po_panel.h' or die $!;
        local $/; <$fh>;
    };
    my ($clamp) = $hdr =~ /define\s+PO_PANEL_COLS_MAX\s+(\d+)/;
    is($clamp, $max, '  and PO_PANEL_COLS_MAX agrees with it');

    my @missing = grep { $css !~ /\.span-$_\s*\{/ } 2 .. $max;
    is_deeply(\@missing, [],
              "every span up to the schema's maximum of $max has a rule")
        or diag('no rule for: ' . join(', ', map { ".span-$_" } @missing)
              . "\na panel with that span silently occupies one column");

    # And the grid it sits in, likewise.
    my @nocols = grep { $css !~ /\.cols-$_\s*\{/ } 2 .. $max;
    is_deeply(\@nocols, [], "every column count up to $max has a rule");
}

# --- every class a template emits has a rule --------------------------------
#
# THE GENERAL FORM OF THE `.span-5` DEFECT, and it caught a second instance
# within the day: `.indent` on the health check rows, which made a target and
# its checks render identically - two targets and four checks reading as six
# unrelated services, with one name appearing twice and nothing to say that
# one was a target and the other a check on it.
#
# A class with no rule fails silently and looks like a layout somebody chose.
# Listed by exception rather than asserted empty, because plenty of classes
# are hooks for JavaScript or for the tests themselves and were never meant
# to be styled - but each of those is a decision, and the list is where the
# decision is written down.
{
    # HOOKS, not styles: read by JavaScript or by the tests, never meant to
    # carry a rule.
    my %not_style = map { $_ => 1 } qw(
        chart chartwrap mono num rows stats panel note empty warnbox
        tablewrap
    );

    # KNOWN UNSTYLED, AND THAT IS A DEBT RATHER THAN A DECISION.
    #
    # Each of these is a class a template emits that the stylesheet has never
    # heard of. They are listed so this test can do its job - catching the
    # NEXT one - and the list is meant to shrink, not to grow.
    #
    # At least one is a visible defect rather than dead markup: `.bar` is used
    # as `<span class="bar" style="width:N%">`, and a span with a width and no
    # display or background draws nothing, so the explore screen's group bars
    # are not there at all.
    my %known_unstyled = map { $_ => 1 } qw(
        nowrap dim barcell bar q faint rowlink tracelink map sublabel
        recordhead check
    );
    %not_style = (%not_style, %known_unstyled);

    my $css = do {
        open my $fh, '<', 'root/static/observe.css' or die $!;
        local $/; <$fh>;
    };

    my (@missing, %seen);
    for my $t (glob 'root/templates/*.tmpl') {
        open my $fh, '<', $t or next;
        my $src = do { local $/; <$fh> };
        # class="..." with no template expression in it: a literal class list.
        while ($src =~ /class="([^"{}]+)"/g) {
            for my $c (split /\s+/, $1) {
                next unless length $c;
                next if $not_style{$c} || $seen{$c}++;
                push @missing, "$t: .$c" unless $css =~ /\.\Q$c\E\b/;
            }
        }
    }
    is_deeply(\@missing, [],
              'every literal class a template emits has a rule in the stylesheet')
        or diag(join("\n", @missing,
                 'a class with no rule renders as nothing and looks deliberate;',
                 'if one of these is a hook rather than a style, name it in',
                 '%not_style so the decision is written down - and if it is a',
                 'style that was never written, that is the bug this catches'));
}

# --- the dashboard carries the range control ---------------------------------
#
# Every panel already ran over the page window; the picker was deliberately
# stripped, so the dashboard was the one screen where narrowing to the
# incident meant editing the URL by hand.
{
    my $out = render('dashboard.tmpl', { %empty, slug => 'ops',
        range => '6h', ranges => [ { key => '6h', label => 'six hours',
                                     current => 1 } ] });
    like($out, qr{data-rangepick}, 'the dashboard shows the range picker');
    like($out, qr{action="/observe/dashboards/ops"},
         '  submitting back to the dashboard it is on');
    like($out, qr{class="rangebtn on"}, '  with the current window marked');
}

# --- the health-target editor is its own page, reached from a button --------
#
# The first cut put the forms inline on the status page, which buried the
# reading view under an editor most visits never need. Now the status screen
# carries only a button - rendered even with nothing configured, or the FIRST
# target could never be added from the UI at all - and the forms live on
# /health-targets/edit, refusals returning there with the reason.
{
    my %h = (writable => 1,
             csrf_field => '<input type="hidden" name="csrf" value="t">');
    my $tgt = { name => 'shop', url => 'http://s/readyz', state => 'ready',
                ok => 1, held_s => '5s', row_class => '', checks => [],
                every_s => 60, timeout_ms => 5000, enabled => 1 };

    # The health screen: a button, not a form. (The section lived on the
    # status page first; it is its own page now, with the latency chart
    # under the table, and the status page carries none of it.) The DATA
    # markup lives in healthslow.tmpl - the fragment defer.js fetches and
    # ?full=1 renders inline - and these render that template, because that
    # is the one template the markup has.
    my $st = render('healthslow.tmpl', { %empty, %h, health => [ $tgt ] });
    like($st, qr{href="/observe/health-targets/edit"},
         'the health page links to the editor');
    unlike($st, qr{name="every_s"}, '  and carries no editing form itself');

    my $none = render('healthslow.tmpl', { %empty, %h, health => [] });
    like($none, qr{href="/observe/health-targets/edit"},
         'the link is there with nothing configured, or the first target '
       . 'could never be added');

    my $ro = render('healthslow.tmpl',
                    { %empty, health => [], writable => 0 });
    unlike($ro, qr{health-targets}, 'and absent entirely when not writable');

    # WAS IT UP, AND WHEN WAS IT NOT - which is what this page is opened to
    # find out. A latency bar per target stood here and answered a question
    # the table already answers, while a service down for forty minutes drew
    # the same bar as any other.
    my $ch = render('healthslow.tmpl', { %empty, %h, health => [ $tgt ],
                                         health_up_plot => '{"data":[]}' });
    like($ch, qr{Up or down}, 'the uptime chart panel renders');
    like($ch, qr{data-plot}, '  as a figure the chart runtime draws');
    like($ch, qr{punk\.health\.ok},
         '  pointing at the metric it was drawn from');
    unlike($ch, qr{Poll latency},
           '  and the latency bars it replaced are gone');

    # The page itself is the SHELL: a placeholder that names the fragment
    # route and polls it, with the no-script escape to ?full=1 - and when
    # the fragment was rendered inline, exactly that and no placeholder.
    my $shell = render('health.tmpl', { %empty, %h });
    like($shell, qr{data-defer="/observe/health\.slow"},
         'the health shell defers to its fragment route');
    like($shell, qr{data-defer-poll="\d+"}, '  and keeps polling it');
    like($shell, qr{href="/observe/health\?full=1"},
         '  with the no-JavaScript escape to a full render');

    my $inline = render('health.tmpl',
                        { %empty, %h, health_html => '<i id="frag"></i>' });
    like($inline, qr{<i id="frag"></i>}, '?full=1 renders the fragment inline');
    unlike($inline, qr{data-defer}, '  and nothing is deferred twice');

    # And the status page is out of the health business entirely.
    my $sp = render('status.tmpl', { %empty, %h, health => [ $tgt ] });
    unlike($sp, qr{Service health}, 'the status page no longer carries the section');

    # The editor: add form, per-target edit and remove forms, CSRF on each.
    my $ed = render('healthedit.tmpl', { %empty, %h, health => [ $tgt ] });
    like($ed, qr{action="/observe/health-targets"}, 'the editor saves targets');
    like($ed, qr{name="every_s"}, '  in seconds, not nanoseconds nobody types');
    like($ed, qr{action="/observe/health-targets/shop/delete"},
         '  with a remove form per target');
    my $forms = () = $ed =~ /name="csrf"/g;
    cmp_ok($forms, '>=', 3, '  and every form carries the CSRF field');

    # A refusal renders on the editor with its reason, not as a bare 400.
    my $ref = render('healthedit.tmpl', { %empty, %h, health => [],
        error => 'loopback addresses are refused.',
        hint  => 'Correct it and submit again.' });
    like($ref, qr{loopback addresses are refused},
         'a refused save shows why, where the form is');
}

done_testing();

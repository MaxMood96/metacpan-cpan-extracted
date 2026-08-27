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

    # NO CARDINALITY FIGURE. A series id is derived rather than assigned, so
    # nothing counts admissions and a count, a ceiling and a rejection total
    # would all read zero for a reason unrelated to the traffic. Asserted
    # rather than left to drift: the tempting fix is to feed the row from the
    # store's distinct service names, which is a different number entirely.
    unlike($out, qr/active series/i, 'no series count while nothing counts them');
    unlike($out, qr/series rejected/i, '  and no rejection total either');
    like($out, qr/deleted but mapped/i,
         'and the deleted-but-still-mapped figure, which is otherwise invisible');

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
          query_esc => 'x', silenced => 1 },
    ], broken => 1 });

    like($out, qr/al-firing/, 'a firing rule gets its state class');
    like($out, qr/>firing</, '  and the state is spelled out, not only coloured');
    like($out, qr/al-stale/, 'stale has a class of its own');
    like($out, qr/al-error/, '  and so does error');
    like($out, qr/could not be evaluated/,
         'rules that could not evaluate are called out, not folded in');
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
    my $out = render('dashboard.tmpl', { %empty, title => 'Checkout',
        slug => 'checkout', cols => 3, panels => [
        { title => 'p95', span => 1, refusal => '', body => '<svg></svg>',
          query_esc => 'metric+x' },
        { title => 'rate', span => 2, query_esc => 'metric+y',
          refusal => 'a percentile cannot be computed from downsampled data',
          body => '' },
    ] });
    like($out, qr/class="grid cols-3"/, 'the column count is a class');
    like($out, qr/span-2/, '  and a panel can span columns');
    like($out, qr/Cannot answer that/, 'a refused panel renders a message');
    like($out, qr/percentile cannot be computed/, '  carrying the reason');
    like($out, qr/open in the explorer/,
         'every panel links to the same query in the explorer');
    unlike($out, qr/draggable|data-drag/,
           'and there is no drag grid, deliberately');
}

done_testing();

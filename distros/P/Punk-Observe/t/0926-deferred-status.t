#!perl
# The deferred overview: the shell ships at once, the heavy panels arrive as
# server-rendered fragments defer.js fetches and re-polls.
#
# The contract has three parts, each pinned here: the SHELL names its
# fragment route and the no-script escape and carries no chart of its own;
# the FRAGMENT is the one copy of the data markup, rendered without the
# layout; and the fragment ROUTE answers with exactly what inline rendering
# would have produced, uncached.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use Punk::Observe ();
use Punk::Observe::Store ();
use Punk::Observe::WAL ();
use Punk::Plugin::Observe ();

BEGIN {
    eval { require Template::Stencil; 1 }
        or plan skip_all => 'Template::Stencil is not installed';
}

my $P = 'Punk::Plugin::Observe';

my $stencil = Template::Stencil->new({
    template_dir => File::Spec->catdir('root', 'templates') });
sub render { my ($t, $v) = @_; return $stencil->render($t, $v) }

my %empty = (prefix => '/observe', writable => 0, range_qs => '',
             range_amp => '', ingest_plot => '', ingest_html => '',
             health => [], health_html => '', health_ms_plot => '',
             error => '', hint => '');

# --- the overview shell ------------------------------------------------------
{
    my $s = render('status.tmpl', { %empty,
        accepted => '0', ingest_rate => '0', logs => '0', spans => '0',
        metrics => '0', traces => '0', errors => '0', segments => '0',
        wal_depth => '0', compaction_lag => '0', rate_rejected => '0',
        accepted_bytes => '0', store_bytes => '0', series_used => '0',
        series_cap => '', series_rejected => '0', overflow_records => '0',
        orphan_index => '0', live_gaps => '0', series_dropping => 0,
        counters_shared => 1, services => [],
        series_gauge_plot => '', storage_gauge_plot => '' });

    like($s, qr{data-defer="/observe/status\.slow"},
         'the shell defers the arrival chart to its fragment route');
    like($s, qr{data-defer-poll="\d+"}, '  and keeps polling it');
    like($s, qr{href="/observe/status\?full=1"},
         '  with the no-JavaScript escape to a full render');
    unlike($s, qr{Logs and spans arriving.*data-plot}s,
           '  and ships no arrival figure of its own');
    like($s, qr{Logs and spans arriving},
         '  though the panel heading is there at once');

    # ?full=1: the fragment inline, the placeholder gone.
    my $full = render('status.tmpl', { %empty,
        accepted => '0', ingest_rate => '0', logs => '0', spans => '0',
        metrics => '0', traces => '0', errors => '0', segments => '0',
        wal_depth => '0', compaction_lag => '0', rate_rejected => '0',
        accepted_bytes => '0', store_bytes => '0', series_used => '0',
        series_cap => '', series_rejected => '0', overflow_records => '0',
        orphan_index => '0', live_gaps => '0', series_dropping => 0,
        counters_shared => 1, services => [],
        series_gauge_plot => '', storage_gauge_plot => '',
        ingest_html => '<i id="frag"></i>' });
    like($full, qr{<i id="frag"></i>}, '?full=1 renders the fragment inline');
    unlike($full, qr{data-defer}, '  and defers nothing');
}

# --- the fragment, without the layout ----------------------------------------
{
    my $f = render('statusslow.tmpl',
                   { %empty, ingest_plot => '{"data":[]}' });
    like($f, qr{data-chart}, 'the fragment carries the chart mount');
    like($f, qr{data-plot}, '  and the figure');
    unlike($f, qr{<nav|</html>}, '  and none of the page around it');

    my $none = render('statusslow.tmpl', { %empty });
    like($none, qr{Nothing arrived}, 'an empty window says so');
    unlike($none, qr{data-chart}, '  and mounts no chart over nothing');
}

# --- the fragment route ------------------------------------------------------
#
# A controller stub, because the contract under test is what _slow_panel
# renders and sets - not the router that gets it there (t/0905 covers the
# route's existence).
{
    package Fake::C;
    sub new    { return bless { h => {}, params => $_[1] || {} }, $_[0] }
    sub param  { return $_[0]{params}{ $_[1] } }
    sub header { $_[0]{h}{ $_[1] } = $_[2]; return $_[0] }
    sub status { $_[0]{status} = $_[1]; return $_[0] }
    sub html   { $_[0]{html} = $_[1]; return $_[0] }
    sub text   { $_[0]{text} = $_[1]; return $_[0] }
}

{
    my $dir   = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir, tenant => 'default');
    my $T0    = '1774224000000000000';
    Punk::Observe::WAL::append($store->wal_path, [ {
        kind => 2, t => $T0, body => 'a line', severity => 9, duration => 0,
        trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
        attrs => { 'service.name' => 'svc' } } ], 0, 0);

    my $st = {
        prefix   => '/observe',
        writable => 0,
        opts     => {},
        limits   => {},
        store    => $dir,
        tenant   => { fixed => 'default' },
        stores   => { default => $store },
        fragment => Template::Stencil->new({
            template_dir => File::Spec->catdir('root', 'templates') }),
    };

    my $c = Fake::C->new({ from => '1774223940000000000',
                           to   => '1774224060000000000' });
    $P->can('_slow_panel')->($st, $c, 'status');
    ok(defined $c->{html}, 'the status fragment route answers HTML');
    like($c->{html}, qr{data-plot}, '  carrying the arrival figure');
    unlike($c->{html}, qr{<nav|</html>}, '  with no layout around it');
    is($c->{h}{'Cache-Control'}, 'no-cache',
       '  and it is a moment, never cached');

    # Health with no configuration database: the empty state, honestly.
    my $c2 = Fake::C->new({});
    $P->can('_slow_panel')->($st, $c2, 'health');
    like($c2->{html}, qr{Nothing is being polled yet},
         'the health fragment with nothing watched says so');

    # --- the gate in _page, both ways ----------------------------------------
    #
    # The mutant that computes the figure inline regardless renders
    # data-plot into the default page; the one that never computes it
    # leaves ?full=1 with a placeholder. One page render each kills both.
    $st->{stencil} = Template::Stencil->new({
        template_dir => File::Spec->catdir('root', 'templates'),
        wrapper      => 'layout.tmpl' });

    my $page = Fake::C->new({});
    $P->can('_page')->($st, 'status', $page, {});
    like($page->{html}, qr{data-defer="/observe/status\.slow},
         'the rendered overview defers its chart');
    unlike($page->{html}, qr{Logs and spans arriving.{0,600}data-plot}s,
           '  and computed no figure for it');

    my $fullp = Fake::C->new({ full => 1,
                               from => '1774223940000000000',
                               to   => '1774224060000000000' });
    $P->can('_page')->($st, 'status', $fullp, {});
    unlike($fullp->{html}, qr{data-defer}, '?full=1 defers nothing');
    like($fullp->{html}, qr{Logs and spans arriving.{0,600}data-plot}s,
         '  because the figure is already on the page');

    # THE OVERRIDES NAME THE TEMPLATE, and the gate must read it from THERE:
    # $over merges at the end of _page, so reading $vars{template} inside the
    # status build saw 'status' for every status-family screen - the health
    # page's ?full=1 built the overview's arrival fragment, the health shell
    # stayed at "Loading", and the editor lost its rows.
    my $hfull = Fake::C->new({ full => 1 });
    $P->can('_page')->($st, 'status', $hfull,
                       { template => 'health', here_status => 0,
                         here_home => 0, here_health => 1 });
    unlike($hfull->{html}, qr{data-defer}, 'health ?full=1 defers nothing');
    like($hfull->{html}, qr{Nothing is being polled yet},
         '  the health fragment renders inline (no config db: empty state)');
    unlike($hfull->{html}, qr{Logs and spans arriving},
           '  and it is the health fragment, not the overview one');

    # --- exactly one nav item is current -------------------------------------
    #
    # /health reuses the 'status' build, whose own flags mark here_status
    # AND here_home - and an override that cleared only here_status left
    # both Overview and Health carrying aria-current. The page render is
    # the only place all the flags meet, so it is where this is pinned.
    sub currents {
        my ($html) = @_;
        return [ $html =~ m{<a href="[^"]*"\s+aria-current="page">([^<]+)</a>}g ];
    }

    my $hp = Fake::C->new({});
    $P->can('_page')->($st, 'status', $hp,
                       { template => 'health', heading => 'Health',
                         here_status => 0, here_home => 0,
                         here_health => 1 });
    is_deeply(currents($hp->{html}), ['Health'],
              'the health page marks Health current, and nothing else');

    my $op = Fake::C->new({});
    $P->can('_page')->($st, 'status', $op, {});
    is_deeply(currents($op->{html}), ['Overview'],
              'the overview marks Overview current, and nothing else');
}

done_testing();

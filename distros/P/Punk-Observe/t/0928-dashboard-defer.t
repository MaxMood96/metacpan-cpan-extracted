#!perl
# Deferred dashboard panels: the shell ships panel metadata and a
# placeholder each; every body - chart or table - arrives from its own
# fragment route, in parallel, and re-polls. ?full=1 renders the same
# fragment template inline; the editor renders forms and runs NO panel
# queries at all, where it used to run every one for nothing.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;

use Punk::Observe ();
use Punk::Observe::View ();

my $V = 'Punk::Observe::View';

# A store that counts its queries and answers a scripted shape.
{
    package Fake::Store;
    sub new {
        my ($class, %o) = @_;
        return bless { calls => [], shape => $o{shape} || 'rows' }, $class;
    }
    sub query {
        my ($self, $q, %opt) = @_;
        push @{ $self->{calls} }, { q => $q, %opt };
        return { ok => 1, shape => 'buckets',
                 series => [ { key => '', points => [ [ 1, 2 ] ] } ],
                 meta => { truncated => 0 } }
            if $self->{shape} eq 'buckets';
        return { ok => 1, shape => 'rows', rows => [
                 { t => '1000', service => 'svc', body => 'a line' } ],
                 meta => { truncated => 0 } };
    }
    sub records { return [] }
    sub stats   { return {} }
}

my $DASH = {
    title => 'Checkout', slug => 'checkout', cols => 2,
    panels => [
        { id => 7,  position => 0, title => 'chart', span => 1,
          query => 'log | bucket(1m) count', viz => 'line' },
        { id => 12, position => 1, title => 'lines', span => 1,
          query => 'log | limit 50', viz => 'table' },
    ],
};

# --- the shell runs no queries -----------------------------------------------
{
    my $store = Fake::Store->new;
    my $v = $V->page($store, 'dashboard',
                     { slug => 'checkout', dashboards => $DASH });

    is(scalar @{ $store->{calls} }, 0,
       'the shell render runs NO panel queries');
    is(scalar @{ $v->{panels} }, 2, '  and still lists every panel');
    is($v->{panels}[0]{title}, 'chart', '  with its title');
    is($v->{panels}[0]{key}, 7, '  keyed by its id for the fragment URL');
    ok(!$v->{panels}[0]{series_plot} && !$v->{panels}[1]{rows},
       '  and no body vars at all');
    is($v->{slug}, 'checkout', 'the resolved slug is on the page');
}

# --- ?full=1 pays with the page ----------------------------------------------
{
    my $store = Fake::Store->new(shape => 'buckets');
    my $v = $V->page($store, 'dashboard',
                     { slug => 'checkout', panels_inline => 1,
                       dashboards => $DASH });
    is(scalar @{ $store->{calls} }, 2, 'panels_inline runs every query');
    ok($v->{panels}[0]{series_plot} || $v->{panels}[0]{bucket_rows},
       '  and builds the bodies');
}

# --- the editor never pays ---------------------------------------------------
#
# It renders forms; it used to run check_panel and a full store query per
# panel for vars its template never reads.
{
    my $store = Fake::Store->new;
    my $v = $V->page($store, 'dashboard',
                     { slug => 'checkout', dashboards => $DASH });
    is(scalar @{ $store->{calls} }, 0, 'the editor build runs no queries');
    is($v->{panels}[1]{query}, 'log | limit 50',
       '  and still carries the raw query its forms need');
    is($v->{panels}[1]{viz}, 'table', '  and the chart kind');
}

# --- one panel, by key -------------------------------------------------------
{
    my $store = Fake::Store->new;
    my $p = $V->_panel($store,
                       { slug => 'checkout', panel => '12',
                         dashboards => $DASH });
    is(ref $p, 'HASH', 'the fragment builder finds a panel by id');
    is($p->{title}, 'lines', '  the right one');
    is(scalar @{ $store->{calls} }, 1, '  running exactly its query');
    ok($p->{rows} && @{ $p->{rows} }, '  and building its body - a table');
    is($p->{rows}[0]{body}, 'a line', '  with the row in it');

    my $none = $V->_panel($store,
                          { slug => 'checkout', panel => '99',
                            dashboards => $DASH });
    ok(!defined $none, 'a key naming no panel answers undef - the 404');
}

# --- seam panels without ids get index keys ----------------------------------
#
# A host-supplied reader owes nobody an id column; the shell keys such
# panels by their position in the SORTED list, and the fragment route
# resolves the same way - so the two agree by construction.
{
    my $seam = { title => 'S', panels => [
        { position => 1, title => 'second', query => 'log | count' },
        { position => 0, title => 'first',  query => 'log | count' },
    ] };
    my $store = Fake::Store->new;
    my $v = $V->page($store, 'dashboard', { dashboards => $seam });
    is_deeply([ map { $_->{key} } @{ $v->{panels} } ], [ 'i0', 'i1' ],
              'id-less panels are keyed by sorted index');
    is($v->{panels}[0]{title}, 'first', '  in position order');

    my $p = $V->_panel($store, { panel => 'i1', dashboards => $seam });
    is($p && $p->{title}, 'second', 'the index key lands on the same panel');
}

# --- a refusal is a body too -------------------------------------------------
{
    my $store = Fake::Store->new;
    my $p = $V->_panel($store,
                       { slug => 'checkout', panel => 'i0',
                         dashboards => { title => 'X', panels => [
                             { title => 'bad', query => 'log | wibble' } ] } });
    ok($p && $p->{refusal}, 'an invalid query becomes the panel refusal');
    like($p->{refusal}, qr/\S/, '  with words in it');
    is(scalar @{ $store->{calls} }, 0, '  and no query was run');
}

# --- the plugin: shell, ?full=1, the fragment route, and Plotly --------------
SKIP: {
    eval { require Template::Stencil; 1 }
        or skip 'Template::Stencil is not installed', 10;
    require File::Temp;
    require File::Spec;
    require Punk::Observe::Store;
    require Punk::Plugin::Observe;

    package Fake::C;
    sub new    { return bless { h => {}, params => $_[1] || {} }, $_[0] }
    sub param  { return $_[0]{params}{ $_[1] } }
    sub header { $_[0]{h}{ $_[1] } = $_[2]; return $_[0] }
    sub status { $_[0]{status} = $_[1]; return $_[0] }
    sub html   { $_[0]{html} = $_[1]; return $_[0] }
    sub text   { $_[0]{text} = $_[1]; return $_[0] }
    package main;

    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $td  = File::Spec->catdir('root', 'templates');

    # One fresh record, or the table panel's inline body is legitimately
    # empty and asserts nothing.
    {
        require Punk::Observe::WAL;
        my $s = Punk::Observe::Store->new(dir => $dir, tenant => 'default');
        Punk::Observe::WAL::append($s->wal_path, [ {
            kind => 2, t => Punk::Observe::now_ns(), body => 'a fresh line',
            severity => 9, duration => 0, trace_hi => 0, trace_lo => 0,
            span_id => 0, parent_id => 0,
            attrs => { 'service.name' => 'svc' } } ], 0, 0);
    }
    my $st = {
        prefix   => '/observe',
        writable => 0,
        opts     => {},
        limits   => {},
        store    => $dir,
        tenant   => { fixed => 'default' },
        stores   => {},
        seam     => { dashboards => { read => sub { return $DASH } } },
        stencil  => Template::Stencil->new({ template_dir => $td,
                                             wrapper => 'layout.tmpl' }),
        fragment => Template::Stencil->new({ template_dir => $td }),
    };
    my $P = 'Punk::Plugin::Observe';

    my $shell = Fake::C->new({ slug => 'checkout' });
    $P->can('_page')->($st, 'dashboard', $shell, {});
    like($shell->{html},
         qr{data-defer="/observe/dashboards/checkout/panels/7/slow},
         'the rendered shell defers each panel to its route');
    unlike($shell->{html}, qr{data-plot}, '  and carries no figure');
    like($shell->{html}, qr{plotly\.min\.js},
         '  but still loads the chart runtime - a figure is coming');

    my $full = Fake::C->new({ slug => 'checkout', full => 1 });
    $P->can('_page')->($st, 'dashboard', $full, {});
    unlike($full->{html}, qr{data-defer}, '?full=1 defers nothing');
    like($full->{html}, qr{class="tablewrap"},
         '  and the table panel body is inline');

    my $edit = Fake::C->new({ slug => 'checkout' });
    $P->can('_page')->($st, 'dashboard', $edit,
                       { template => 'dashedit', editing => 1 });
    unlike($edit->{html}, qr{data-defer},
           'the editor defers nothing - it renders forms');

    my $frag = Fake::C->new({ slug => 'checkout', key => '12' });
    $P->can('_dash_panel')->($st, $frag);
    ok(defined $frag->{html}, 'the fragment route answers HTML');
    unlike($frag->{html}, qr{<nav|</html>}, '  with no layout around it');
    is($frag->{h}{'Cache-Control'}, 'no-cache', '  uncached');

    my $gone = Fake::C->new({ slug => 'checkout', key => '99' });
    $P->can('_dash_panel')->($st, $gone);
    is($gone->{status}, 404, 'a deleted panel is a 404, not a broken page');

    # --- a name that renders as itself is a failure, never a body ------------
    #
    # Stencil's contract: a template argument that fails to RESOLVE to a
    # file is treated as template SOURCE - so one transient open failure
    # turned the fragment into a 200 whose entire body was the fourteen
    # bytes "panelslow.tmpl", intermittently, under the 30-second poll.
    # The seam treats an answer of exactly the name as the resolution
    # failure it is.
    {
        package Name::Echo;
        sub new    { return bless {}, shift }
        sub render { return $_[1] }
    }
    local $st->{fragment} = Name::Echo->new;
    my $echo = Fake::C->new({ slug => 'checkout', key => '12' });
    $P->can('_dash_panel')->($st, $echo);
    is($echo->{status}, 500,
       'a render answering the template name is a 500, not a body');
    isnt($echo->{html} // '', 'panelslow.tmpl',
         '  and the name never reaches the page');

    local $st->{stencil} = Name::Echo->new;
    my $page5 = Fake::C->new({ slug => 'checkout' });
    $P->can('_page')->($st, 'dashboard', $page5, {});
    is($page5->{status}, 500, 'the page render gets the same guard');
    like($page5->{text}, qr/did not resolve/, '  saying what happened');
}

done_testing();

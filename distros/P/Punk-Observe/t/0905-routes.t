#!perl
# The route table, and the assertion that keeps it honest: EVERY PATH THE UI
# EMITS IS A ROUTE THAT EXISTS.
#
# The nav linked /explore and the metrics chart linked /traces/:id for two
# phases while neither route was registered, and the layout linked a favicon
# nothing served. None of that fails a render test - the markup is perfectly
# valid - and none of it fails a unit test either, because the two halves were
# never compared. This file compares them.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

BEGIN {
    eval { require Punk::Plugin::Observe; 1 }
        or plan skip_all => 'Punk::Plugin::Observe not loadable';
}

# A stand-in for the application, recording what was registered rather than
# routing anything. The plugin asks `can('under')` and `can('mount')`, so this
# has to answer both.
{
    package T::App;
    sub new { bless { routes => [], mounts => [], scopes => [] }, shift }
    sub under {
        my ($self, $prefix, $guard) = @_;
        push @{ $self->{scopes} }, { prefix => $prefix, guard => $guard };
        return T::Scope->new($self, $prefix);
    }
    sub mount {
        my ($self, $prefix, $app) = @_;
        push @{ $self->{mounts} }, $prefix;
        return $app;
    }

    package T::Scope;
    sub new { my ($c, $app, $p) = @_; bless { app => $app, prefix => $p }, $c }
    sub get {
        my ($self, $path, $cb) = @_;
        push @{ $self->{app}{routes} }, { method => 'GET', path => $path,
                                          cb => $cb };
        return $self;
    }
    # THE WRITE ROUTES ARE ROUTES TOO. This stand-in had no `post`, so every
    # path a form posts to was outside the inventory below - and the plugin
    # only registers them when editing is on, so the omission was invisible.
    sub post {
        my ($self, $path, $cb) = @_;
        push @{ $self->{app}{routes} }, { method => 'POST', path => $path,
                                          cb => $cb };
        return $self;
    }
}

my $P = 'Punk::Plugin::Observe';

my $app = T::App->new;

# EDITING ON, so the write routes are registered and therefore checked. The
# plugin decides that from the application having CSRF and somewhere to write;
# both are faked here, because what is under test is the route table.
$app->{csrf} = { field => '_csrf' };

my $st  = $P->register($app, {
    guard  => sub { return },
    prefix => '/observe',
    store  => undef,
    ingest => { prefix => '/v1' },
    dashboards => { read => sub { {} }, write => sub { { ok => 1 } } },
});

# --- the scope, not a mount --------------------------------------------------

is(scalar @{ $app->{scopes} }, 1, 'the UI registers ONE guarded scope');
is($app->{scopes}[0]{prefix}, '/observe', '  at the configured prefix');
ok($app->{scopes}[0]{guard}, '  with the guard attached to the scope itself');

# A guard on the scope covers routes added later. A mount plus a guard per
# route is the same thing right up until somebody forgets one, and the failure
# mode of forgetting is an unauthenticated page.
is(scalar @{ $app->{mounts} }, 1, 'and the ingest prefix is mounted separately');
is($app->{mounts}[0], '/v1', '  outside the guarded scope, on purpose');

my %route = map { $_->{path} => 1 } @{ $app->{routes} };

# --- every screen the nav offers ---------------------------------------------

for my $p (qw(/ /status /logs /metrics /map /traces /explore /alerts)) {
    ok($route{$p}, "the screen $p is routed");
}

# And every form the templates post to answers a POST, not only a GET. A
# write path that resolves to a read route is a 405 nobody sees until they
# press the button.
{
    my %post = map { $_->{path} => 1 }
               grep { $_->{method} eq 'POST' } @{ $app->{routes} };
    ok(scalar keys %post, 'the write routes are registered when editing is on');
    ok($post{'/views'}, '  including saving a view');
    ok($post{'/dashboards'}, '  and creating a dashboard');
}

# --- every detail screen a row links to --------------------------------------

ok($route{'/logs/:id'},      'a log row has somewhere to go');
ok($route{'/traces/:trace'}, 'a trace id has somewhere to go');
ok($route{'/logs/stream'},   'the live tail has a server');

# ORDER MATTERS HERE. A literal path and a capture that both match are decided
# by which was registered first, so /logs/stream registered after /logs/:id is
# a record lookup for a record called "stream".
{
    my @logs = grep { $_->{path} =~ m{^/logs/} } @{ $app->{routes} };
    is($logs[0]{path}, '/logs/stream',
       'the literal /logs/stream is registered BEFORE the :id capture');
}

# --- every asset the layout references ---------------------------------------

for my $a (qw(observe.css brush.js waterfall.js flamegraph.js livetail.js
              favicon.svg)) {
    ok($route{"/assets/$a"}, "the asset $a is served");
}

# --- and now the comparison the whole file exists for ------------------------

# Every path the templates emit, checked against the table above. A link the
# UI offers and the router does not answer is a 404 that only a person
# clicking finds.
{
    my $dir = 'root/templates';
    opendir(my $dh, $dir) or plan skip_all => "no templates: $!";
    my @tmpl = grep { /\.tmpl\z/ } readdir $dh;
    closedir $dh;

    my %want;
    for my $f (@tmpl) {
        open my $fh, '<', "$dir/$f" or next;
        local $/;
        my $src = <$fh>;
        close $fh;

        # Anything of the form {% prefix %}/... in an href, a src or a data
        # attribute. The variable part of a path is whatever follows, and a
        # path whose next segment is a variable is a capture.
        while ($src =~ m{\{%\s*prefix\s*%\}(/[A-Za-z0-9_./-]*)}g) {
            my $path = $1;
            $path =~ s{/\z}{} unless $path eq '/';
            $want{$path} ||= $f;
        }
    }

    ok(scalar keys %want, 'the templates emit paths to check');

    my @missing;
    for my $p (sort keys %want) {
        next if $route{$p};
        # A path with a captured segment: /logs/ABC matches /logs/:id.
        my $capture = $p;
        $capture =~ s{/[^/]+\z}{/:x};
        my $matched = 0;
        for my $r (keys %route) {
            (my $shape = $r) =~ s{/:[A-Za-z_]\w*\z}{/:x};
            $matched = 1, last if $shape eq $capture;
        }
        push @missing, "$p (from $want{$p})" unless $matched;
    }
    is_deeply(\@missing, [],
              'every path the templates link to is a route that exists')
        or diag "unrouted: @missing";
}

# --- the assets themselves exist ---------------------------------------------

# A route that serves a file that is not in the distribution is a 404 with a
# longer stack trace.
{
    my $root = $st->{root};
    ok($root, 'the plugin found its own root directory');
    for my $a (qw(observe.css brush.js waterfall.js flamegraph.js livetail.js)) {
        ok(-f "$root/static/$a", "  and $a is in it");
    }
    for my $t (qw(layout.tmpl status.tmpl logs.tmpl record.tmpl trace.tmpl
                  map.tmpl metrics.tmpl explore.tmpl alerts.tmpl)) {
        ok(-f "$root/templates/$t", "  and the template $t");
    }
}

done_testing();

#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require Catalyst::Seal::Construct;
require TestApp;
require SealTest;

my $app = TestApp->psgi_app;

ok(
    Catalyst::Controller->can('BUILD') == \&Catalyst::Seal::Construct::_controller_build,
    'Catalyst::Controller::BUILD is the memoised version',
) or plan skip_all => 'the construct step did not apply on this Catalyst';

# --------------------------------------------------- the context object's BUILD

# The application class inherits Catalyst::Controller, so the per-request
# context object runs a controller's BUILD. What it must end up with is what it
# ended up with before.
{
    is(
        (grep { $_ eq 'Catalyst::Controller' } @{ mro::get_linear_isa('TestApp') })[0],
        'Catalyst::Controller',
        'the application class really does inherit Catalyst::Controller',
    );

    my $c = TestApp->context_class->new({});
    is_deeply($c->{actions}, {}, 'a plain context object gets empty actions');
    is_deeply($c->{_all_actions_attributes}, {}, 'and empty action attributes');
    is_deeply($c->{_action_roles}, [], 'and no action roles');
}

# The containers must be fresh per instance. Sharing them would mean one
# request's writes showing up in the next, and _build__all_actions_attributes
# deletes a key from that hash as it goes.
{
    my $a = TestApp->context_class->new({});
    my $b = TestApp->context_class->new({});

    isnt(
        Scalar::Util::refaddr($a->{actions}),
        Scalar::Util::refaddr($b->{actions}),
        'two context objects do not share the actions hash',
    );
    isnt(
        Scalar::Util::refaddr($a->{_action_roles}),
        Scalar::Util::refaddr($b->{_action_roles}),
        'nor the action roles array',
    );

    $a->{actions}{probe} = 1;
    is_deeply($b->{actions}, {}, 'writing to one does not reach the other');
}

# A real controller, configured with actions, takes the stock body.
{
    my $ctrl = TestApp::Controller::Steps->COMPONENT('TestApp', {
        actions => { okay => { Path => '/steps/ok' } },
    });
    ok($ctrl, 'a controller with actions constructed');
    is_deeply(
        $ctrl->_controller_actions,
        { okay => { Path => '/steps/ok' } },
        'and kept its configured actions rather than being handed empties',
    );
}

# The memo only remembers the boring case.
cmp_ok(Catalyst::Seal::Construct::empty_classes(), '>=', 1,
    'at least one class was recorded as empty');

# ----------------------------------------------------------------- lazy stats

{
    ok(!TestApp->use_stats, 'stats are off for this application');
    ok($Catalyst::Seal::Construct::LAZY_STATS{ TestApp->context_class },
        'so the context class got a lazy stats reader');
}

# With stats off, prepare does not build one, and reading builds it once.
{
    my $c = TestApp->context_class->new({});
    ok(!exists $c->{stats}, 'no stats object until something asks');

    my $first = $c->stats;
    ok($first, 'reading builds one');
    isa_ok($first, 'Catalyst::Stats');
    ok(!$first->enable, 'and it is disabled, matching use_stats');

    is(
        Scalar::Util::refaddr($c->stats),
        Scalar::Util::refaddr($first),
        'a second read returns the same object',
    );
}

# Two contexts get their own. A shared one would accumulate for the life of the
# worker as soon as any request enabled it.
{
    my $a = TestApp->context_class->new({});
    my $b = TestApp->context_class->new({});
    isnt(
        Scalar::Util::refaddr($a->stats),
        Scalar::Util::refaddr($b->stats),
        'separate contexts do not share a stats object',
    );
}

# The writer still writes.
{
    my $c = TestApp->context_class->new({});
    my $mine = Catalyst::Stats->new;
    $c->stats($mine);
    is(Scalar::Util::refaddr($c->stats), Scalar::Util::refaddr($mine),
        'writing stats still works and wins over the builder');
}

# With stats ON the eager path is taken, unchanged. use_stats is a method
# Catalyst overrides per application, so this is a subclass rather than config.
{
    package TestApp::Stats;
    our @ISA = ('TestApp');
    sub use_stats { 1 }
}
{
    # context_class is inherited class data, so TestApp::Stats->context_class is
    # still TestApp. Construct the subclass directly to get an invocant whose
    # use_stats is true.
    ok(!$Catalyst::Seal::Construct::LAZY_STATS{'TestApp::Stats'},
        'a class that did not seal keeps the eager stats path in prepare');

    my $c = TestApp::Stats->new({});
    ok($c->use_stats, 'the subclass reports stats on');

    my $s = $c->stats;
    ok($s->enable, 'a stats object built through the inherited reader is enabled');
    ok($s->tree, 'with a tree, which is what the eager path is protecting');
}

# ------------------------------------------------------------- still serving

{
    my $res = SealTest::response($app);
    is($res->[0], 200, 'the application still answers');
    is(join('', @{ $res->[2] }), 'hello', 'with the right body');
}

done_testing;

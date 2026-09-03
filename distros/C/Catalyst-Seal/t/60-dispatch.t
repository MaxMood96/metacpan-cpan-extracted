#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
use Catalyst::Seal::Dispatch ();
require TestApp;
require SealTest;

my $app = TestApp->psgi_app;

sub body {
    my (%over) = @_;
    my $res = SealTest::response($app, %over);
    return join '', @{ $res->[2] || [] };
}

# The memos are installed, and the lookups they replaced are the ones we think.
ok(
    Catalyst::Dispatcher->can('_invoke_as_path')
        == \&Catalyst::Seal::Dispatch::_invoke_as_path,
    '_invoke_as_path is the memoised version',
) or plan skip_all => 'the dispatch step did not apply on this Catalyst';

ok(
    Catalyst::Dispatcher->can('get_actions')
        == \&Catalyst::Seal::Dispatch::_get_actions,
    'get_actions is the memoised version',
);

# ------------------------------------------------------------- chain order

# Root has begin and auto; Steps has begin, auto and end. get_actions takes the
# last begin in the container chain, so Steps' begin wins over Root's, while
# both autos run, root first.
is(
    body(PATH_INFO => '/steps/ok'),
    'steps-begin,root-auto,steps-auto,action,steps-end',
    'the chain runs begin, both autos, the action, then end',
);

# A false auto halts the remaining steps but end still runs. A flat chain that
# returns early here would skip end, and nothing that only checks the status
# would notice.
is(
    body(PATH_INFO => '/steps/halt'),
    'steps-begin,root-auto,steps-auto,steps-end',
    'a false auto skips the action and still runs end',
);

# ------------------------------------------------------- forward and friends

is(
    body(PATH_INFO => '/steps/forward'),
    'steps-begin,root-auto,steps-auto,action,target,after-forward,steps-end',
    'forward returns to the caller',
);

is(
    body(PATH_INFO => '/steps/detach'),
    'steps-begin,root-auto,steps-auto,action,target,steps-end',
    'detach does not return to the caller, and end still runs',
);

# visit re-runs the whole chain for the target, which is what makes it visit
# and not forward.
is(
    body(PATH_INFO => '/steps/visit'),
    'steps-begin,root-auto,steps-auto,action,steps-begin,root-auto,steps-auto,target,steps-end',
    'visit runs the target chain as well',
);

# --------------------------------------------------------- stack and depth

# The private steps are on the stack, and everything that reads it depends on
# them being there: depth gates the detach and go rethrows, and the uncaught
# error message names the class and method off the top of it. This is the
# assertion that says why the chain was not flattened.
is(
    body(PATH_INFO => '/steps/depth'),
    'steps-begin,root-auto,steps-auto,depth=3,stack=_DISPATCH|_ACTION|depth,steps-end',
    'the private chain steps are still on the stack at the action',
);

# ---------------------------------------------------------------- lookups

# Distinct paths get distinct entries, and a repeat is a hit rather than a
# second walk.
{
    Catalyst::Seal::Dispatch::_clear();
    my ($paths, $actions) = Catalyst::Seal::Dispatch::memo_sizes();
    is($paths, 0, 'the path memo starts empty');
    is($actions, 0, 'and so does the action memo');

    # /steps/forward, not /steps/ok: the private chain no longer goes through
    # forward at all now that its actions are pre-resolved, so the path memo is
    # only reached by an application calling forward, detach, go or visit.
    body(PATH_INFO => '/steps/forward');
    my ($p1, $a1) = Catalyst::Seal::Dispatch::memo_sizes();
    cmp_ok($p1, '>', 0, 'an application forward populates the path memo');
    cmp_ok($a1, '>', 0, 'and the action memo');

    body(PATH_INFO => '/steps/forward') for 1 .. 5;
    my ($p2, $a2) = Catalyst::Seal::Dispatch::memo_sizes();
    is($p2, $p1, 'repeating the same request adds no path entries');
    is($a2, $a1, 'and no action entries');
}

# A lookup that finds nothing is remembered as nothing, and does not become a
# false hit for a different path.
{
    is(body(PATH_INFO => '/no/such/thing'), 'not found', 'an unmatched path 404s');
    is(body(PATH_INFO => '/no/such/thing'), 'not found', 'and does so again from the memo');
    is(body(PATH_INFO => '/steps/ok'),
        'steps-begin,root-auto,steps-auto,action,steps-end',
        'a real path is unaffected by the negative entry');
}

# ------------------------------------------------------------------- cap

# The path memo is keyed on whatever was handed to forward, detach, go or
# visit. An application that forwards to caller supplied input turns that into
# an unbounded cache keyed on caller controlled strings, which is a memory leak
# stock Catalyst does not have. Past the cap the lookup still works and simply
# stops being remembered.
{
    local $Catalyst::Seal::Dispatch::MAX_KEYS = 8;
    Catalyst::Seal::Dispatch::_clear();

    # /steps/fwd forwards to ?to=, on purpose.
    body(PATH_INFO => '/steps/fwd', QUERY_STRING => "to=/no/such/$_") for 1 .. 200;

    my ($paths) = Catalyst::Seal::Dispatch::memo_sizes();
    cmp_ok($paths, '<=', 8, 'the path memo stopped growing at the cap')
        or diag "memo held $paths keys";
    cmp_ok(Catalyst::Seal::Dispatch::capped(), '>', 0, 'and said so');

    is(
        body(PATH_INFO => '/steps/ok'),
        'steps-begin,root-auto,steps-auto,action,steps-end',
        'dispatch is still correct past the cap',
    );
}
Catalyst::Seal::Dispatch::_clear();

# ------------------------------------------------------------ invalidation

# Registering an action after the seal clears both memos. Getting this wrong
# means dispatching to a stale action, which no amount of output comparison on
# the existing routes would reveal.
{
    body(PATH_INFO => '/steps/forward');
    my ($before) = Catalyst::Seal::Dispatch::memo_sizes();
    cmp_ok($before, '>', 0, 'the memo has entries to lose');

    my $action = Catalyst::Action->new(
        name       => 'late',
        code       => sub { 1 },
        reverse    => 'steps/late',
        class      => 'TestApp::Controller::Steps',
        namespace  => 'steps',
        attributes => { Private => [] },
    );
    TestApp->dispatcher->register('TestApp', $action);

    my ($after, $after_actions) = Catalyst::Seal::Dispatch::memo_sizes();
    is($after, 0, 'registering an action cleared the path memo');
    is($after_actions, 0, 'and the action memo');
}

# And the application still works afterwards.
is(
    body(PATH_INFO => '/steps/ok'),
    'steps-begin,root-auto,steps-auto,action,steps-end',
    'the chain still runs after an invalidation',
);

done_testing;

#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require TestApp;
require SealTest;

# CVE-2026-85491.
#
# A route decision is not a pure function of the request path.
# Catalyst::ActionRole::HTTPMethods, ConsumesContent, Scheme and QueryMatching
# each wrap match() with a test on request state that is not the path, so the
# same path can match one action, a different action, or none at all,
# depending on the method, the content type, the scheme or the query.
#
# Anything in this distribution that remembers a routing decision has to key
# on all of that or not remember it at all. These are the requests that say so.

my $app = TestApp->psgi_app;

sub body {
    my (%over) = @_;
    my $res = SealTest::response($app, %over);
    return $res->[0] . ' ' . join('', @{ $res->[2] || [] });
}

# ------------------------------------------- a failed match must not stick

# A GET of a POST-only path is a legitimate 404. It must not decide anything
# for the POST that follows: one unauthenticated GET would otherwise disable
# the endpoint for the life of the worker.
{
    is(body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'POST'),
        '200 post-only', 'the POST route works to begin with');

    my $get = body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'GET');
    isnt($get, '200 post-only', 'a GET of a POST-only path does not reach the action');

    is(body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'POST'),
        '200 post-only', 'and the POST still works after that GET');

    # Cold, in the other order: the GET first, before anything has matched.
    Catalyst::Seal::Dispatch::_clear_routes()
        if Catalyst::Seal::Dispatch->can('_clear_routes');
    body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'GET');
    is(body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'POST'),
        '200 post-only', 'and when the GET came first');

    # Repeatedly, because one poisoned entry is enough.
    body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'GET') for 1 .. 5;
    is(body(PATH_INFO => '/guard/post', REQUEST_METHOD => 'POST'),
        '200 post-only', 'and after five of them');
}

# --------------------------------- a match at the wrong level must not stick

# The GET descends past the POST-only /guard/thing/edit and lands on the
# any-method /guard/thing with 'edit' as an argument. That is correct for the
# GET. Replaying it for a POST would run a different action from the one the
# POST asked for, with whatever the deeper action's chain was guarding it
# never running.
{
    Catalyst::Seal::Dispatch::_clear_routes()
        if Catalyst::Seal::Dispatch->can('_clear_routes');

    is(body(PATH_INFO => '/guard/thing/edit', REQUEST_METHOD => 'POST'),
        '200 deep', 'the POST reaches the deep action');

    is(body(PATH_INFO => '/guard/thing/edit', REQUEST_METHOD => 'GET'),
        '200 shallow:edit', 'the GET descends to the shallow one');

    is(body(PATH_INFO => '/guard/thing/edit', REQUEST_METHOD => 'POST'),
        '200 deep', 'and the POST still reaches the deep action afterwards');

    # Cold, GET first.
    Catalyst::Seal::Dispatch::_clear_routes()
        if Catalyst::Seal::Dispatch->can('_clear_routes');
    is(body(PATH_INFO => '/guard/thing/edit', REQUEST_METHOD => 'GET'),
        '200 shallow:edit', 'the GET descends when it goes first');
    is(body(PATH_INFO => '/guard/thing/edit', REQUEST_METHOD => 'POST'),
        '200 deep', 'and the POST is still routed to the deep action');
}

# ------------------------------------------------- the ordinary routes still work

{
    is(body(PATH_INFO => '/'), '200 hello', 'the plain route is unaffected');
    is(body(PATH_INFO => '/books/42'), '200 book 42', 'and an argument route');
    like(body(PATH_INFO => '/no/such/thing'), qr/^404 /, 'and a real 404 is still a 404');
    like(body(PATH_INFO => '/no/such/thing'), qr/^404 /, 'twice');
}

done_testing;

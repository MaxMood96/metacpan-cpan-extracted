#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();
use File::Spec ();

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
require TestApp;
require SealTest;
require SealTest::HttpError;

unless (Catalyst->can('handle_request') == \&Catalyst::Seal::Exceptions::_handle_request) {
    plan skip_all => 'handle_request was not patched on this Catalyst';
}

ok(1, 'handle_request is the eval version');
ok(
    Catalyst->can('prepare') == \&Catalyst::Seal::Exceptions::_prepare,
    'prepare is the eval version',
);

my $app = TestApp->psgi_app;

# A plain die in an action is caught, logged, and a response still comes out.
{
    my $res = SealTest::response($app, PATH_INFO => '/boom');
    cmp_ok($res->[0], '>=', 400, 'a dying action produces an error status')
        or diag explain $res;
}

# An exception object that overloads boolean to false, thrown from an action,
# is dropped by Catalyst itself: Catalyst::execute decides whether the eval
# failed with "if (my $error = $@)", which is false for this object. Seal does
# not change that, and t/20-parity.t proves sealed and stock agree. Asserted
# here so that if Catalyst ever fixes it, this file says where to look.
{
    my $res = SealTest::response($app, PATH_INFO => '/httperr');
    is($res->[0], 200, 'Catalyst::execute drops a false-overloading exception (stock behaviour)')
        or diag explain $res;
}

# The patched handle_request itself must not repeat that mistake. It decides
# with the eval's own return value, so an exception object thrown from prepare
# reaches _handle_http_exception and is rethrown for the middleware, however it
# overloads boolean.
{
    my $thrown = SealTest::HttpError->new;
    ok(!$thrown, 'the exception object really is false in boolean context');

    no warnings 'redefine';
    local *Catalyst::prepare = sub { die $thrown };

    my $err;
    my $status = eval { TestApp->handle_request(); } ;
    $err = $@;

    ok(Scalar::Util::blessed($err), 'the exception was rethrown, not logged and swallowed')
        or diag "status=" . (defined $status ? $status : 'undef') . " err=" . (defined $err ? $err : 'undef');
    is(ref $err, 'SealTest::HttpError', 'and it is the same object');
}

# A die with a plain string from prepare is logged, not rethrown, and the
# caller gets the -1 status Catalyst promises.
{
    no warnings 'redefine';
    local *Catalyst::prepare = sub { die "plain failure\n" };
    # Catalyst::Log writes the caught error to STDERR, which is correct and
    # noisy. The point of this block is the return value, not the log line.
    open my $devnull, '>', File::Spec->devnull or die $!;
    my $status = do {
        local *STDERR = $devnull;
        eval { TestApp->handle_request() };
    };
    is($@, '', 'a plain error is not rethrown');
    is($status, -1, 'and the documented worst-case status comes back');
}

# $@ is not left set for the caller after a handled error.
{
    $@ = '';
    SealTest::response($app, PATH_INFO => '/boom');
    is($@, '', 'a handled error does not leak $@ to the caller');
}

# The ordinary path is unaffected by all of the above.
{
    my $res = SealTest::response($app);
    is($res->[0], 200, 'the ordinary path still works');
    is(join('', @{ $res->[2] }), 'hello', 'with the right body');
}

done_testing;

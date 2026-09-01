#!perl
# The upstream conformance suite for the Future::AsyncAwait::Awaitable API.
# Neither it nor Test2::V0 is a dependency, so the file skips when they are
# not installed; t/26-awaitable.t covers the same ground with Test::More.
# The plan is printed before either is loaded, so a skip stays a skip.
use strict;
use warnings;

BEGIN {
    unless ( eval { require Test2::V0;
                    require Test::Future::AsyncAwait::Awaitable; 1 } ) {
        print "1..0 # SKIP Test2::V0 and "
            . "Test::Future::AsyncAwait::Awaitable required\n";
        exit 0;
    }
}

use Test2::V0;
use Test::Future::AsyncAwait::Awaitable qw(test_awaitable);
use Fetch::Future;

test_awaitable "Fetch::Future",
    class  => 'Fetch::Future',
    new    => sub { Fetch::Future->new },
    cancel => sub { $_[0]->cancel };

done_testing;

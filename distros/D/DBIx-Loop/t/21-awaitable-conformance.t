#!perl
# The upstream conformance suite for the Future::AsyncAwait::Awaitable API.
# Neither it nor Test2::V0 is a dependency, so the file skips when they are
# not installed; t/20-awaitable.t covers the same ground with Test::More.
# The plan is printed before either is loaded, so a skip stays a skip.
#
# No `cancel` argument: this future has no cancelled state, so the suite's
# cancellation subtest does not apply. See t/20-awaitable.t, which pins that.
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
use DBIx::Loop;

test_awaitable "DBIx::Loop::Future",
    class => 'DBIx::Loop::Future',
    new   => sub { DBIx::Loop::Future->new };

done_testing;

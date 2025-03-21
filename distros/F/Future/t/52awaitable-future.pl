use v5.10;
use strict;
use warnings;

use Test2::V0;

eval { require Test::Future::AsyncAwait::Awaitable } or
   plan skip_all => "No Test::Future::AsyncAwait::Awaitable";

use Future;

Test::Future::AsyncAwait::Awaitable::test_awaitable( "Future",
   class  => "Future",
   cancel => sub { shift->cancel },
);

done_testing;

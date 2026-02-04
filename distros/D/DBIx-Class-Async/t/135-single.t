#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

$schema->resultset('User')
       ->create({ name => 'Alice', age => 30 })
       ->get;

my $bob = $schema->resultset('User')
                 ->create({ name => 'Bob', age => 40 })
                 ->get;

$bob->create_related('orders', { amount => 99.99, status => 'shipped' })
    ->get;

subtest 'Basic single()' => sub {
    my $rs = $schema->resultset('User')->search({ name => 'Bob' });
    my $user = $schema->await($rs->single);

    isa_ok($user, 'TestSchema::Result::User');
    is($user->name, 'Bob', "single() found the correct user");
};

subtest 'single_future() with Prefetch' => sub {
    my $rs = $schema->resultset('User')
        ->search({ 'me.name' => 'Bob' })
        ->prefetch('orders');

    my $user = $schema->await($rs->single_future);

    ok($user, "Found user via single_future");
    is($user->name, 'Bob', "Correct user returned");

    # Verify prefetch worked through the single() path
    my $orders = $user->{_relationship_data}{orders};
    is(ref $orders, 'ARRAY', "Orders were prefetched during single() call");
    is($orders->[0]{amount}, 99.99, "Related data is intact");
};

subtest 'single() returns undef on no match' => sub {
    my $rs = $schema->resultset('User')->search({ name => 'NonExistent' });
    my $user = $schema->await($rs->single);

    is($user, undef, "single() returns undef when no rows match");
};

subtest 'single() utilizes existing buffer' => sub {
    my $rs = $schema->resultset('User')->search({});

    $schema->await($rs->all);
    ok($rs->{_rows}, "Buffer is populated");

    # Now call single() - it should return the first item without a new DB hit
    # (If you have STAGE logs enabled, you'll see no 'all' sent to worker here)
    my $user = $schema->await($rs->single);
    is($user->name, 'Alice', "single() pulled from buffer correctly");
};

$schema->disconnect;

done_testing;

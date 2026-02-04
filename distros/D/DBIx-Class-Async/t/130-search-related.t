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

my $user = $schema->resultset('User')->create({
    id     => 1,
    name   => 'BottomUp User',
    email  => 'bu@test.com',
    active => 1,
})->get;

$schema->resultset('Order')->create({
    user_id => 1,
    status  => 'pending',
    amount  => 100.00,
})->get;

$schema->resultset('Order')->create({
    user_id => 1,
    status  => 'completed',
    amount  => 50.00,
})->get;

subtest 'Relationship Pivoting (search_related)' => sub {
    my $user_future = $schema->resultset('User')->find(1);
    my $user        = $user_future->get;
    my $orders_rs   = eval { $user->search_related_rs('orders') };

    if ($@) {
        fail("search_related_rs failed: $@");
        return;
    }

    isa_ok($orders_rs, 'DBIx::Class::Async::ResultSet', 'Pivoted to Orders');
    is($orders_rs->{_source_name}, 'TestSchema::Result::Order', 'Source name updated to Order result class');

    my $orders = $orders_rs->all_future->get;

    is(scalar(@$orders), 2, 'User has 2 orders');

    if (@$orders) {
        is($orders->[0]->user_id, $user->id, 'Order belongs to the correct user');
    }
};

subtest 'Chained search_related' => sub {
    my $user = $schema->resultset('User')->find(1)->get;

    my $recent_orders = $user->search_related('orders',
        { status   => 'pending' },
        { order_by => { -desc => 'id' },
          rows     => 1 }
    )->all_future->get;

    ok(scalar @$recent_orders <= 1, "Chained search attributes respected (rows => 1)");
    is(scalar @$recent_orders, 1, "Found 1 pending order");
    is($recent_orders->[0]->status, 'pending', "Order status is pending");
};

$schema->disconnect;

done_testing;

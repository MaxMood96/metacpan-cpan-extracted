#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use File::Temp;
use Test::Exception;
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

$schema->await($schema->deploy({ add_drop_table => 0 }));

my @users = (
    { name => 'Alice',   email => 'alice@example.com',   active => 1 },
    { name => 'Bob',     email => 'bob@example.com',     active => 1 },
);

foreach my $user (@users) {
    $schema->resultset('User')->create($user)->get;
}

my $user_orders = {
    1 => [ { amount => 10, status => 'new' },
           { amount => 20, status => 'new' },
         ],
    2 => [ { amount => 30, status => 'completed' },
           { amount => 40, status => 'completed' },
         ]
};

foreach my $user_id (sort keys %$user_orders) {
    my $user = $schema->resultset('User')->find($user_id)->get;
    foreach my $order (@{$user_orders->{$user_id}}) {
        my $order = $user->create_related('orders', $order)->get;
    }
}

my $user_rs = $schema->resultset('User');
ok($user_rs, 'User resultset exists');

my $order_rs = $schema->resultset('Order');
ok($order_rs, 'Order resultset exists');

my $rs = $schema->resultset('Order')->search(
    {},
    { prefetch => 'user',
      order_by => { -desc => 'user.name' }
    }
);

my $orders = $rs->all->get;
is(scalar @$orders, 4, 'Got 4 orders');

my $order = $orders->[0];
my $user_future = $order->user;

isa_ok($user_future, 'Future', 'user() returns a Future');

my $user = $user_future->get;
isa_ok($user, 'DBIx::Class::Async::Row', 'Got user Row object');
ok($user->name, 'User has a name: ' . $user->name);

my @user_names;
foreach my $order (@$orders) {
    my $order_user = $order->user->get;
    push @user_names, $order_user->name;
}

is(scalar @user_names, 4, 'Got all 4 user names from prefetched data');
cmp_deeply(\@user_names, [qw/Bob Bob Alice Alice/], 'User names match expected order');

$schema->disconnect;

done_testing;

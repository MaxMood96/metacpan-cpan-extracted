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
    {
        workers      => 2,
        schema_class => 'TestSchema',
        async_loop   => $loop,
    },
);

$schema->await($schema->deploy);

subtest 'Real Data: Persistence and JSON Inflation' => sub {
    my $rs = $schema->resultset('User');

    # Insert a real record with JSON settings
    my $user = $rs->create({
        name     => 'Real Person',
        email    => 'real@data.com',
        settings => { notifications => 'on', theme => 'cobalt' },
        balance  => 99.99
    })->get;

    ok($user->id, "Record saved to disk with ID: " . $user->id);

    my $fresh = $rs->find($user->id)->get;

    is(ref($fresh->settings), 'HASH', 'Settings column inflated from DB text');
    is($fresh->settings->{theme}, 'cobalt', 'JSON data correctly recovered');
};

subtest 'Real Data: One-to-Many Relationship' => sub {
    my $user_rs  = $schema->resultset('User');
    my $order_rs = $schema->resultset('Order');

    my $user = $user_rs->create({ name => 'Shopper', email => 'shop@test.com' })->get;

    $order_rs->create({ user_id => $user->id, amount => 50.00, status => 'paid' })->get;
    $order_rs->create({ user_id => $user->id, amount => 15.00, status => 'shipped' })->get;

    my $rel_rs = $user->orders;
    isa_ok($rel_rs, 'DBIx::Class::Async::ResultSet', 'orders() returns a ResultSet');

    my $orders = $rel_rs->all->get;
    is(scalar @$orders, 2, 'Found 2 orders in the database for this user');
    is($orders->[0]->amount, 50.00, 'Data integrity verified');
};

subtest 'Real Data: SQL Prefetch Inflation' => sub {
    my $user_rs  = $schema->resultset('User');
    my $order_rs = $schema->resultset('Order');

    my $user = $user_rs->create({
        name  => 'Prefetch Tester',
        email => 'prefetch@test.com'
    })->get;

    $order_rs->create({
        user_id => $user->id,
        amount  => 42.00,
        status  => 'completed'
    })->get;

    my $prefetched_user = $user_rs->search(
        { 'me.email' => 'prefetch@test.com' },
        { prefetch   => 'orders' }
    )->first->get;

    my $orders_rs = $prefetched_user->orders;
    isa_ok($orders_rs, 'DBIx::Class::Async::ResultSet', 'Prefetched relationship');

    my $first_order = $orders_rs->all->get->[0];
    isa_ok($first_order, 'TestSchema::Result::Order', 'Order is a blessed object');
    is($first_order->amount, 42.00, 'Data recovered via JOIN');
};

subtest 'The "Memory-Only" Proof' => sub {
    $schema->{_async_db}->{_cache_ttl} = 300;
    my $rs = $schema->resultset('User');

    my $user = $rs->new_result({
        name   => 'Ghost User',
        orders => [
            { amount => 10.00, status => 'pending' },
            { amount => 20.00, status => 'completed' }
        ]
    });

    my $orders_rs = $user->orders;
    isa_ok($orders_rs, 'DBIx::Class::Async::ResultSet', 'Orders is a ResultSet');

    my $orders = $schema->await($orders_rs->all);
    is(scalar @$orders, 2, 'Found 2 memory-only orders');

    isa_ok($orders->[0], 'DBIx::Class::Async::Row', 'First order is a Row object');
    is($orders->[0]->amount, 10.00, 'First order amount correct');
    is($orders->[1]->amount, 20.00, 'Second order amount correct');
};

$schema->disconnect;

done_testing;

#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use Test::Exception;

use lib "t/lib";

use TestSchema;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

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

subtest 'Basic schema connection' => sub {
    isa_ok($schema, 'DBIx::Class::Async::Schema');

    my @sources = $schema->sources;
    cmp_ok(scalar @sources, '>=', 3, 'Has at least 3 sources');
    ok(grep(/^User$/,    @sources), 'Has User source');
    ok(grep(/^Order$/,   @sources), 'Has Order source');
    ok(grep(/^Product$/, @sources), 'Has Product source');
};

subtest 'Simple user CRUD' => sub {
    my $user_rs = $schema->resultset('User');
    isa_ok($user_rs, 'DBIx::Class::Async::ResultSet');

    # Create
    my $user = $user_rs->create({
        name   => 'Test User',
        email  => 'test@example.com',
        active => 1,
    })->get;

    isa_ok($user, 'DBIx::Class::Async::Row', 'Created row');
    is($user->name,  'Test User', 'Name is correct');
    is($user->email, 'test@example.com', 'Email is correct');

    # Find
    my $found = $user_rs->find($user->id)->get;
    isa_ok($found, 'DBIx::Class::Async::Row', 'Found row via find()');
    is($found->name, 'Test User', 'Found row name matches');

    # Update
    my $updated = $found->update({
        name   => 'Updated User',
        active => 0,
    })->get;
    is($updated->name,   'Updated User', 'Update reflected in returned object');
    is($updated->active, 0,              'Update attribute correct');
};

subtest 'Order operations' => sub {
    my $user_rs  = $schema->resultset('User');
    my $order_rs = $schema->resultset('Order');

    # Create user
    my $user = $user_rs->create({
        name  => 'Order User',
        email => 'order@example.com',
    })->get;

    # Create order
    my $order = $order_rs->create({
        user_id => $user->id,
        amount  => 49.99,
        status  => 'paid',
    })->get;

    isa_ok($order, 'DBIx::Class::Async::Row');
    is(sprintf('%.2f', $order->amount), '49.99', 'Amount is correct');
    is($order->user_id, $user->id, 'FK user_id is correct');

    # Test belongs_to (Lazy Loading)
    my $order_user = $order->user->get;
    isa_ok($order_user, 'DBIx::Class::Async::Row', 'Relationship returns a Row');
    is($order_user->id, $user->id, 'Relationship belongs_to works');

    # Test has_many
    my $user_orders = $user->orders->all->get;
    is(scalar @$user_orders, 1, 'User has 1 order');
    is($user_orders->[0]->id, $order->id, 'Relationship has_many works');
};

subtest 'Search and count' => sub {
    my $user_rs = $schema->resultset('User');

    # Count before
    my $count_before = $user_rs->count->get;

    # Create test data
    $user_rs->create({ name => 'Search Test 1', email => 's1@test.com', active => 1 })->get;
    $user_rs->create({ name => 'Search Test 2', email => 's2@test.com', active => 0 })->get;

    # Count after
    my $count_after = $user_rs->count->get;
    is($count_after, $count_before + 2, 'Count increased after creation');

    # Search active
    my $active_users = $user_rs->search({ active => 1 })->all->get;
    isa_ok($active_users, 'ARRAY', 'search->all returns arrayref');
    cmp_ok(scalar @$active_users, '>=', 1, 'Found active users in array');

    # Count active
    my $active_count = $user_rs->search({ active => 1 })->count->get;
    cmp_ok($active_count, '>=', 1, 'Search count works');
};

$schema->disconnect;

done_testing;

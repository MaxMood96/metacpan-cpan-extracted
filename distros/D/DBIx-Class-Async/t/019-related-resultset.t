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
        $user->create_related('orders', $order)->get;
    }
}

my $user_count  = $schema->resultset('User')->count->get;
my $order_count = $schema->resultset('Order')->count->get;
is($user_count, 2, 'Created 2 users');
is($order_count, 4, 'Created 4 orders');

subtest 'related_resultset - basic functionality' => sub {
    # Test that the method exists
    my $rs = $schema->resultset('Order');
    can_ok($rs, 'related_resultset');

    # Test creating a related resultset
    my $related_rs = eval { $rs->related_resultset('user') };
    if ($@) {
        diag("Error creating related_resultset: $@");
        fail("related_resultset creation failed");
        fail("placeholder");
    } else {
        isa_ok($related_rs, 'DBIx::Class::Async::ResultSet',
            'related_resultset returns a ResultSet');
        is($related_rs->source_name, 'User',
            'Related ResultSet has correct source name');
    }
};

subtest 'related_resultset - Order to User (belongs_to)' => sub {
    # Get orders with new status
    my $new_orders_rs = $schema->resultset('Order')
        ->search({ status => 'new' });

    # Get related users
    my $users_rs = eval { $new_orders_rs->related_resultset('user') };

    if ($@) {
        diag("Error in related_resultset: $@");
        BAIL_OUT("Cannot continue without working related_resultset");
    }

    isa_ok($users_rs, 'DBIx::Class::Async::ResultSet');
    is($users_rs->source_name, 'User', 'Correct source name');

    # Try to fetch the users
    my $users = eval { $users_rs->all->get };

    if ($@) {
        diag("Error fetching users: $@");
        use Data::Dumper;
        diag("SQL attrs: " . Dumper($users_rs->{_attrs}));
        diag("SQL cond: " . Dumper($users_rs->{_cond}));
        fail("Could not fetch users");
        fail("placeholder 1");
        fail("placeholder 2");
        fail("placeholder 3");
    } else {
        isa_ok($users, 'ARRAY', 'Got arrayref');
        ok(scalar @$users > 0, 'Found at least one user with pending orders');

        # Check that we got actual user objects
        my $user = $users->[0];
        isa_ok($user, 'DBIx::Class::Async::Row', 'Got Row object');
        ok($user->name, 'User has name: ' . $user->name);
    }
};

subtest 'related_resultset - User to Orders (has_many)' => sub {
    # Get active users
    my $active_users_rs = $schema->resultset('User')
        ->search({ active => 1 });

    # Get their orders
    my $orders_rs = eval { $active_users_rs->related_resultset('orders') };

    if ($@) {
        diag("Error in related_resultset: $@");
        BAIL_OUT("Cannot continue without working related_resultset");
    }

    isa_ok($orders_rs, 'DBIx::Class::Async::ResultSet');
    is($orders_rs->source_name, 'Order', 'Correct source name');

    # Try to fetch the orders
    my $orders = eval { $orders_rs->all->get };

    if ($@) {
        diag("Error fetching orders: $@");
        use Data::Dumper;
        diag("SQL attrs: " . Dumper($orders_rs->{_attrs}));
        diag("SQL cond: " . Dumper($orders_rs->{_cond}));
        fail("Could not fetch orders");
        fail("placeholder 1");
        fail("placeholder 2");
        fail("placeholder 3");
    } else {
        isa_ok($orders, 'ARRAY', 'Got arrayref');
        ok(scalar @$orders > 0, 'Found at least one order for active users');

        # Check that we got actual order objects
        my $order = $orders->[0];
        isa_ok($order, 'DBIx::Class::Async::Row', 'Got Row object');
        ok($order->status, 'Order has status: ' . $order->status);
    }
};

subtest 'related_resultset - chaining searches' => sub {
    # Chain: pending orders -> users -> active only
    my $rs = eval {
        $schema->resultset('Order')
            ->search({ status => 'pending' })
            ->related_resultset('user')
            ->search({ active => 1 })
    };

    if ($@) {
        diag("Error creating chain: $@");
        fail("Chain creation failed");
        fail("placeholder 1");
        fail("placeholder 2");
        fail("placeholder 3");
        return;
    }

    isa_ok($rs, 'DBIx::Class::Async::ResultSet', 'Chain returns ResultSet');

    my $results = eval { $rs->all->get };

    if ($@) {
        diag("Error executing chain: $@");
        fail("Chain execution failed");
        fail("placeholder 1");
        fail("placeholder 2");
    } else {
        isa_ok($results, 'ARRAY', 'Got results');

        # Verify all are active
        my $all_active = 1;
        foreach my $user (@$results) {
            $all_active = 0 unless $user->active;
        }

        ok($all_active || scalar(@$results) == 0,
            'All results match criteria (or empty)');

        pass('Chain completed successfully');
    }
};

subtest 'related_resultset - error handling' => sub {
    my $rs = $schema->resultset('User');

    # Test invalid relationship name
    eval {
        $rs->related_resultset('nonexistent_relation');
    };
    like($@, qr/No such relationship/, 'Dies on invalid relationship');

    # Test missing relationship name
    eval {
        $rs->related_resultset();
    };
    like($@, qr/required/, 'Dies when relationship name missing');
};

$schema->disconnect;

done_testing;

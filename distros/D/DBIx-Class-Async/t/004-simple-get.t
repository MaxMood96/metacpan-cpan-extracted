#!/usr/bin/env perl

use strict;
use warnings;

use File::Temp;
use Test::More;
use Test::Exception;

use lib "t/lib";

use TestSchema;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

my ($fh, $db_file) = File::Temp::tempfile( UNLINK => 1);
my $schema_class   = 'TestSchema';
my $loop           = IO::Async::Loop->new;

my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => $schema_class,
      loop         => $loop,
    });

$schema->await($schema->deploy);

subtest 'Basic schema connection' => sub {
    my $schema;
    lives_ok {
        $schema = DBIx::Class::Async::Schema->connect(
            "dbi:SQLite:dbname=$db_file", undef, undef, {},
            {
                workers      => 2,
                schema_class => $schema_class,
                loop         => $loop
            });
    } 'Schema connects successfully';

    isa_ok($schema, 'DBIx::Class::Async::Schema');

    my @sources = $schema->sources;
    cmp_ok(scalar @sources, '>=', 3, 'Has at least 3 sources');
    ok(grep(/^User$/,    @sources), 'Has User source');
    ok(grep(/^Order$/,   @sources), 'Has Order source');
    ok(grep(/^Product$/, @sources), 'Has Product source');

    lives_ok { $schema->disconnect } 'Can disconnect';
};

subtest 'Simple user CRUD' => sub {
    my $schema = DBIx::Class::Async::Schema->connect(
        "dbi:SQLite:dbname=$db_file", undef, undef, {},
        {
            workers      => 2,
            schema_class => $schema_class,
            loop         => $loop
        });

    my $user_rs = $schema->resultset('User');
    isa_ok($user_rs, 'DBIx::Class::Async::ResultSet');

    # Create
    my $user = $user_rs->create({
        name   => 'Test User',
        email  => 'test@example.com',
        active => 1,
    })->get;

    isa_ok($user, 'DBIx::Class::Async::Row');
    is($user->name, 'Test User');
    is($user->email, 'test@example.com');

    # Find
    my $found = $user_rs->find($user->id)->get;
    isa_ok($found, 'DBIx::Class::Async::Row');
    is($found->name, 'Test User');

    # Update
    my $updated = $found->update({
        name   => 'Updated User',
        active => 0,
    })->get;
    is($updated->name, 'Updated User');
    is($updated->active, 0);

    $schema->disconnect;
};

subtest 'Order operations' => sub {
    my $schema = DBIx::Class::Async::Schema->connect(
        "dbi:SQLite:dbname=$db_file", undef, undef, {},
        {
            workers      => 2,
            schema_class => $schema_class,
            loop         => $loop
        }
    );

    # Create user
    my $user = $schema->resultset('User')
                      ->create({
                        name  => 'Order User',
                        email => 'order@example.com' })
                      ->get;

    # Create order
    my $order = $schema->resultset('Order')
                       ->create({
                        user_id => $user->id,
                        amount  => 49.99,
                        status  => 'paid' })
                       ->get;

    isa_ok($order, 'DBIx::Class::Async::Row');
    is(sprintf('%.2f', $order->amount), '49.99');
    is($order->user_id, $user->id);

    # Test belongs_to
    my $order_user = $order->user->get;
    is($order_user->id, $user->id, 'belongs_to works');

    # Test has_many
    my $user_orders = $user->orders->all->get;
    isa_ok($user_orders, 'ARRAY');
    is(scalar @$user_orders, 1, 'User has 1 order');
    is($user_orders->[0]->id, $order->id, 'Correct order');

    $schema->disconnect;
};

subtest 'Search and count' => sub {
    my $schema = DBIx::Class::Async::Schema->connect(
        "dbi:SQLite:dbname=$db_file", undef, undef, {},
        {
            workers      => 2,
            schema_class => $schema_class,
            loop         => $loop
        });

    my $user_rs      = $schema->resultset('User');
    my $count_before = $user_rs->count->get;

    # Create test data
    $user_rs->create({
        name   => 'Search Test 1',
        email  => 's1@test.com',
        active => 1 })->get;
    $user_rs->create({
        name   => 'Search Test 2',
        email  => 's2@test.com',
        active => 0 })->get;

    my $count_after = $user_rs->count->get;
    is($count_after, $count_before + 2, 'Count increased');

    # Search active
    my $active_search_rs    = $user_rs->search({ active => 1 });
    my $active_users_future = $active_search_rs->all_future;
    my $active_users        = $active_users_future->get;
    isa_ok($active_users, 'ARRAY', 'search returns array of rows');

    # Count active
    my $active_count_rs     = $user_rs->search({ active => 1 });
    my $active_count_future = $active_count_rs->count_future;
    my $active_count        = $active_count_future->get;
    cmp_ok($active_count, '>=', 1, 'Has active users');

    $schema->disconnect;
};

done_testing;

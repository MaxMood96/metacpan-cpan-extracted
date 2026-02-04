#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use Test::Exception;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers => 2, schema_class => 'TestSchema', async_loop => $loop });

$schema->await($schema->deploy({ add_drop_table => 1 }));
my $row = {
    name     => 'Alice',
    age      => 20,
    email    => 'alice@example.com',
    active   => 1,
    settings => undef,
    balance  => 10,
};

my $rs = $schema->resultset('User');
$schema->await($rs->create($row));

subtest 'Row basics' => sub {

    my $user = $schema->await($rs->find(1));

    isa_ok($user, 'DBIx::Class::Async::Row', 'Row object');
    is($user->get_column('name'), 'Alice', 'get_column() works');
    is($user->get_column('email'), 'alice@example.com', 'get_column() works for email');

    # Test column accessor via method call
    is($user->name, 'Alice', 'Column accessor via method');
    is($user->email, 'alice@example.com', 'Column accessor via method');

    # Test get_columns
    my %columns = $user->get_columns;
    $row->{id}  = $user->id;
    is_deeply(\%columns, $row, 'get_columns() returns all columns');

    my %inflated = $user->get_inflated_columns;
    is($inflated{name}, 'Alice', 'get_inflated_columns includes name');

    ok($user->in_storage, 'Row is in storage');
};

subtest 'Row updates' => sub {

    my $user   = $schema->await($rs->find(1));
    my $update = $user->update({
        name  => 'Bob Updated',
        email => 'bob.updated@example.com'
    });

    isa_ok($update, 'Future', 'Row update returns Future');
    my $updated = $schema->await($update);
    isa_ok($updated, 'DBIx::Class::Async::Row', 'Returns Row');
    is($updated->name, 'Bob Updated', 'Name was updated');
    is($updated->email, 'bob.updated@example.com', 'Email was updated');

    # Force a reload from DB to prove it hit the disk
    my $discard = $updated->discard_changes;
    $schema->await($discard);

    is($updated->name, 'Bob Updated', 'Update persisted after discard_changes');
    is($updated->email, 'bob.updated@example.com', 'Email persisted after discard_changes');
};

subtest 'Row deletion' => sub {

    my $row = {
        name     => 'Temp',
        age      => 25,
        email    => 'temp@example.com',
        active   => 1,
        settings => undef,
        balance  => 1,
    };
    my $user = $schema->await($rs->create($row));
    my $user_id = $user->id;
    ok($user_id, 'Created temp user with id');

    # Delete the row
    my $deleted = $schema->await($user->delete);
    ok(defined $deleted, 'Delete completed');

    # Verify deletion from database
    my $check = $schema->await($rs->find($user_id));
    ok(!$check, 'Row was deleted from database');

    # Row object should know it's not in storage
    ok(!$user->in_storage, 'Row object knows it\'s not in storage');
};

subtest 'Row relationships' => sub {

    my $user_rs  = $schema->resultset('User');
    my $order_rs = $schema->resultset('Order');

    # User with orders (Alice, id=1)
    my $user = $schema->await($user_rs->find(1));
    ok($user, 'Found Alice (user id=1)');

    # Test related_resultset
    my $orders_rs = $user->related_resultset('orders');
    isa_ok($orders_rs, 'DBIx::Class::Async::ResultSet', 'related_resultset() works');
    is($orders_rs->source_name, 'TestSchema::Result::Order', 'Correct related resultset');

    $schema->await($user->create_related('orders', { amount => 10 }));
    $schema->await($user->create_related('orders', { amount => 20 }));

    # Get orders via relationship
    my $orders = $schema->await($user->orders->all);
    isa_ok($orders, 'ARRAY', 'Relationship returns arrayref');
    is(scalar @$orders, 2, 'Alice has 2 orders');

    my $first_order = $orders->[0];
    isa_ok($first_order, 'DBIx::Class::Async::Row', 'Order is Row object');
    is($first_order->user_id, $user->id, 'Order belongs to user');

    # Test belongs_to relationship
    my $order = $schema->await($order_rs->find($user->id));
    ok($order, 'Found order id=1');

    my $order_user = $order->user->get;
    isa_ok($order_user, 'DBIx::Class::Async::Row', 'Order->user returns Row');
    is($order_user->id, $user->id, 'Order belongs to correct user (Alice)');

    # Capture the ResultSet object itself
    my $orders_rs1 = $user->orders;
    isa_ok($orders_rs1, 'DBIx::Class::Async::ResultSet');

    # Get the data from it
    my $data1 = $schema->await($orders_rs1->all);

    # Call the accessor again - should return the SAME ResultSet object
    my $orders_rs2 = $user->orders;

    is($orders_rs1, $orders_rs2, 'The ResultSet object itself is cached in the Row');

    # Check that the data matches
    my $data2 = $schema->await($orders_rs2->all);
    is_deeply($data1, $data2, 'The data retrieved via the cached ResultSet is identical');
};

subtest 'Row errors' => sub {

    my $user = $schema->await($rs->find(1));

    # Invalid column access
    throws_ok {
        $user->get_column('nonexistent');
    } qr/No such column/, 'Invalid column throws error';

    # Invalid column via method
    throws_ok {
        $user->nonexistent_column
    } qr/Method .*nonexistent_column.* not found/, 'Invalid method throws error';

    # Invalid relationship
    throws_ok {
        $user->related_resultset('nonexistent');
    } qr/No such relationship/, 'Invalid relationship throws error';

    # Update without data
    lives_ok {
        $user->update()->get;
    } 'Update without data succeeds (no-op when no dirty columns)';

    # Update deleted row
    my $temp_user = $rs->create({
        name   => 'Temp',
        email  => 'temp2@example.com',
        active => 1,
    })->get;

    $temp_user->delete->get;

    throws_ok {
        $schema->await($temp_user->update({ name => 'Updated' }));
    } qr/not in storage|Cannot update/, 'Update deleted row fails';

    # Delete already deleted row
    my $delete_again = $temp_user->delete;
    my $result = $delete_again->get;
    ok(!$result, 'Delete already deleted returns false');
};

subtest 'Row inflation' => sub {

    my $rs   = $schema->resultset('User');
    my $user = $rs->find(1)->get;

    # Test that we can access all columns
    ok(defined $user->id, 'ID is accessible');
    ok(defined $user->name, 'Name is accessible');
    ok(defined $user->active, 'Active is accessible');
};

$schema->disconnect;

done_testing;

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

my $user_1 = $schema->resultset('User')
                    ->create({ name => 'Bob', age => 40 })
                    ->get;
$user_1->create_related('orders', { amount => 99.99, status => 'shipped' })
       ->get;

my $user_2 = $schema->resultset('User')
                    ->create({ name => 'Alice', age => 30 })
                    ->get;
$user_2->create_related('orders', { amount => 10.00, status => 'pending' })
       ->get;
$user_2->create_related('orders', { amount => 20.00, status => 'pending' })
       ->get;

my $user_3 = $schema->resultset('User')
                    ->create({ name => 'Charlie', age => 25 })
                    ->get;
$user_3->create_related('orders', { amount => 5.00, status => 'cancelled' })
       ->get;

subtest 'related_resultset() filtering' => sub {
    my $orders_rs = $schema->resultset('User')
                           ->search({ age => { '>=', 30 } })
                           ->related_resultset('orders');

    is($orders_rs->{_attrs}{join}, 'user', "Parent correctly identified 'user' as reverse rel");

    my $orders = $schema->await($orders_rs->all);
    is(scalar @$orders, 3, "Found 3 orders total for Alice and Bob")
        or diag "Got " . scalar @$orders . " orders instead of 3";
};

subtest 'slice() pagination' => sub {
    my $rs = $schema->resultset('Order')
                    ->search({}, { order_by => 'amount' });

    my $slice_rs = $rs->slice(1, 2);

    is($slice_rs->{_attrs}{offset}, 1, "Offset correctly set to 1");
    is($slice_rs->{_attrs}{rows}, 2, "Rows correctly set to 2");

    my $results = $schema->await($slice_rs->all);
    is(scalar @$results, 2, "Retrieved exactly 2 rows from slice");
    is($results->[0]->amount, 10.00, "First sliced element is 10.00");
    is($results->[1]->amount, 20.00, "Second sliced element is 20.00");
};

subtest 'Chained related and slice' => sub {
    # Alice (age 30) has two orders (10.00 and 20.00).
    # Let's get her second most expensive order using slice.
    my $alice_second_order = $schema->resultset('User')
                                    ->search({ name => 'Alice' })
                                    ->related_resultset('orders')
                                    ->search({}, { order_by => { -desc => 'amount' } })
                                    ->slice(1, 1);

    my $results = $schema->await($alice_second_order->all);
    is(scalar @$results, 1, "Found exactly one order in the chained slice");
    is($results->[0]->amount, 10.00, "Retrieved Alice's 2nd order (10.00)");
};

$schema->disconnect;

done_testing;

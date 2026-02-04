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
    name     => 'Async Developer',
    email    => 'dev@example.com',
    age      => 30,
    active   => 1,
    settings => { theme => 'dark', notifications => 1 },
    balance  => 1000.50,
})->get;

$schema->await($user->create_related('orders', { amount => 150.00, status => 'completed' }));
$schema->await($user->create_related('orders', { amount => 42.99,  status => 'pending'   }));


subtest 'Search with Prefetch and HashRefInflator' => sub {
    my $future = $schema->search_with_prefetch(
        'User',
        { email => 'dev@example.com' },
        ['orders'],
        { result_class => 'DBIx::Class::ResultClass::HashRefInflator' }
    );

    # We use list context to "unwrap" the results from the future
    my $results = $schema->await($future);

    # Now $results should be the ARRAY ref you expect
    is(ref($results), 'ARRAY', 'Results is an array reference');
    is(scalar @$results, 1, 'Found exactly 1 user');

    my $user = $results->[0];
    is($user->{name}, 'Async Developer', 'Correct user name');

    # Verify prefetch worked
    is(ref($user->{orders}), 'ARRAY', 'Orders prefetched as array');
    is(scalar @{$user->{orders}}, 2, 'Found both orders');

    is($user->{orders}[0]{amount}, 150, 'First order amount matches');

    # Validate JSON Inflator
    is(ref $user->{settings}, 'HASH', 'Settings column was correctly inflated from JSON');
    is($user->{settings}{theme}, 'dark', 'Inflated data is correct');
    is(ref $user->{settings}, 'HASH', 'Settings column inflated in HashRef');
};

subtest 'Search with Prefetch (Object Mode)' => sub {
    my $future = $schema->search_with_prefetch(
        'User',
        { email => 'dev@example.com' },
        ['orders']
    );

    my $results = $schema->await($future);
    my $u = $results->[0];

    ok(Scalar::Util::blessed($u), 'Result is a blessed Row object');
    ok($u->can('orders'), 'Object has orders relationship method');

    my $orders_future = $u->orders->all;
    my $orders = $schema->await($orders_future);
    is(scalar @$orders, 2, 'Related objects are accessible');
};

$schema->disconnect;

done_testing;

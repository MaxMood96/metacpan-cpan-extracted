#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use lib 't/lib';

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

# Create user
my $user = $schema->resultset('User')
                  ->create({
                    name  => 'Order User',
                    email => 'order@example.com', })
                  ->get;

# Create user's order
my $order_1 = $user->create_related('orders', { amount => 10, status => 'pending' })->get;
my $order_2 = $user->create_related('orders', { amount => 20, status => 'pending' })->get;

my $rows = $schema->await(
    $schema->resultset('User')
           ->search({ id => $user->id })
           ->all
);
is(scalar @$rows, 1, 'basic search works');

my $users_with_orders = $schema->await(
    $schema->search_with_prefetch('User', { 'me.id' => 1 }, 'orders')
);

is(scalar @$users_with_orders, 1, 'prefetch returns results');

my $results = $schema->search_with_prefetch(
    'User',
    { 'me.id' => $user->id },
    'orders',
    { result_class => 'DBIx::Class::ResultClass::HashRefInflator' }
)->get;

ok(ref $results eq 'ARRAY', 'Got array of results');
ok(ref $results->[0] eq 'HASH', 'Result is a plain hash');
ok(exists $results->[0]{orders}, 'Prefetched data is included in hash');

$schema->disconnect;

done_testing;

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

my $dave = $schema->resultset('User')->create({ name => 'Dave', age => 50 })->get;
$dave->create_related('orders', { amount => 10, status => 'pending' })->get;
$schema->resultset('User')->create({ name => 'Eve', age => 25 })->get;

subtest "Basic first()" => sub {
    # FIX: Remove ->get. search() returns the RS object immediately.
    my $rs = $schema->resultset('User')->search({}, { order_by => 'name' });

    # first() returns the Future
    my $user = $schema->await($rs->first);

    isa_ok($user, 'TestSchema::Result::User');
    is($user->name, 'Dave', "First user in alpha order is Dave");
};

subtest "first_future() Alias" => sub {
    my $rs = $schema->resultset('User')->search({ name => 'Eve' });
    my $user = $schema->await($rs->first_future);

    is($user->name, 'Eve', "first_future works as expected");
    done_testing;
};

subtest "first() with Prefetch" => sub {
    my $rs = $schema->resultset('User')
        ->search({ 'me.name' => 'Dave' })
        ->prefetch('orders');

    my $user = $schema->await($rs->first);

    ok($user, "Found user");
    # Access relationship data
    my $orders = $user->{_relationship_data}{orders};
    is(ref $orders, 'ARRAY', "Orders were prefetched into the first() result");
    is($orders->[0]{amount}, 10, "Prefetched data is correct");
};

subtest 'first() from buffered entries' => sub {
    my $rs = $schema->resultset('User')->search({}, { order_by => 'name' });

    # Fill the buffer
    $schema->await($rs->all);

    # Match the key used in your ResultSet.pm logic
    ok($rs->{_rows}, "Buffer (_rows) is populated");

    # FIX: Use $schema->wait instead of wait_for
    my $user = $schema->await($rs->first);
    is($user->name, 'Dave', "Retrieved from buffer correctly");
};

$schema->disconnect;

done_testing;

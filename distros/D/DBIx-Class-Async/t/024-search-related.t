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

my $user = $schema->resultset('User')
                  ->create({
                    name  => 'Buyer',
                    email => 'buyer@example.com',
                    })->get;

$user->create_related('orders', { amount => 10 })->get;
$user->create_related('orders', { amount => 2  })->get;
$user->create_related('orders', { amount => 15 })->get;

my $user_rs = $schema->resultset('User')->search({ email => 'buyer@example.com' });

subtest 'search_related_rs (Scalar Context)' => sub {
    # This should trigger the metadata path
    my $rs_only = $user_rs->search_related_rs('orders');

    isa_ok($rs_only, 'DBIx::Class::Async::ResultSet');
    is($rs_only->{_source_name}, 'Order', 'Pivoted to Orders source');
};

subtest 'search_related (List Context)' => sub {
    # Get the related ResultSet
    my $related_rs = $user_rs->search_related_rs('orders');

    # Then call ->all to get the Future
    my $f = $related_rs->all;

    ok($f && $f->can('get'), 'Method returns a resolvable Future');

    my $results = $schema->await($f);

    is(scalar @$results, 3, 'Found all 3 related orders');

    if (@$results) {
        is($results->[0]->get_column('amount'), 10, 'Data is correct');
    }
};

subtest 'search_related (List Context)' => sub {
    my $f = scalar $user_rs->search_related('orders');

    ok($f && $f->can('get'), 'Method returns a resolvable Future');

    my $results = $f->get;

    # Ensure we are dealing with an arrayref
    my @orders = (ref $results eq 'ARRAY') ? @$results : ($results);

    is(scalar @orders, 3, 'Found all 3 related orders');

    if (@orders) {
        is($orders[0]->get_column('amount'), 10, 'Data is correct');
    }
};

$schema->disconnect;

done_testing;

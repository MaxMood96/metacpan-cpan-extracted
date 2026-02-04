#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use File::Temp;
use Test::Exception;

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
                  ->create({ name => 'Alice', age => 30 })
                  ->get;
for my $i (1..5) {
    $user->create_related('orders', {
        amount => $i * 10,
        status => ($i <= 3 ? 'pending' : 'shipped')
    })->get
}

subtest 'search_with_pager metadata initialization' => sub {
    my $rs = $schema->resultset('Order');

    # We want pending orders, 2 per page
    my $paged_rs = $rs->search({ status => 'pending' }, { rows => 2, page => 1 });

    ok($paged_rs->is_paged, "ResultSet correctly identified as paged");
    is($paged_rs->{_attrs}{rows}, 2, "Rows attribute preserved");
    is($paged_rs->{_attrs}{page}, 1, "Page attribute preserved");

    my $pager = $paged_rs->pager;
    isa_ok($pager, 'DBIx::Class::Async::ResultSet::Pager');
    is($pager->entries_per_page, 2, "Pager inherited rows limit");
};

subtest 'search_with_pager execution' => sub {
    my $rs     = $schema->resultset('Order');
    my $future = $rs->search_with_pager(
        { status   => 'pending' },
        { rows     => 2,
          page     => 1,
          order_by => 'amount' }
    );

    my ($rows, $pager) = $schema->await($future);

    is(scalar @$rows, 2, "Found 2 rows for page 1");
    is($rows->[0]->amount, 10, "First row is correct (amount 10)");

    my $total = $schema->await($pager->total_entries);
    is($total, 3, "Total entries correctly reported as 3");
    is($pager->last_page, 2, "Correctly calculated that there are 2 pages total");
    ok($pager->has_next, "Pager knows there is a second page");
};

subtest 'search_with_pager with related pivot' => sub {
    my $future = $schema->resultset('User')
                        ->search({ age => 30 })
                        ->related_resultset('orders')
                        ->search_with_pager({}, { rows => 1 });

    my ($rows, $pager) = $schema->await($future);

    is(scalar @$rows, 1, "Pivoted and paged data successfully");
    is($schema->await($pager->total_entries), 5, "Total count correctly identified 5 orders for Alice");
};

done_testing;

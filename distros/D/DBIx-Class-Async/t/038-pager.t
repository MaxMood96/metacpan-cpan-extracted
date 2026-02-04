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

for my $i (1..25) {
    $schema->resultset('User')->create({
        name  => "User $i",
        email => "user$i\@test.com"
    })->get;
}

subtest "ResultSet count vs count_total" => sub {
    my $rs = $schema->resultset('User')->page(1);

    my $page_count = $rs->count->get;
    is($page_count, 10, "count() returns the slice size (10)");

    my $total_count = $rs->count_total->get;
    is($total_count, 25, "count_total() returns the full table size (25)");
};

subtest "Full Pager Integration" => sub {
    my $rs = $schema->resultset('User')->page(3);

    my $pager = $rs->pager;
    is($pager->current_page, 3, "Pager on correct page");

    my $total_f = $pager->total_entries;
    is($total_f->get, 25, "Pager total_entries is correct");

    is($pager->last_page, 3, "Last page is 3 (10+10+5)");
    is($pager->entries_on_this_page, 5, "Entries on page 3 is 5");
    ok($pager->previous_page, "Has a previous page");
    ok(!$pager->next_page, "No next page (this is the last page)");
};

subtest "Search with Pager (Parallel)" => sub {
    my $rs = $schema->resultset('User');

    my $f = $rs->search_with_pager(undef, { page => 2, rows => 10 });

    my ($rows, $pager) = $f->get;

    is(scalar @$rows, 10, "Fetched 10 rows for page 2");
    is($rows->[0]->name, "User 11", "First row is User 11");
    is($pager->total_entries->get, 25, "Pager still knows there are 25 total");
    is($pager->current_page, 2, "Pager correctly reports page 2");
};

subtest "Ordering Check" => sub {
    my $rs = $schema->resultset('User');
    ok( !$rs->is_ordered, "New resultset is not ordered" );

    my $ordered_rs = $rs->search(undef, { order_by => { -desc => 'created_at' } });
    ok( $ordered_rs->is_ordered, "Resultset with order_by returns true for is_ordered" );
};

$schema->disconnect;

done_testing;

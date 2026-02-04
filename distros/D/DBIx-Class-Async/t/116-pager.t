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
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

$schema->resultset('User')->delete_all->get;
for (1..25) {
    $schema->resultset('User')->create({ id => $_, name => "User $_" })->get;
}

subtest 'Pager: Initialization and Math' => sub {
    my $rs = $schema->resultset('User')->page(1)->search(undef, { rows => 10 });
    my $pager = $rs->pager;

    isa_ok($pager, 'DBIx::Class::Async::ResultSet::Pager');
    is($pager->current_page, 1, 'Initial page is 1');

    my $f = $pager->total_entries;
    isa_ok($f, 'Future', 'total_entries returns a Future');

    my $total = $f->get;
    is($total, 25, 'Correctly counted 25 total entries');

    is($pager->last_page, 3, 'Last page is 3 (ceil(25/10))');
    is($pager->entries_on_this_page, 10, 'First page has 10 entries');
    is($pager->next_page, 2, 'Next page is 2');
    is($pager->previous_page, undef, 'No previous page for page 1');
};

subtest 'Pager: Boundary Conditions' => sub {
    my $rs_last = $schema->resultset('User')->page(3)->search(undef, { rows => 10 });

    my $pager = $rs_last->pager;

    $pager->{_total_entries} = 25;

    is($pager->entries_on_this_page, 5, 'Last page (3) has exactly 5 entries');
    is($pager->next_page, undef, 'No next page after page 3');
    is($pager->previous_page, 2, 'Previous page is 2');
};

subtest 'Pager: ResultSet Chaining' => sub {
    my $rs = $schema->resultset('User')->page(1)->search(undef, { rows => 10 });
    my $pager = $rs->pager;

    $pager->total_entries->get;

    my $next_rs = $pager->next_page_rs;
    isa_ok($next_rs, 'DBIx::Class::Async::ResultSet', 'next_page_rs returns a ResultSet');

    is($next_rs->{_attrs}->{page}, 2, 'New ResultSet is targeted at page 2');
};

$schema->disconnect;

done_testing;

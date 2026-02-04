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

my $rs = $schema->resultset('User');

$rs->create({ name => 'Alice', email => 'alice@test.com', active => 1 })->get;
$rs->create({ name => 'Bob',   email => 'bob@test.com',   active => 1 })->get;
$rs->create({ name => 'Charlie', email => 'charlie@test.com', active => 0 })->get;

# Test count_literal
my $active_count = $rs->count_literal('active = ?', 1)->get;
is($active_count, 2, "count_literal returned correct count for active users");

# Test search_literal (with Multiple Bind Values)
my $literal_rs = $rs->search_literal('name = ? OR email = ?', 'Alice', 'bob@test.com');
my $found = $literal_rs->all->get;
is(scalar @$found, 2, "search_literal found correct number of rows with multiple binds");
is($found->[0]->name, 'Alice', "search_literal retrieved correct accessor data");

# Test Chaining after search_literal
my $chained_count = $rs->search_literal('active = ?', 1)
                       ->search({ name => 'Alice' })
                       ->count
                       ->get;
is($chained_count, 1, "Chaining standard search() after search_literal() works");

# Test count_rs (Standalone execution)
my $cnt_rs  = $rs->search({ active => 1 })->count_rs;
my $cnt_row = $cnt_rs->single_future->get;
is($cnt_row->get_column('count'), 2, "count_rs works as a standalone executed ResultSet");

# Test count_rs (Subquery usage via as_query)
my $id_subquery = $rs->search(
    { active => 1 },
    { select => ['id'] }
)->as_query;

my $complex_rs = $rs->search({ id => { -in => $id_subquery } });
my $subquery_results = $complex_rs->all->get;
is(scalar @$subquery_results, 2, "as_query successfully generated a valid subquery");

$schema->disconnect;

done_testing;

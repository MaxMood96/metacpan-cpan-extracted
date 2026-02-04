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

$schema->resultset('User')->create({ name => 'Alice', active => 1 })->get;
$schema->resultset('User')->create({ name => 'Bob',   active => 1 })->get;
$schema->resultset('User')->create({ name => 'Charlie', active => 0 })->get;

my $rs = $schema->resultset('User');

subtest 'Standard Count'=> sub {
    my $future = $rs->count({ active => 1 });

    my $count;
    $future->on_done(sub { $count = shift; $loop->stop; });
    $loop->run;

    is($count, 2, "Standard count returned 2 active users");
};

subtest 'Count Literal' => sub {
    # Literal SQL fragment for SQLite
    my $future = $rs->count_literal('name LIKE ?', 'A%');

    my $literal_count;
    $future->on_done(sub { $literal_count = shift; $loop->stop; });
    $loop->run;

    is($literal_count, 1, "count_literal found 1 user starting with 'A' (Alice)");
};

subtest 'Scoreboard Integrity' => sub {
    # Use the new public method
    my $queries = $rs->stats('queries');

    # If you didn't reset, we expect 5 (3 setup + 2 test)
    is($queries, 5, "The public stats() method correctly reported 4 queries");
};

subtest 'Testing count_rs and lazy stats' => sub {
    # Get current query count
    my $initial_queries = $rs->stats('queries');

    # Call count_rs (Lazy)
    my $count_rs = $rs->count_rs({ active => 1 });

    isa_ok($count_rs, 'DBIx::Class::Async::ResultSet', "count_rs returned a ResultSet");
    is($rs->stats('queries'), $initial_queries, "Counter NOT incremented after count_rs (Lazy)");

    # Execute the RS using the async count method
    my $future = $count_rs->count;

    my $val;
    $future->on_done(sub {
        $val = shift;
        $loop->stop;
    });
    $loop->run;

    # Verify results
    is($val, 2, "Execution of count_rs returned correct data");
    is($rs->stats('queries'), $initial_queries + 1, "Counter incremented exactly once after execution");
};

subtest 'Testing error metrics' => sub {
    # Capture current error count
    my $initial_errors = $rs->stats('errors') || 0;

    # Trigger a guaranteed SQL syntax error
    my $bad_rs = $rs->search_literal('THIS IS NOT VALID SQL');

    my $future = $bad_rs->count;

    $future->on_ready(sub { $loop->stop });

    $loop->run;

    is($rs->stats('errors'), $initial_errors + 1, "The Accountant caught the syntax error");
};

$schema->disconnect;

done_testing;

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

$schema->resultset('User')->populate([
    [qw/ name age / ],
    [ 'Alice', 30   ],
    [ 'Bob',   40   ],
    [ 'Charlie', 20 ],
])->get;

my $rs = $schema->resultset('User');

subtest 'Testing ResultSetColumn Aggregates' => sub {
    my $initial_queries = $rs->stats('queries');

    my $age_col = $rs->get_column('age');
    isa_ok($age_col, 'DBIx::Class::Async::ResultSetColumn', "get_column returned the proxy");
    is($rs->stats('queries'), $initial_queries, "Counter did not increment yet");

    my $max_val;
    my $f_max = $age_col->max;

    $f_max->on_done(sub {
        my $val  = shift;
        $max_val = $val;
        $loop->stop;
    });

    $loop->run;

    ok(defined $max_val, "Retrieved a maximum age: $max_val");
    is($rs->stats('queries'), $initial_queries + 1, "Counter incremented for MAX query");

    my $sum_val;
    my $f_sum = $age_col->sum;

    $f_sum->on_done(sub { $sum_val = shift; $loop->stop; });
    $loop->run;

    ok(defined $sum_val, "Retrieved a sum of ages: $sum_val");
    is($rs->stats('queries'), $initial_queries + 2, "Counter incremented for SUM query");

    my $filtered_rs = $rs->search({ name => { '!=', undef } });
    my $f_filtered  = $filtered_rs->get_column('age')->min;

    my $min_val;
    $f_filtered->on_done(sub { $min_val = shift; $loop->stop; });
    $loop->run;

    ok(defined $min_val, "Retrieved MIN(age) with filters");
    is($rs->stats('queries'), $initial_queries + 3, "Counter incremented for filtered MIN query");
};

subtest 'Testing Average Aggregate' => sub {
    my $f_avg = $rs->get_column('age')->average;

    my ($avg_val, $error);

    $f_avg->on_ready(sub {
        my $f = shift;
        if ($f->is_done) {
            $avg_val = $f->result;
        } else {
            $error   = $f->failure;
        }
        $loop->stop;
    });

    $loop->run;

    if ($error) {
        fail("Average query failed: $error");
    } else {
        cmp_ok($avg_val, '==', 30, "Retrieved the correct average age (30)");
    }
};

subtest 'Testing Column Count' => sub {
    my $f = $rs->get_column('age')->count;
    my $val;

    $f->on_ready(sub {
        my $future = shift;
        if ($future->is_done) {
            $val   = $future->result;
        } else {
            $val   = undef;
        }
        $loop->stop;
    });

    $loop->run;
    is($val, 3, "Column count works");
};

$schema->disconnect;

done_testing;

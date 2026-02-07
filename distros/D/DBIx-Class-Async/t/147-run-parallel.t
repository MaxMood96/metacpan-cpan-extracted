#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use Future;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

subtest 'run_parallel executes tasks concurrently and returns results' => sub {
    my $combined_future = $schema->run_parallel(
        sub { Future->done('result1') },
        sub { Future->done('result2') },
    );

    my @results = $schema->await_all($combined_future);

    is(scalar @results, 2, 'Should return results for all tasks');
    is($results[0], 'result1', 'Task 1 result is correct');
    is($results[1], 'result2', 'Task 2 result is correct');
};

subtest 'run_parallel propagates failures' => sub {
    my $combined_future = $schema->run_parallel(
        sub { Future->done('good') },
        sub { Future->fail('database error') },
    );

    eval { $schema->await_all($combined_future) };

    ok($@, 'Should throw an exception if a task fails');
    like($@, qr/database error/, 'Exception message should match');
};

$schema->disconnect;

done_testing;

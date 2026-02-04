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
my ($fh, $db_file) = File::Temp::tempfile(SUFFIX => '.db', UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

$schema->resultset('User')
       ->create({ name => 'Alice', email => 'a@test.com' })
       ->get;
$schema->resultset('User')
       ->create({ name => 'Bob',   email => 'b@test.com' })
       ->get;

subtest 'Verify search_future Alias' => sub {
    my $rs = $schema->resultset('User');

    my $future = $rs->search_future({ name => 'Bob' });
    isa_ok($future, 'Future', 'Method returns a Future object');

    $loop->await($future);

    my ($payload) = $future->get;

    my @results = (ref($payload) eq 'ARRAY') ? @$payload : ($payload);

    is(scalar @results, 1, 'Found exactly one record')
        or diag("Expected 1 result, got: " . scalar @results);

    if (@results) {
        my $row = $results[0];

        isa_ok($row, 'TestSchema::Result::User', 'Result is correctly inflated');
        is($row->name, 'Bob', 'Correct record retrieved');
    }
};

$schema->disconnect;

done_testing;

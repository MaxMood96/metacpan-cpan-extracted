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

subtest "Bulk Populate" => sub {
    my $data = [
        { name => 'User A', email => 'a@test.com', age => 25 },
        { name => 'User B', email => 'b@test.com', age => 30 },
        { name => 'User C', email => 'c@test.com', age => 35 },
    ];

    my $future = eval { $schema->populate('User', $data) };
    ok($future, "populate() returned a future") or diag $@;

    my $res = $future->get;
    ok($res, "Bulk populate completed successfully");

    my $count_future = $schema->resultset('User')->count_future;
    is($count_future->get, 3, "All 3 rows were inserted via populate");
};

$schema->disconnect;

done_testing;

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

for my $i (1..100) {
    $schema->resultset('User')
           ->create({
            name   => 'User' . $i,
            email  => 'alice' . $i . '@example.com',
            active => ($i % 2) ? 1 : 0, })
           ->get;
}

my $rs = $schema->resultset('User');

subtest 'Standard count (no limit)' => sub {
    $rs->count
       ->then(sub {
        my $count = shift;
        is($count, 100, 'Total count returns full table size');
        return Future->done; })
       ->get;
};

subtest 'Sliced count (with rows limit)' => sub {
    $rs->search(undef, { rows => 5 })
       ->count
       ->then(sub {
        my $count = shift;
        is($count, 5, 'Count respects the "rows" attribute via subquery logic');
        return Future->done;
       })
       ->get;
};

subtest 'Sliced count with offset' => sub {
    $rs->search(undef, { rows => 10, offset => 95 })
       ->count
       ->then(sub {
        my $count = shift;
        is($count, 10, 'Count respects rows even with offset');
        return Future->done; })
       ->get;
};

$schema->disconnect;

done_testing;

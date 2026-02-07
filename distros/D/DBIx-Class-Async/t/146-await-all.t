#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
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

subtest 'await_all handles multiple concurrent futures' => sub {

    my $f1 = Future->done('result1');
    my $f2 = Future->done('result2');

    my @results = $schema->await_all($f1, $f2);

    is(scalar @results, 2, 'Should return results for all tasks');
    is($results[0], 'result1', 'First result is correct');
    is($results[1], 'result2', 'Second result is correct');
};

subtest 'await_all dies if any future fails' => sub {
    my $f1 = Future->done('good');
    my $f2 = Future->fail('something went wrong');

    eval { $schema->await_all($f1, $f2) };
    ok($@, 'Should throw an exception if a future fails');
    like($@, qr/something went wrong/, 'Exception message should match');
};

$schema->disconnect;

done_testing;

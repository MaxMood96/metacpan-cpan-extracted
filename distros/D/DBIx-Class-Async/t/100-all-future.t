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

my $user = $schema->resultset('User')->create({
    name   => 'Alice',
    email  => 'alice@example.com',
    active => 1,
})->get;

subtest 'Validation of all_future() Bridge' => sub {
    my $rs = $schema->resultset('User')->search({ id => 1 });

    my $future = $rs->all_future;

    isa_ok($future, 'Future', 'all_future() returns a Future');

    my $results = $future->get;
    ok(ref($results) eq 'ARRAY', 'Returns an arrayref of results');

    # Verify Structure
    ok(ref($results) eq 'ARRAY', 'Returns an arrayref of results');
    is(scalar @$results, 1, 'Found exactly 1 row');

    # Verify Inflation & Hijacking
    my $row = $results->[0];
    ok($row, 'Result row exists');
    isa_ok($row, 'DBIx::Class::Async::Row', 'Row is hijacked by Async::Row');
    isa_ok($row, 'TestSchema::Result::User', 'Row is still a TestSchema User');

    # Verify Data Accuracy
    is($row->name, 'Alice', 'Data was correctly retrieved from DB via worker');
    ok($row->in_storage, 'Row is correctly marked as in_storage');

    # Verify Class Name (Dynamic Hijacking check)
    like(ref($row), qr/Anon/, 'Row is blessed into a dynamic Anon class');
};

$schema->disconnect;

done_testing;

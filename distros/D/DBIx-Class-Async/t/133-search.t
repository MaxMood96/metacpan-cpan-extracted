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

$schema->resultset('User')->create({
    name => 'Alice',
    email => 'alice@test.com',
    active => 1
})->get;

$schema->resultset('User')->create({
    name => 'Bob',
    email => 'bob@test.com',
    active => 1
})->get;

my $rs = $schema->resultset('User')
                ->search({ active => 1 })
                ->search({ name => 'Alice' });

is(ref($rs), 'DBIx::Class::Async::ResultSet', 'Still an Async ResultSet after chaining');
is_deeply($rs->{_cond}, { -and => [ { active => 1 }, { name => 'Alice' } ] }, 'Conditions merged correctly');

my $future = $rs->all();

$schema->await($future);
my $results = $future->get;

is(ref($results), 'ARRAY', 'Worker returned an arrayref');
is(scalar @$results, 1, 'Correctly filtered to 1 result');
is($results->[0]{name}, 'Alice', 'Data is correct');
is($results->[0]{email}, 'alice@test.com', 'Email matches');

done_testing;

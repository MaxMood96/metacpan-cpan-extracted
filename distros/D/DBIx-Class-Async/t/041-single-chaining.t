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
    name   => 'Alice',
    email  => 'alice@example.com',
    active => 1,
})->get;

$schema->resultset('User')->create({
    name   => 'Bob',
    email  => 'bob@example.com',
    active => 0,
})->get;

subtest 'single_future preserves conditions' => sub {
    my $user = $schema->resultset('User')
                      ->search({ active => 1 })
                      ->single_future
                      ->get;

    ok($user, "Got a user");
    is($user->name, 'Alice', "Correct user returned (filter was respected)");
    is($user->active, 1, "Active column matches filter");

    my $none = $schema->resultset('User')
                      ->search({ name => 'NonExistent' })
                      ->single_future
                      ->get;

    is($none, undef, "Returns undef when search condition matches nothing");
};

subtest 'single_future with additional criteria' => sub {
    my $user = $schema->resultset('User')
                      ->single_future({ name => 'Bob' })
                      ->get;

    ok($user, "Found user by name");
    is($user->id, 2, "Got correct ID");
};

subtest 'find method works via single_future' => sub {
    my $user = $schema->resultset('User')
                      ->find(2)
                      ->get;

    ok($user, "find(2) returned a user");
    is($user->name, 'Bob', "Found the correct user by ID");
};

$schema->disconnect;

done_testing;

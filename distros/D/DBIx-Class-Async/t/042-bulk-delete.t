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

my @users = (
    { name => 'Alice', email => 'alice@example.com', active => 1 },
    { name => 'Bob',   email => 'bob@example.com',   active => 1 },
    { name => 'John',  email => 'john@example.com',  active => 0 },
    { name => 'Joe',   email => 'joe@example.com',   active => 1 },
    { name => 'Blog',  email => 'blog@example.com',  active => 0 },
);

foreach my $user (@users) {
    $schema->resultset('User')->create($user)->get;
}

subtest 'Real Integration: Optimised Delete' => sub {

    my $rs = $schema->resultset('User');
    my $active_rs = $rs->search({ active => 1 });

    is($active_rs->count->get, 3, "Found 3 active users");

    my $delete_f = $active_rs->delete;
    my $deleted_count = $delete_f->get;

    is($deleted_count, 3, "Bulk delete reported 3 rows deleted");

    my $remaining_count = $schema->resultset('User')->count->get;

    is($remaining_count, 2, "Only 1 user remains in the database");

    my $remaining_user = $rs->first->get;

    ok($remaining_user, "Found the remaining user");
    is($remaining_user->name, 'John', "The survivor is indeed Charlie");
};

$schema->disconnect;

done_testing;

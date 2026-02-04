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

my $rs = $schema->resultset('User');
for my $i (1..5) {
    $rs->create({
        name   => "User$i",
        email  => "user$i\@example.com",
        active => 1,
    })->get;
}

subtest 'Row->delete() works' => sub {
    my $users = $rs->all->get;
    my $user  = $users->[0];
    ok($user->in_storage, 'User is in storage before delete');

    my $result = $user->delete->get;
    is($result, 1, 'delete() returns 1 on success');

    ok(!$user->in_storage, 'User not in storage after delete');
};

subtest 'Row->delete() on already deleted row' => sub {
    my $users = $rs->all->get;
    my $user  = $users->[0];
    $user->delete->get;  # First delete

    ok(!$user->in_storage, 'User not in storage');

    my $result = $user->delete->get;  # Try to delete again
    is($result, 0, 'delete() returns 0 when already deleted');
};

subtest 'delete_all() calls Row->delete()' => sub {
    $rs->delete->get;
    for my $i (1..3) {
        $rs->create({
            name   => "TestUser$i",
            email  => "test$i\@example.com",
            active => 1,
        })->get;
    }

    my $count_before = $schema->resultset('User')->count->get;
    is($count_before, 3, 'Have 3 users before delete_all');

    my $deleted = $rs->search({ name => { -like => 'TestUser%' } })
                     ->delete_all
                     ->get;

    is($deleted, 3, 'delete_all() deleted 3 users');
};

subtest 'delete_all() vs delete() behavior' => sub {
    # Reset and create identical datasets
    $rs->delete->get;

    for my $i (1..5) {
        $rs->create({
            name   => "User$i",
            email  => "user$i\@example.com",
            active => ($i <= 3) ? 1 : 0,
        })->get;
    }

    # Test delete_all on first 3
    my $deleted_all = $rs->search({ active => 1 })
                         ->delete_all
                         ->get;

    is($deleted_all, 3, 'delete_all deleted 3 active users');
    is($rs->count->get, 2, '2 users remain');

    # Reset data
    $rs->delete->get;
    for my $i (1..5) {
        $rs->create({
            name   => "User$i",
            email  => "user$i\@example.com",
            active => ($i <= 3) ? 1 : 0,
        })->get;
    }

    # Test delete on first 3
    my $deleted_bulk = $rs->search({ active => 1 })
                          ->delete
                          ->get;

    is($deleted_bulk, 3, 'delete deleted 3 active users');
    is($rs->count->get, 2, '2 users remain');
};

$schema->disconnect;

done_testing;

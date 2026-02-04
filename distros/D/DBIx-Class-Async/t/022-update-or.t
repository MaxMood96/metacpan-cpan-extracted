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

subtest 'update_or_create logic' => sub {
    $rs->delete_all->get;

    $rs->create({
        name  => "Old Name",
        email => 'upsert@example.com',
    })->get;

    my $user = $rs->update_or_create(
        {
            email => 'upsert@example.com',
            name  => 'New Improved Name'
        },
        {
            key => 'user_email'
        })->get;

    is($user->name, 'New Improved Name', 'Record was updated successfully');
    is($schema->resultset('User')->count->get, 1, 'No new record was created');

    my $new_user = $rs->update_or_create(
        {
            email => 'brandnew@example.com',
            name  => 'Fresh User'
        },
        {
            key => 'user_email'
        })->get;

    is($rs->count->get, 2, 'New record created when email not found');
};

$schema->disconnect;

done_testing;

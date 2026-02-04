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

subtest 'ResultSet Create - Basic' => sub {
    my $rs = $schema->resultset('User');

    # We do NOT provide an ID here
    my $future = $rs->create({
        name  => 'Alice',
        email => 'alice@example.com'
    });

    my $user = $future->get;

    isa_ok($user, 'DBIx::Class::Async::Row', 'Returns a Row object');
    ok($user->id, 'User has an auto-incremented ID: ' . $user->id);
    is($user->name, 'Alice', 'Name matches');
    ok($user->in_storage, 'Row is marked as in_storage');
};

subtest 'Verify Async Capabilities' => sub {
    my $user = $schema->resultset('User')->create({ name => 'Test' })->get;

    isa_ok($user, 'DBIx::Class::Async::Row', 'Object from create() should be Async-aware');

    my $f = $user->delete;
    isa_ok($f, 'Future', 'delete() on created object should return a Future');
    $f->get;
};

subtest 'The Breaking Point: Deflation' => sub {
    my $rs = $schema->resultset('User');

    # Assuming 'settings' is a column with an inflator/deflator (like JSON)
    my $future = $rs->create({
        name     => 'Bob',
        email    => 'bob@example.com',
        settings => { theme => 'dark', font => 'monaco' }
    });

    my $user = eval { $future->get };
    ok($user, "Create handled complex data") or diag("Error: $@");
};

$schema->disconnect;

done_testing;

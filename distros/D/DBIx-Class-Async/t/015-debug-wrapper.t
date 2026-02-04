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
is(ref($rs), 'DBIx::Class::Async::ResultSet');

my $user = $schema->resultset('User')
                  ->create({
                    name  => 'Alice',
                    email => 'alice@example.com', })
                  ->get;

is($user->name, 'Alice');

$schema->disconnect;

done_testing;

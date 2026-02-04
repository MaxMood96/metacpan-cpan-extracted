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

$schema->resultset('User')
       ->create({
           name   => 'Alice',
           email  => 'alice@example.com',
           active => 1
        })->get;

my $rs = $schema->resultset('User')->search({ id => 1 });

# Create a "fake" row that doesn't exist in the DB
my $fake_user = $rs->new_result({ id => 999, name => "Ghost" });

# Manually set the cache
$rs->set_cache([ $fake_user ]);

# 'all' should return the fake user without hitting the DB
my $results = $rs->all->get;
is(scalar @$results, 1, "Got 1 result from RS cache");
is($results->[0]->name, "Ghost", "Result came from set_cache, not DB");

$rs->clear_cache;

ok(!defined $rs->get_cache, "Cache is now empty");

$schema->disconnect;

done_testing;

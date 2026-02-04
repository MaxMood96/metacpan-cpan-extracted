#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use CHI;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $tmp    = File::Temp::tempdir(CLEANUP => 1);

my $cache  = CHI->new(
    driver   => 'File',
    root_dir => $tmp,
    depth    => 2,
);
my $loop   = IO::Async::Loop->new;
my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$tmp/test.db", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      cache        => $cache,
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

sub run_test {
    return $schema->deploy->then(sub {
        return $schema->resultset('User')->create({ name => 'Test User', active => 1, email => 't@ex.com' });
    })->then(sub {
        return $schema->resultset('User')->search({ active => 1 }, { cache => 1 })->all;
    })->then(sub {
        my $rows = shift;
        is($schema->cache_misses, 1, "First search is a MISS");
        return $schema->resultset('User')->search({ active => 1 }, { cache => 1 })->all;
    })->then(sub {
        is($schema->cache_hits, 1, "Second search is a HIT");
        return $schema->resultset('User')->update(1, { name => 'Updated Name' });
    })->then(sub {
        return $schema->resulset('User')->search({ active => 1 }, { cache => 1 })->all;
    })->then(sub {
        my $rows = shift;
        is($rows->[0]{name}, 'Updated Name', "Got fresh data");
        is($schema->cache_misses, 2, "Third search is a MISS");
        return Future->done;
    });
}

my $f = run_test()->on_ready(sub { $loop->stop });

$loop->run;

ok($f->is_ready, "Test sequence finished within timeout");

done_testing;

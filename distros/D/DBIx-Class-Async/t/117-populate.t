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

subtest 'Standard Populate' => sub {
    my $rows = $schema->resultset('User')
                      ->populate([
                         [qw/name age/],
                         ['Dave', 50],
                         ['Eve',  25]
                      ])
                      ->get;

    is(ref $rows, 'ARRAY', "Returns array of rows");
    is(scalar @$rows, 2, "Got 2 rows back");
    is($rows->[0]{name}, 'Dave', "Dave is here");
};

subtest 'Bulk Populate' => sub {
    my $rows = $schema->resultset('User')
                      ->populate_bulk([ { name => 'Frank', age => 28 } ])
                      ->get;

    ok($rows, "Bulk returns truthy success");
};

$schema->disconnect;

done_testing;

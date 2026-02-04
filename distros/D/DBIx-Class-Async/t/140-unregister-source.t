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

subtest "Unregistration and Cleanup" => sub {
    # 1. Verify existence (assuming 'User' is in TestSchema)
    ok($schema->source('User'), "User source initially exists");

    # 2. Unregister
    $schema->unregister_source('User');

    # 3. Verify it's gone from the Parent's perspective
    my $rs = eval { $schema->resultset('User') };
    ok(!$rs, "resultset('User') fails after unregistration");
    like($@, qr/Can't find source/, "Error message confirms source is gone");
};

$schema->disconnect;

done_testing;

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

my $expected_workers = 2;

my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    {
        workers      => $expected_workers,
        schema_class => 'TestSchema',
        async_loop   => $loop,
        cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

subtest 'Worker Health Check' => sub {
    my $healthy_workers = eval { $schema->health_check->get };

    if ($@) {
        fail("health_check died with error: $@");
    }
    else {
        is($healthy_workers, $expected_workers, "All $expected_workers configured workers are healthy");
        cmp_ok($healthy_workers, '>', 0, 'At least one worker is alive');
    }
};

subtest 'Health Stability' => sub {
    $schema->resultset('User')->create({ name => 'HealthCheckUser', email => 'hc@test.com' })->get;

    my $after_query_health = $schema->health_check->get;
    is($after_query_health, $expected_workers, 'Workers remain healthy after database operations');
};

$schema->disconnect;

done_testing;

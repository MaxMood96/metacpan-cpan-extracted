#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';

use IO::Async::Loop;
use DBIx::Class::Async::Schema;

my $dsn          = "dbi:SQLite:dbname=:memory:";
my $schema_class = "TestSchema";

subtest "Implicit Loop (The Smart Default)" => sub {
    my $schema = DBIx::Class::Async::Schema->connect(
        $dsn, '', '', {},
        {
            schema_class => $schema_class,
            workers      => 2
        }
    );

    # Accessing the internal engine state
    my $db_engine = $schema->{_async_db};

    ok($db_engine, "Schema has internal _async_db state");
    ok($db_engine->{_loop}, "Internal loop was automatically initialized");
    isa_ok($db_engine->{_loop}, 'IO::Async::Loop');

    is(scalar @{$db_engine->{_workers}}, 2, "Internal loop is managing 2 workers");

    $schema->disconnect;
};

subtest "Explicit Loop (The Injection Pattern)" => sub {
    my $existing_loop = IO::Async::Loop->new;

    my $schema = DBIx::Class::Async::Schema->connect(
        $dsn, '', '', {},
        {
            schema_class => $schema_class,
            workers      => 2,
            loop         => $existing_loop
        }
    );

    my $db_engine = $schema->{_async_db};

    is($db_engine->{_loop}, $existing_loop, "Schema adopted the user-supplied loop");

    # Heartbeat check
    my $tick = 0;
    $existing_loop->add(
        IO::Async::Timer::Countdown->new(
            delay => 0.01,
            on_expire => sub { $tick++ },
        )->start
    );

    $existing_loop->loop_once(0.1);
    is($tick, 1, "Shared loop is still processing external events");

    $schema->disconnect;
};

done_testing;

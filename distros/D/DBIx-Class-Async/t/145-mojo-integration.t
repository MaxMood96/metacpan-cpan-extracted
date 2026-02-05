#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';

eval { require Mojo::IOLoop; require IO::Async::Loop::Mojo; 1 }
    or plan skip_all => "Mojo::IOLoop and IO::Async::Loop::Mojo required for this test";

use Mojo::IOLoop;
use DBIx::Class::Async::Schema;

my $dsn          = "dbi:SQLite:dbname=:memory:";
my $schema_class = "TestSchema";

subtest "Integration: Sharing the Mojo Heartbeat" => sub {
    # 1. Create the Mojo-backed IO::Async loop
    # This loop is a "guest" inside Mojo's IOLoop
    my $mojo_bridge = IO::Async::Loop::Mojo->new();

    # 2. Connect the Schema using this bridge
    my $schema = DBIx::Class::Async::Schema->connect(
        $dsn, '', '', {},
        {
            schema_class => $schema_class,
            workers      => 2,
            loop         => $mojo_bridge
        }
    );

    my $db_engine = $schema->{_async_db};

    # 3. Verify Integration
    is($db_engine->{_loop}, $mojo_bridge, "Bridge adopted the Mojo-backed loop");
    isa_ok($db_engine->{_loop}, 'IO::Async::Loop::Mojo');

    # 4. THE REAL TEST: Run the Mojo Loop and check for concurrency
    my $mojo_tick = 0;
    Mojo::IOLoop->timer(0.01 => sub { $mojo_tick++ });

    # We use Mojo's own loop control to process events
    # This proves DBIC::Async isn't "hijacking" the loop
    Mojo::IOLoop->one_tick;

    ok($mojo_tick > 0, "Mojo's native timer fired while DBIC::Async was attached");
    is(scalar @{$db_engine->{_workers}}, 2, "Workers are successfully parked on the Mojo loop");

    $schema->disconnect;
};

done_testing;

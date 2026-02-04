#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use Test::Exception;
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

subtest "Verify Active Connection" => sub {
    ok($schema->{_async_db}, "Internal async_db manager is initialized");

    # Perform a quick operation to ensure workers are alive
    my $rs = $schema->resultset('User');
    isa_ok($rs, 'DBIx::Class::Async::ResultSet');

    # Ensure metadata cache is populated
    my $class = $schema->class('User');
    ok($class, "Metadata cache is populated (Class: $class)");
    ok(keys %{$schema->{_sources_cache}}, "Sources cache is not empty");
};

subtest "Execution of disconnect()" => sub {
    # We call the method we just ported
    eval { $schema->disconnect };
    ok(!$@, "disconnect() executed without errors") or diag $@;

    # 1. Check reference cleanup
    ok(!exists $schema->{_async_db}, "Internal _async_db reference was deleted");

    # 2. Check metadata cleanup
    # (Assuming your disconnect clears the cache as suggested)
    is(scalar keys %{$schema->{_sources_cache} // {}}, 0, "Metadata sources cache was cleared");
};

subtest "Post-disconnect Behavior" => sub {
    # Attempting to use the schema after disconnect should fail gracefully
    # because the worker pool is gone.
    eval { $schema->resultset('User')->all_future->get };

    ok($@, "Operations fail after disconnect (as expected)");
    like($@, qr/async_db|disconnected|undef|Schema class not found/i,
         "Error message correctly identifies missing connection");
};

$schema->disconnect;

done_testing;

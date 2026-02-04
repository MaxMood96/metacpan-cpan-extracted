#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use lib 't/lib';

use TestSchema;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $dsn            = "dbi:SQLite:dbname=$db_file";

# Deploy schema
my $base_schema = TestSchema->connect($dsn);
$base_schema->deploy;
$base_schema->resultset('User')->create({ name => 'Original', email => 'orig@test.com' });

# 2. Create the parent Async Schema
my $schema = DBIx::Class::Async::Schema->connect($dsn, {
    schema_class => 'TestSchema',
    async_loop   => $loop,
    workers      => 1,
});

subtest 'Storage Alignment' => sub {
    my $clone = $schema->clone;

    # 1. Use the method call schema() instead of the hash key {schema}
    is($clone->storage->schema, $clone, 'Clone storage points to cloned schema');

    # 2. Verify that the storage itself is a new instance
    isnt($clone->storage, $schema->storage, 'Clone has its own storage instance');

    #done_testing;
};

subtest 'Basic Cloning Integrity' => sub {
    my $clone = $schema->clone(workers => 2);

    isa_ok($clone, 'DBIx::Class::Async::Schema');
    isnt($clone, $schema, 'Clone is a different object reference');
    is($clone->schema_class, $schema->schema_class, 'Schema class is preserved');

    # Verify worker counts are independent
    is($schema->{_async_db}->{_workers_config}->{_count}, 1, 'Original keeps 1 worker');
    is($clone->{_async_db}->{_workers_config}->{_count}, 2, 'Clone has 2 workers');
};

subtest 'Functional Independence' => sub {
    my $clone = $schema->clone(workers => 1);
    ok($clone->{_async_db} != $schema->{_async_db}, 'Internal engines are distinct');

    # 1. Fire the query
    my $future = $clone->resultset('User')->search_future({ name => 'Original' });

    # 2. Block until the worker responds
    $loop->await($future);

    # 3. CRITICAL: Extract the payload (an arrayref of objects)
    my ($data) = $future->get;
    my @results = (ref $data eq 'ARRAY') ? @$data : ($data);

    ok(scalar @results > 0, 'Clone can perform queries successfully');

    # 4. Access the row data
    if (@results) {
        is($results[0]->name, 'Original', 'Data retrieved via clone is correct');
    }

    #done_testing;
};

subtest 'Storage Alignment' => sub {

    my $clone = $schema->clone(); # Keep the clone alive in this scope
    is($clone->storage->schema, $clone, 'Clone storage points to cloned schema');
    isnt($clone->storage, $schema->storage, 'Clone has its own storage instance');
};

$schema->disconnect;

done_testing;

#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use lib 't/lib';

eval { require Test::DBIx::Class; 1 }
    or plan skip_all => "Test::DBIx::Class required";

eval { require Test::PostgreSQL::v2; 1 }
    or plan skip_all => "Test::PostgreSQL::v2 required";

use Test::DBIx::Class {
    schema_class => 'MySchema',
    traits       => ['Testpostgresqlv2'],
    deploy_db    => 1,
}, 'Item';

ok(Schema(), "Schema deployed successfully on v2 instance");

my $it = eval { ResultSet('Item')->create({ name => 'Test Item' }) };

if ($@) {
    fail("Create failed: $@");
} else {
    ok($it && $it->id, "Successfully created an item in Postgres v2");
}

done_testing;

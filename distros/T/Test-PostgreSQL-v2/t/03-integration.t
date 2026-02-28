#!/usr/bin/env perl

use strict;
use warnings;

use lib 't/lib';

use Test::More;

eval { require Test::DBIx::Class; 1 }
    or plan skip_all => "Test::DBIx::Class required";

eval { require Test::PostgreSQL::v2; 1 }
    or plan skip_all => "Test::PostgreSQL::v2 required";

eval { require DBD::Pg; 1 }
    or plan skip_all => "DBD::Pg required";

use Test::DBIx::Class {
    schema_class => 'MySchema',
    traits       => ['Testpostgresqlv2'],
    deploy_db    => 1,
}, 'Item';

ok(__PACKAGE__->can('Schema'), "Test::DBIx::Class successfully initialised");

my $rs = ResultSet('Item');
ok($rs, "Got ResultSet using Testpostgresqlv2 trait");

my $row = eval { $rs->create({ name => 'Integration Test' }) };
if ($@) {
    fail("Create failed: $@");
} else {
    is($row->name, 'Integration Test', "Data persisted through v2 engine");
}

done_testing;

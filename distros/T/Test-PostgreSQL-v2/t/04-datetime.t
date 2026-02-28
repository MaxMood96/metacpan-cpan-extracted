#!/usr/bin/env perl

use strict;
use warnings;

use lib 't/lib';

use Test::More;
use DateTime;

eval { require Test::DBIx::Class; 1 }
    or plan skip_all => "Test::DBIx::Class required";

eval { require Test::PostgreSQL::v2; 1 }
    or plan skip_all => "Test::PostgreSQL::v2 required";

use Test::DBIx::Class {
    schema_class => 'MySchema',
    traits       => ['Testpostgresqlv2'],
    deploy_db    => 1,
}, 'Item';

subtest 'Real DateTime Round-trip' => sub {
    my $dt = DateTime->new(
        year      => 2026,
        month     => 2,
        day       => 27,
        hour      => 10,
        minute    => 0,
        second    => 0,
        time_zone => 'Europe/London',
    );

    my $row = ResultSet('Item')->create({
        name       => 'Formatter Test',
        created_at => $dt,
    });

    ok($row->id, "Row inserted into real Postgres with ID " . $row->id);

    my $fresh_row = Item->find($row->id);

    isa_ok($fresh_row->created_at, 'DateTime', "Retrieved column inflated back to DateTime");
    is($fresh_row->created_at->year, 2026, "Year preserved");
    is($fresh_row->created_at->hour, 10, "Hour preserved (via Europe/London inflation)");
};

done_testing;

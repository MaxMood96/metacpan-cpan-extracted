#!/usr/bin/perl
use strict;
use warnings;

use lib './lib';

use Test::More;

use Yote::SQLObjectStore::TableManager;
use Yote::SQLObjectStore::SQLite::TableManager;
use Yote::SQLObjectStore::MariaDB::TableManager;
use Yote::SQLObjectStore::Postgres::TableManager;

# map_type only uses $self for method dispatch, so a bare blessed hash suffices.
my $base     = bless {}, 'Yote::SQLObjectStore::TableManager';
my $sqlite   = bless {}, 'Yote::SQLObjectStore::SQLite::TableManager';
my $mariadb  = bless {}, 'Yote::SQLObjectStore::MariaDB::TableManager';
my $postgres = bless {}, 'Yote::SQLObjectStore::Postgres::TableManager';

# ---- input types to test ----
my @types = (
    'TEXT',
    'VARCHAR(128)',
    'INTEGER',
    'BIGINT',
    'SMALLINT',
    'FLOAT',
    'DOUBLE',
    'DECIMAL(10,2)',
    'BOOLEAN',
    'BLOB',
    'TIMESTAMP',
    'DATE',
);

# ---- expected mappings per backend ----
my %expect = (
    base => {
        'TEXT'          => 'TEXT',
        'VARCHAR(128)'  => 'VARCHAR(128)',
        'INTEGER'       => 'INTEGER',
        'BIGINT'        => 'BIGINT',
        'SMALLINT'      => 'SMALLINT',
        'FLOAT'         => 'FLOAT',
        'DOUBLE'        => 'DOUBLE',
        'DECIMAL(10,2)' => 'DECIMAL(10,2)',
        'BOOLEAN'       => 'BOOLEAN',
        'BLOB'          => 'BLOB',
        'TIMESTAMP'     => 'TIMESTAMP',
        'DATE'          => 'DATE',
    },
    sqlite => {
        'TEXT'          => 'TEXT',
        'VARCHAR(128)'  => 'VARCHAR(128)',
        'INTEGER'       => 'INTEGER',
        'BIGINT'        => 'INTEGER',
        'SMALLINT'      => 'INTEGER',
        'FLOAT'         => 'REAL',
        'DOUBLE'        => 'REAL',
        'DECIMAL(10,2)' => 'NUMERIC',
        'BOOLEAN'       => 'INTEGER',
        'BLOB'          => 'BLOB',
        'TIMESTAMP'     => 'TEXT',
        'DATE'          => 'TEXT',
    },
    mariadb => {
        'TEXT'          => 'TEXT',
        'VARCHAR(128)'  => 'VARCHAR(128)',
        'INTEGER'       => 'INT',
        'BIGINT'        => 'BIGINT',
        'SMALLINT'      => 'SMALLINT',
        'FLOAT'         => 'FLOAT',
        'DOUBLE'        => 'DOUBLE',
        'DECIMAL(10,2)' => 'DECIMAL(10,2)',
        'BOOLEAN'       => 'TINYINT(1)',
        'BLOB'          => 'BLOB',
        'TIMESTAMP'     => 'TIMESTAMP',
        'DATE'          => 'DATE',
    },
    postgres => {
        'TEXT'          => 'TEXT',
        'VARCHAR(128)'  => 'VARCHAR(128)',
        'INTEGER'       => 'INTEGER',
        'BIGINT'        => 'BIGINT',
        'SMALLINT'      => 'SMALLINT',
        'FLOAT'         => 'REAL',
        'DOUBLE'        => 'DOUBLE PRECISION',
        'DECIMAL(10,2)' => 'DECIMAL(10,2)',
        'BOOLEAN'       => 'BOOLEAN',
        'BLOB'          => 'BYTEA',
        'TIMESTAMP'     => 'TIMESTAMP',
        'DATE'          => 'DATE',
    },
);

my %instances = (
    base     => $base,
    sqlite   => $sqlite,
    mariadb  => $mariadb,
    postgres => $postgres,
);

for my $backend (sort keys %instances) {
    subtest "$backend map_type" => sub {
        my $tm = $instances{$backend};
        for my $type (@types) {
            my $got      = $tm->map_type($type);
            my $expected = $expect{$backend}{$type};
            is($got, $expected, "$type -> $expected");
        }
    };
}

done_testing;

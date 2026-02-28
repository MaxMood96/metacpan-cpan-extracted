#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::PostgreSQL::v2;

use DBI;

my $pg = eval { Test::PostgreSQL::v2->new() };
ok($pg, "Created a modern Postgres instance");
isa_ok($pg, 'Test::PostgreSQL::v2');

my $dsn = $pg->dsn;
like($dsn, qr/port=\d+/, "DSN contains a port");

my $dbh = DBI->connect($dsn, $pg->{user}, '', { RaiseError => 1, PrintError => 0 });
ok($dbh, "Connected to the instance via DBI");

my $val = $dbh->selectrow_array("SELECT 1+1");
is($val, 2, "Database performs simple arithmetic");

my $user = $dbh->selectrow_array("SELECT current_user");
is($user, $pg->{user}, "Running as correct user: " . $pg->{user});

$dbh->disconnect;

done_testing;

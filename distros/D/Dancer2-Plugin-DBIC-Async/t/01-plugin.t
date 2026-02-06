#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);

use DBI;
use IO::Async::Loop;
use lib 't/lib';

my $dir     = tempdir(CLEANUP => 1);
my $db_file = catfile($dir, 'test.db');
my $dbh     = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1,
    AutoCommit => 1,
});

$dbh->do(q{
    CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
    )
});

$dbh->do(q{ INSERT INTO users (name) VALUES ('Alice') });
$dbh->do(q{ INSERT INTO users (name) VALUES ('Bob') });
$dbh->do(q{ INSERT INTO users (name) VALUES ('Charlie') });
$dbh->disconnect;

require_ok('Test::Schema');
require_ok('DBIx::Class::Async::Schema');

my $loop   = IO::Async::Loop->new;
my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file",
    '',
    '',
    { sqlite_unicode => 1 },
    {
        schema_class => 'Test::Schema',
        workers      => 2,
        loop         => $loop,
    }
);

my $async = $schema;

subtest 'Count' => sub {
    my $count = $schema->resultset('User')->count->get;
    is($count, 3, 'Count returns 3 users via ResultSet proxy');
};

subtest 'Find' => sub {
    my $user = $schema->resultset('User')->find(1)->get;
    ok($user, 'Find returns a user');

    isa_ok($user, 'DBIx::Class::Async::Anon::Test_Schema_Result_User');

    is($user->{name}, 'Alice', 'Found user is Alice via hash access');

    is($user->name, 'Alice', 'Found user is Alice via accessor');
};

subtest 'Search' => sub {
    my $users = $schema->resultset('User')->search({ name => 'Bob' })->all->get;
    is($users->[0]{name}, 'Bob', 'Search finds Bob');
};

subtest 'Create' => sub {
    my $result = $schema->resultset('User')->create({ name => 'David' })->get;
    ok($result, 'Create succeeded');
    is($result->{name}, 'David', 'Created user name matches');

    my $count = $schema->resultset('User')->count->get;
    is($count, 4, 'Count increased to 4');
};

subtest 'Update' => sub {
    my $result = $schema->resultset('User')->search({ id => 1 })->update({ name => 'Alice Updated' })->get;
    ok($result, 'Update command succeeded');

    my $user = $schema->resultset('User')->find(1)->get;
    is($user->{name}, 'Alice Updated', 'User was updated in the DB');
};

subtest 'Delete' => sub {
    my $result = $schema->resultset('User')->search({ id => 2 })->delete->get;
    ok($result, 'Delete command succeeded');

    my $count = $schema->resultset('User')->count->get;
    is($count, 3, 'Count decreased to 3');
};

$schema->storage->disconnect if $schema->storage->can('disconnect');

done_testing;

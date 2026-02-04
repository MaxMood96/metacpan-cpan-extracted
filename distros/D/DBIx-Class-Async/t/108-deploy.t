#!/usr/bin/env perl

use strict;
use warnings;

use Try::Tiny;
use File::Temp;
use Test::More;

use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

use TestSchema;

my $loop               = IO::Async::Loop->new;
my ($fh, $db_filename) = File::Temp::tempfile(UNLINK => 1);
my $dsn                = "dbi:SQLite:dbname=$db_filename";
my $schema             = DBIx::Class::Async::Schema->connect($dsn, {
    schema_class => 'TestSchema',
    async_loop   => $loop,
    workers      => 1,
});

subtest "Async Deployment with Temp File" => sub {
    my $rs = $schema->resultset('User');
    my $f  = $rs->all;
    my $sql_error = 'NONE';

    my $res;
    try {
        $res = $loop->await($f);

        # Check if it's a Future
        if (Scalar::Util::blessed($res) && $res->isa('Future')) {
            if ($res->is_failed) {
                $sql_error = ($res->failure)[0];
            } elsif ($res->is_done) {
                my @values = $res->get;
            }
        }
    }
    catch {
        $sql_error = $_;
    };

    ok($sql_error ne 'NONE', "Caught expected error before deployment");
    like($sql_error, qr/no such table/i, "SQL error confirmed");


    # 2. PERFORM DEPLOYMENT
    my $deploy_res;
    try {
        $deploy_res = $loop->await($schema->deploy);

        # Handle nested Future for deploy
        if (Scalar::Util::blessed($deploy_res) && $deploy_res->can('get')) {
            if ($deploy_res->is_ready && $deploy_res->is_done) {
                $deploy_res = ($deploy_res->get)[0];
            }
        }
    }
    catch {
        fail("Deploy failed: $_");
    };

    ok($deploy_res->{success}, "Deployment command executed successfully");

    # 3. VERIFY SUCCESS
    my $after_res;
    try {
        $after_res = $loop->await($rs->all);

        # Handle nested Future
        if (Scalar::Util::blessed($after_res) && $after_res->can('get')) {
            if ($after_res->is_ready && $after_res->is_done) {
                $after_res = ($after_res->get)[0];
            }
        }
    }
    catch {
        fail("Query failed: $_");
    };

    is(ref($after_res), 'ARRAY', "Search results is an ARRAY reference");
    is(scalar @$after_res, 0, "Database table exists and is empty");
};

$schema->disconnect;

done_testing;

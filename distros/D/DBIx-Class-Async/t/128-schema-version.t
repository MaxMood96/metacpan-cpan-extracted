#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

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

# Ensure TestSchema has a version for this test
{
    package TestSchema;
    use base 'DBIx::Class::Schema';
    our $VERSION = '1.2.3';
}

subtest "Schema Version Introspection" => sub {
    my $version = eval { $schema->schema_version };
    ok(!$@, "schema_version() executed without error") or diag $@;

    is($version, '1.2.3', "Correctly retrieved version from TestSchema");
};

subtest "Error Handling" => sub {
    local $schema->{_async_db}->{_schema_class} = undef;

    eval { $schema->schema_version };
    my $err = $@;

    like($err, qr/schema_class is not defined/, "Throws error when nested class is missing");
};

$schema->disconnect;

done_testing;

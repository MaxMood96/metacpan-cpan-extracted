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

my $rs = $schema->resultset('User');

subtest 'Validation of new_result via Async Engine' => sub {
    ok(ref($rs->{_async_db}) eq 'HASH', 'ResultSet contains the _async_db hashref');

    my $raw_data = {
        id    => 1,
        name  => 'Alice',
        email => 'alice@example.com'
    };

    my $row = $rs->new_result($raw_data, { in_storage => 1 });

    ok($row, 'new_result returned an object');
    isa_ok($row, 'DBIx::Class::Async::Row', 'Inherits from Async::Row base');
    isa_ok($row, 'TestSchema::Result::User', 'Inherits from real Result class');

    my $class_name = ref($row);
    like($class_name, qr/^DBIx::Class::Async::Anon::/, "Class hijacked to unique namespace: $class_name");

    is($row->id, 1, 'Data integrity: id is correct');
    is($row->name, 'Alice', 'Data integrity: name is correct');

    ok($row->in_storage, 'Row is correctly marked as in_storage');
};

$schema->disconnect;

done_testing;

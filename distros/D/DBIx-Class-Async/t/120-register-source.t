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

subtest "Dynamic Registration Metadata" => sub {
    my $source = DBIx::Class::ResultSource->new({ name => 'temp_table' });
    $source->add_columns( id => { data_type => 'integer' } );
    $source->result_class('TestSchema::Result::User');

    $schema->register_source('DynamicSource', $source);

    my $rs = eval { $schema->resultset('DynamicSource') };
    ok($rs, "Parent created ResultSet for DynamicSource") or diag $@;

    is($schema->class('DynamicSource'), 'TestSchema::Result::User',
       "Parent maps DynamicSource to correct Result Class");
};

$schema->disconnect;

done_testing;

#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile( UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

subtest 'ResultSet update_or_create logic' => sub {
    my $rs = $schema->resultset('User');
    my $unique_email = 'uoc_test@example.com';

    my $created = $rs->update_or_create({
        email => $unique_email,
        name  => 'Initial'
    })->get;

    ok($created->id, 'Created new row with ID');
    is($created->in_storage, 1, 'Row is in storage');

    my $updated = $rs->update_or_create({
        email => $unique_email,
        name  => 'Revised'
    })->get;

    is($updated->id, $created->id, 'Identified and updated the same row');
    is($updated->name, 'Revised', 'Data updated correctly');

    my $conflict_future = $rs->create({ email => 'conflict@test.com', name => 'First' })
        ->then(sub {
            # Try to create it again - this SHOULD trigger the race recovery catch
            return $rs->update_or_create({ email => 'conflict@test.com', name => 'Second' });
        });

    my $recovered = $conflict_future->get;
    is($recovered->name, 'Second', 'Race recovery successful: caught conflict and updated');
};

$schema->disconnect;

done_testing;

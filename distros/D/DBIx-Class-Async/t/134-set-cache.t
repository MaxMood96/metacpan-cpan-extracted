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

subtest 'set_cache with raw data' => sub {
    my $rs = $schema->resultset('User');

    # Simulate data that might have come from a manual JSON import or Prefetch
    my $raw_data = [
        { id => 999, name => 'Cache Test User', age => 50 }
    ];

    $rs->set_cache($raw_data);

    ok($rs->{_is_prefetched}, "ResultSet marked as prefetched");
    is($rs->{_entries}, $raw_data, "Raw data stored in _entries");

    # Trigger all() - this should use lines 129-138 of your all() method
    my $results = $schema->await($rs->all);

    is(scalar @$results, 1, "Returned 1 row");
    isa_ok($results->[0], 'TestSchema::Result::User', "Raw hash was inflated into a Result object");
    is($results->[0]->name, 'Cache Test User', "Attribute 'name' is correct");

    # Verify that it didn't hit the worker (no 'all' STAGE logs should appear in console)
};

subtest 'set_cache with objects' => sub {
    my $rs = $schema->resultset('User');

    # Create a real object via the native schema for the sake of the test
    my $user_obj = $schema->resultset('User')->new_result({
        id => 888,
        name => 'Existing Object'
    });

    $rs->set_cache([ $user_obj ]);

    my $results = $schema->await($rs->all);

    is($results->[0], $user_obj, "all() returned the exact same object instance");
    is($results->[0]->id, 888, "Object state preserved");
};

subtest 'set_cache resets position' => sub {
    my $rs = $schema->resultset('User');

    $rs->set_cache([ { name => 'User A' } ]);
    $schema->await($rs->all);

    $rs->{_pos} = 1;

    $rs->set_cache([ { name => 'User B' } ]);

    is($rs->{_pos}, 0, "set_cache reset the resultset position to 0");

    my $results = $schema->await($rs->all);
    is($results->[0]->name, 'User B', "New cache successfully replaced old data");
};

$schema->disconnect;

done_testing;

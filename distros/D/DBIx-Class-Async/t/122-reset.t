#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use lib 't/lib';

use TestSchema;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

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

subtest 'ResultSet pointer reset' => sub {
    my $rs = $schema->resultset('User');

    # 1. Manually seed cache with 3 items
    $rs->set_cache([
        { id => 1, name => 'Alice' },
        { id => 2, name => 'Bob'   },
        { id => 3, name => 'Charlie' }
    ]);

    # 2. Inflate the rows
    my $results = $schema->await($rs->all);
    is(scalar @$results, 3, "Inflated 3 rows");

    # 3. Simulate iterating through the results
    $rs->{_pos} = 3;
    is($rs->{_pos}, 3, "Pointer moved to the end of the set");

    # 4. Call reset()
    my $returned_rs = $rs->reset;

    # 5. Verify
    is($rs->{_pos}, 0, "reset() moved the pointer back to 0");
    isa_ok($returned_rs, 'DBIx::Class::Async::ResultSet', "reset() returns self for chaining");

    # 6. Verify data accessibility after reset
    my $first_again = $rs->{_rows}->[$rs->{_pos}];
    is($first_again->name, 'Alice', "Data is still available and correct after reset");
};

$schema->disconnect;

done_testing;

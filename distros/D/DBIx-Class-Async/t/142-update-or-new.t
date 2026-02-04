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

$schema->resultset('User')->create({
    id    => 1,
    name  => 'BottomUp User',
    email => 'bu@test.com'
})->get;

subtest 'Debug Lookup' => sub {
    my $rs = $schema->resultset('User');
    my $data = { 'me.email' => 'test@test.com', name => 'Foo' };

    my $lookup = $rs->_extract_unique_lookup($data, {});

    # If this shows the whole hash instead of just { email => ... },
    # the alias-aware fix above is required.

    ok(exists $lookup->{email}, "Lookup contains the unique column");
    ok(!exists $lookup->{'me.email'}, "Lookup cleaned the alias");
};

subtest 'ResultSet update_or_new logic' => sub {
    my $rs = $schema->resultset('User');
    my $email = 'new_test@example.com';

    # 1. Test the "New" path
    my $new_row = $rs->update_or_new({
        'me.email' => $email,
        'name'     => 'Local Ghost'
    })->get;

    isa_ok($new_row, 'DBIx::Class::Async::Row');
    is($new_row->in_storage, 0, 'New row is NOT in storage yet');
    is($new_row->email, $email, 'Key alias "me." was cleaned correctly');
    is($new_row->name, 'Local Ghost', 'Data populated correctly');

    # 2. Test the "Update" path
    # First, save a record to find later
    my $stored = $rs->create({ email => 'stored@example.com', name => 'Stored' })->get;

    my $updated_row = $rs->update_or_new({
        email => 'stored@example.com',
        name  => 'Changed'
    })->get;

    is($updated_row->id, $stored->id, 'Found existing record');
    is($updated_row->name, 'Changed', 'Update triggered on found row');
    is($updated_row->in_storage, 1, 'Updated row is in storage');
};

$schema->disconnect;

done_testing;

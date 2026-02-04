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
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

subtest 'Row: discard_changes' => sub {
    my $id = 100;
    $schema->resultset('User')->create({
        id    => $id,
        name  => 'Original Name',
        email => 'old@test.com'
    })->get;

    # Fetch the row we want to test
    my $row = $schema->resultset('User')->find($id)->get;
    is($row->name, 'Original Name', 'Initial load is correct');

    # Update via a separate path to make the local $row stale
    $schema->resultset('User')->search({ id => $id })->update({
        name => 'New Remote Name'
    })->get;

    is($row->name, 'Original Name', 'Local row object is now officially stale');

    # Modify local row (dirty it)
    $row->email('temporary@change.com');
    ok($row->{_dirty}{email}, 'Row is locally dirty before discard');

    # Trigger discard_changes
    my $f = $row->discard_changes;
    isa_ok($f, 'Future', 'discard_changes returns a Future');

    my $returned_obj = $f->get;
    is($returned_obj, $row, 'discard_changes returns self');

    # Verifications
    is($row->name, 'New Remote Name', 'Name refreshed from database');
    is($row->email, 'old@test.com', 'Local dirty changes were reverted');
    is_deeply($row->{_dirty}, {}, 'Dirty flags were cleared');
};

subtest 'Row: discard_changes (Row Vanished)' => sub {
    my $id = 200;
    $schema->resultset('User')->create({
        id    => $id,
        name  => 'Ghost User',
        email => 'ghost@test.com'
    })->get;

    my $row = $schema->resultset('User')->find($id)->get;
    ok($row, 'Fetched row successfully');

    # FIX: Get the row before calling delete
    $schema->resultset('User')->find($id)->get->delete->get;

    my $f = $row->discard_changes;

    my $failed = 0;
    $f->on_fail(sub {
        my ($error) = @_;
        like($error, qr/Row vanished/i, 'Caught expected "Row vanished" error');
        $failed = 1;
    });

    # Catch the exception from ->get on a failed Future
    eval { $f->get };

    ok($failed, 'Future correctly failed when row was missing');
};

$schema->disconnect;

done_testing;

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

subtest 'Row Object update() - Existing Record' => sub {
    my $rs = $schema->resultset('User');

    my $user = $rs->create({ name => 'Original Name', email => 'orig@test.com' })->get;
    my $id = $user->id;

    $user->name('Updated Name');

    if ($user->can('get_dirty_columns')) {
        my %dirty = $user->get_dirty_columns;
        ok(exists $dirty{name}, 'Column "name" marked as dirty before update');
    }

    my $returned_user = $user->update->get;

    is($returned_user->name, 'Updated Name', 'Returned object has new name');
    is($user->name, 'Updated Name', 'Original object updated in-place');

    if ($user->can('get_dirty_columns')) {
        my %dirty = $user->get_dirty_columns;
        is(keys %dirty, 0, 'Dirty flags cleared after success');
    }

    my $db_check = $rs->find($id)->get;
    is($db_check->name, 'Updated Name', 'Database reflects change');
};

subtest 'Row Object update_or_insert() - New Record' => sub {
    my $rs = $schema->resultset('User');

    my $new_user = $rs->new_result({ name => 'New User', email => 'new@test.com' });
    is($new_user->in_storage, 0, 'New object starts with in_storage = 0');

    $new_user->update_or_insert->get;

    ok($new_user->id, 'Object now has an auto-incremented ID: ' . $new_user->id);
    is($new_user->in_storage, 1, 'Object now marked as in_storage');

    my $db_check = $rs->find($new_user->id)->get;
    ok($db_check, 'Found the newly inserted record in DB');
};

subtest 'Row Object update() - No Changes' => sub {
    my $user = $schema->resultset('User')->search({}, {rows => 1})->single->get;

    my $f = $user->update;

    isa_ok($f, 'Future');
    my $res = $f->get;
    is($res, $user, 'Update with no changes returns the object immediately');
};

$schema->disconnect;

done_testing;

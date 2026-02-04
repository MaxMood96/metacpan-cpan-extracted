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

my $email_counter = 0;
sub unique_email {
    return 'test' . $email_counter++ . '@example.com';
}

subtest 'update_or_insert - insert when not in storage' => sub {
    my $user = $schema->resultset('User')
                      ->new_result({
                        name  => 'New User',
                        email => unique_email(),
                      });

    ok(!$user->in_storage, 'Row is not in storage initially');

    my $result = $user->update_or_insert({
        name  => 'New User',
        email => $user->get_column('email') // unique_email(),
    })->get;

    ok(defined $result->id, 'Result has an ID');
    is($result->get_column('name'), 'New User', 'Name is correct');
};

subtest 'update_or_insert - update when in storage' => sub {
    my $user = $schema->resultset('User')
                      ->create({
                        name  => 'Original Name',
                        email => unique_email(),
                      })->get;

    ok($user->in_storage, 'Row is in storage');
    my $original_id = $user->id;

    # Modify the user using set_column
    $user->set_column('name', 'Updated Name');

    # Call update_or_insert - should update
    my $result = $user->update_or_insert->get;

    is($result->id, $original_id, 'ID unchanged (same row)');
    is($result->get_column('name'), 'Updated Name', 'Name was updated');

    # Verify in database
    my $found = $schema->resultset('User')->find($original_id)->get;
    is($found->get_column('name'), 'Updated Name', 'Update persisted to database');
    is($found->get_column('email'), $user->get_column('email'), 'Other columns unchanged');
};

subtest 'insert_or_update - alias works for insert' => sub {
    my $user = $schema->resultset('User')
                      ->new_result({
                        name  => 'Alias Test Insert',
                        email => unique_email(),
                      });

    ok(!$user->in_storage, 'Row not in storage');

    my $result = $user->insert_or_update->get;

    ok($result->in_storage, 'Row inserted via alias');
    is($result->name, 'Alias Test Insert', 'Data correct');
};

subtest 'insert_or_update - alias works for update' => sub {
    my $user = $schema->resultset('User')
                      ->create({
                        name  => 'Alias Test Update',
                        email => unique_email(),
                      })->get;

    my $original_id = $user->id;
    $user->set_column('name', 'Updated via Alias');

    # Use the alias method
    my $result = $user->insert_or_update->get;

    is($result->id, $original_id, 'Same row updated');

    # Fetch fresh from database to verify the update persisted
    my $found = $schema->resultset('User')->find($original_id)->get;
    is($found->get_column('name'), 'Updated via Alias', 'Update persisted');
    is($found->get_column('email'), $user->get_column('email'), 'Email unchanged');
};

subtest 'Multiple update_or_insert calls' => sub {
    my $user = $schema->resultset('User')
                      ->new_result({
                        name  => 'Multi Test',
                        email => unique_email(),
                      });

    my $result1 = $user->update_or_insert->get;
    ok($result1->in_storage, 'First call inserted');
    my $id = $result1->id;

    # Second call - update
    $user->set_column('name', 'Multi Test Updated 1');
    my $result2 = $user->update_or_insert->get;
    is($result2->id, $id, 'Second call updated same row');
    is($result2->name, 'Multi Test Updated 1', 'Second update correct');

    # Third call - another update
    $user->name('Multi Test Updated 2');
    my $result3 = $user->update_or_insert->get;
    is($result3->id, $id, 'Third call updated same row');
    is($result3->name, 'Multi Test Updated 2', 'Third update correct');

    # Verify final state
    my $found = $schema->resultset('User')->find($id)->get;
    is($found->name, 'Multi Test Updated 2', 'Final state correct');
};

subtest 'update_or_insert with unique constraints' => sub {
    my $unique_email = unique_email();

    # Create user with unique email
    my $user1 = $schema->resultset('User')
                       ->create({
                            name  => 'User 1',
                            email => $unique_email,
                       })->get;

    my $user2 = $schema->resultset('User')->new_result({
        name  => 'User 2',
        email => $unique_email,
    });

    # This should fail due to unique constraint
    my $error;
    eval {
        $user2->update_or_insert->get;
    };
    $error = $@;

    ok($error, 'Insert with duplicate email fails');
    like($error, qr/UNIQUE|constraint/i, 'Error mentions unique constraint');

    $user1->name('User 1 Updated');

    my $updated = $user1->update_or_insert->get;
    is($updated->name, 'User 1 Updated', 'Update with same email works');
    is($updated->email, $unique_email, 'Email unchanged');
};

$schema->disconnect;

done_testing;

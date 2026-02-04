#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

# Helper for unique emails to avoid SQLite constraint failures
my $email_count = 0;
sub next_email { "test_" . ++$email_count . "\@example.com" }

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

my $top_email = next_email();
my $user = $schema->resultset('User')
                   ->create({
                     name  => 'Original Name',
                     email => $top_email,
                   })->get;

my $user_id = $user->id;
my $batch_email = next_email();
my @batch = (
    {
        type      => 'create',
        resultset => 'User',
        data      => { name => 'New Batch User', email => $batch_email }
    },
    {
        type      => 'update',
        resultset => 'User',
        id        => $user_id,
        data      => { name => 'Updated Name' }
    }
);

my $batch_result = $schema->txn_batch(\@batch)->get;
my $count = ref($batch_result) eq 'HASH' ? scalar(keys %$batch_result) : $batch_result;
is($count, 2, "Async db executed 2 operations.");

my $updated = $schema->resultset('User')->find($user_id)->get;
is($updated->name, 'Updated Name', "Async db update persisted.");

my $new_user = $schema->resultset('User')->find({ email => $batch_email })->get;
is($new_user->name, 'New Batch User', "Async db create persisted.");

subtest "Async schema txn_batch" => sub {
    my $sub_email = next_email();
    my $user = $schema->resultset('User')
                       ->create({
                         name  => 'Subtest Original',
                         email => $sub_email,
                       })->get;

    my $sub_user_id = $user->id;
    my $sub_batch_email = next_email();
    my @batch = (
        {
            type      => 'create',
            resultset => 'User',
            data      => { name => 'Sub Batch User', email => $sub_batch_email }
        },
        {
            type      => 'update',
            resultset => 'User',
            id        => $sub_user_id,
            data      => { name => 'Sub Updated Name' }
        }
    );

    my $res = $schema->txn_batch(\@batch)->get;
    my $c = ref($res) eq 'HASH' ? scalar(keys %$res) : $res;
    is($c, 2, "Async schema executed 2 operations.");

    my $upd = $schema->resultset('User')->find($sub_user_id)->get;
    is($upd->name, 'Sub Updated Name', "Async schema update persisted.");

    my $new = $schema->resultset('User')->find({ email => $sub_batch_email })->get;
    is($new->name, 'Sub Batch User', "Async schema create persisted.");
};

$schema->disconnect;

done_testing;

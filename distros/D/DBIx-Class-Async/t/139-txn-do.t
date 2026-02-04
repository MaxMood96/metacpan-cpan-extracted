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

subtest 'Dependent Cross-Table Transaction' => sub {
    my $txn_f = $schema->txn_do([
        {
            name      => 'new_user',
            action    => 'create',
            resultset => 'User',
            data      => { name => 'Alice', email => 'alice@example.com' }
        },
        {
            action    => 'create',
            resultset => 'Order',
            data      => {
                user_id => '$new_user.id',
                amount  => 150.00
            }
        }
    ]);

    my $inner_f = $schema->await($txn_f);
    my $res     = $inner_f;

    ok($res->{success}, "Transaction completed");

    my $search_f      = $schema->resultset('Order')->search_future({});
    my $orders        = $schema->await($search_f);
    my $user_search_f = $schema->resultset('User')->search_future({ name => 'Alice' });
    my $users         = $schema->await($user_search_f);

    is($orders->[0]{user_id}, $users->[0]{id}, "Order linked to correct User ID via register");
};

subtest 'Raw SQL String Interpolation' => sub {
    # 1. Create a user to get an ID
    # 2. Use that ID inside a raw SQL update string
    my $txn_f = $schema->txn_do([
        {
            name      => 'target_user',
            action    => 'create',
            resultset => 'User',
            data      => { name => 'Original Name', email => 'raw@test.com' }
        },
        {
            action    => 'raw',
            # We are testing if '$target_user.id' is swapped inside the SQL string
            sql       => "UPDATE users SET name = 'Modified for ID \$target_user.id' WHERE id = \$target_user.id",
        }
    ]);

    my $res = $schema->await($txn_f);
    ok($res->{success}, "Transaction with Raw SQL interpolation succeeded");

    my $search_f      = $schema->resultset('User')->search_future({ email => 'raw@test.com' });
    my $users         = $schema->await($search_f);
    my $user_id       = $users->[0]{id};
    my $expected_name = "Modified for ID $user_id";

    is($users->[0]{name}, $expected_name, "Raw SQL string was interpolated correctly with the real ID");
};

$schema->disconnect;

done_testing;

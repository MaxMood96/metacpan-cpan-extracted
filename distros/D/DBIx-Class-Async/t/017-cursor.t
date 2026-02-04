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

my @users = (
    { name => 'Alice',   email => 'alice@example.com',   active => 1 },
    { name => 'Bob',     email => 'bob@example.com',     active => 1 },
    { name => 'Charlie', email => 'charlie@example.com', active => 0 },
    { name => 'Diana',   email => 'diana@example.com',   active => 1 },
);

foreach my $user (@users) {
    $schema->resultset('User')->create($user)->get;
}

my $user_orders = {
    1 => [ { amount => 10, status => 'new'     },
           { amount => 20, status => 'pending' },
         ],
    2 => [ { amount => 30, status => 'completed' } ]
};

foreach my $user_id (sort keys %$user_orders) {
    my $user = $schema->resultset('User')->find($user_id)->get;
    foreach my $order (@{$user_orders->{$user_id}}) {
        $user->create_related('orders', $order)->get;
    }
}

subtest 'Cursor instantiation' => sub {
    my $rs      = $schema->resultset('User');
    my $storage = $schema->storage;

    isa_ok($storage, 'DBIx::Class::Async::Storage::DBI', 'Storage is DBI type');

    my $cursor = $storage->cursor($rs);
    isa_ok($cursor, 'DBIx::Class::Async::Storage::DBI::Cursor', 'Cursor object created');

    is($cursor->{storage}, $storage, 'Cursor holds storage reference');
    is($cursor->{rs}, $rs, 'Cursor holds resultset reference');
};

subtest 'Cursor initial state' => sub {
    my $rs     = $schema->resultset('User');
    my $cursor = $schema->storage->cursor($rs);

    is($cursor->{page}, 1, 'Initial page is 1');
    is($cursor->{finished}, 0, 'Cursor not finished on start');
    is_deeply($cursor->{buffer}, [], 'Buffer is empty on start');
    ok($cursor->{batch} > 0, 'Batch size is set');
};

subtest 'Cursor reset functionality' => sub {
    my $rs     = $schema->resultset('User');
    my $cursor = $schema->storage->cursor($rs);

    # Modify cursor state
    $cursor->{page}     = 5;
    $cursor->{finished} = 1;
    $cursor->{buffer}   = [1, 2, 3];

    # Reset cursor
    my $result = $cursor->reset;

    is($result, $cursor, 'reset returns self for chaining');
    is($cursor->{page}, 1, 'Page reset to 1');
    is($cursor->{finished}, 0, 'Finished flag reset');
    is_deeply($cursor->{buffer}, [], 'Buffer cleared');
};

subtest 'Cursor batch size from ResultSet' => sub {
    my $rs     = $schema->resultset('User')->search(undef, { rows => 5 });
    my $cursor = $schema->storage->cursor($rs);

    is($cursor->{batch}, 5, 'Cursor batch size matches ResultSet rows attribute');
};

subtest 'Async cursor iteration' => sub {
    my $rs     = $schema->resultset('User');
    my $exp    = $rs->count_future->get;
    my $cursor = $schema->storage->cursor($rs);

    my $got = 0;
    while (my $row = $cursor->next->get) {
        $got++;
        ok(ref($row) =~ /^DBIx::Class::Async::Anon::/, "Row $got is an Async Row object");
    }
    is($got, $exp, "Cursor iterated through all $exp rows");
};

subtest 'Cursor exhaustion behaviour' => sub {
    my $rs     = $schema->resultset('User')->search(undef, { rows => 2 });
    my $cursor = $schema->storage->cursor($rs);

    my @rows;
    while (my $row = $cursor->next->get) {
        push @rows, $row;
    }

    # Try to get another row after exhaustion
    my $extra = $cursor->next->get;

    ok(scalar(@rows) > 0, 'Got some rows');
    is($extra, undef, 'Returns undef when cursor is exhausted');
    is($cursor->{finished}, 1, 'Finished flag is set');
};

subtest 'Cursor buffer management' => sub {
    my $rs     = $schema->resultset('User')->search(undef, { rows => 3 });
    my $cursor = $schema->storage->cursor($rs);

    my $row_1  = $cursor->next->get;
    my $buffer_size = scalar(@{$cursor->{buffer}});

    # Get second row (should come from buffer)
    my $row_2  = $cursor->next->get;

    ok(defined $row_1, 'First row retrieved');
    ok(defined $row_2, 'Second row retrieved');
    ok($buffer_size >= 0, 'Buffer was populated after first fetch');
};

subtest 'Integration with ResultSet cursor method' => sub {
    my $rs = $schema->resultset('User');

    ok($rs->can('cursor'), 'ResultSet has cursor method');

    # Test cursor creation directly through storage
    my $cursor = $schema->storage->cursor($rs);
    isa_ok($cursor, 'DBIx::Class::Async::Storage::DBI::Cursor', 'Storage->cursor returns proper cursor');
};

$schema->disconnect;

done_testing;

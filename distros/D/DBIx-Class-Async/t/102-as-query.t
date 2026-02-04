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

subtest 'Basic as_query generation' => sub {
    my $rs = $schema->resultset('User')
                    ->search(
                        { name => 'Alice' },
                        { order_by => { -desc => 'email' } });

    my $query = $rs->as_query;

    isa_ok($query, 'REF', 'as_query returns a reference');

    # Structure of as_query is \[ $sql, [col1, val1], [col2, val2]... ]
    my ($sql, @binds) = @{$$query};

    like($sql, qr/SELECT/i, 'Query contains SELECT');
    like($sql, qr/FROM\s+"?user"?/i, 'Query targets user table');
    like($sql, qr/WHERE/i, 'Query contains WHERE clause');
    like($sql, qr/ORDER BY/i, 'Query contains ORDER BY');

    is(scalar @binds, 1, 'One bind parameter found');
    is($binds[0][1], 'Alice', 'Bind parameter value matches');
};

subtest 'Complex Join / Prefetch as_query' => sub {
    my $rs = $schema->resultset('Order')
                    ->search(
                        { 'user.name' => 'Bob'  },
                        { prefetch    => 'user' });

    my $query = $rs->as_query;
    my $sql = ${$$query}[0];

    like($sql, qr/JOIN/i, 'SQL contains a JOIN for prefetch');
    like($sql, qr/user/i, 'SQL mentions the user table');
};

$schema->disconnect;

done_testing;

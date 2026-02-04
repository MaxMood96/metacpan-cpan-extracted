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

subtest 'Naked next() - Lazy Loading' => sub {
    my $rs = $schema->resultset('User')->search({ id => 1 });
    $rs->{_async_db}{_stats}{_queries} = 0;

    my $row = $rs->next->get;

    ok($row, 'next() triggered a fetch on its own');
    is($row->id, 1, 'Got the correct row');
    is($rs->{_async_db}{_stats}{_queries}, 1, 'One query dispatched to worker');

    my $end = $rs->next->get;
    is($end, undef, 'End of results reached');
};

$schema->disconnect;

done_testing;

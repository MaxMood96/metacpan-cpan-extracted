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

# Setup 5 records
$schema->resultset('User')->delete_all->get;

for (1..5) {
    $schema->resultset('User')
           ->create({ id => $_, name => "User $_" })->get;
}

# Get a cursor with batch size 2
my $rs = $schema->resultset('User')
                ->search(undef, { order_by => 'id', rows => 2 });

my $cursor = $rs->cursor;

# Page 1, Row 1 (Hits DB)
my $r1 = $cursor->next->get;
is($r1->id, 1, 'First row correct');

# Page 1, Row 2 (From Buffer)
my $r2 = $cursor->next->get;
is($r2->id, 2, 'Second row from buffer');

# Page 2, Row 1 (Hits DB again for rows 3-4)
my $r3 = $cursor->next->get;
is($r3->id, 3, 'Third row (new batch) correct');

# Page 3, Row 1 (Hits DB for row 5)
$cursor->next->get; # skip 4
my $r5 = $cursor->next->get;
is($r5->id, 5, 'Final row correct');

$schema->disconnect;

done_testing;

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

# Create user
my $user = $schema->resultset('User')
                  ->create({
                    name  => 'Order User',
                    email => 'order@example.com', })
                  ->get;

# Create concurrent operations
my @futures;
foreach my $i (1..5) {
    push @futures, $schema->resultset('User')->search({}, { rows => 1 })->all;
}

# Wait for all
my @results = Future->wait_all(@futures)->get;

is(scalar @results, 5, 'all concurrent operations completed');

my $success_count = grep { $_->is_done && !$_->failure } @results;
is($success_count, 5, 'all concurrent operations succeeded');

$schema->disconnect;

done_testing;

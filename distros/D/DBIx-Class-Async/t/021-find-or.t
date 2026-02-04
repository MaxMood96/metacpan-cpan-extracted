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

my $rs = $schema->resultset('User');

$rs->create({
    name   => "ExistingUser",
    email  => "existing\@example.com",
    active => 1,
})->get;


subtest 'find_or_new logic' => sub {
    my $user_a = $rs->find_or_new({ name => 'ExistingUser' })->get;

    isa_ok($user_a, 'DBIx::Class::Async::Row');
    is($user_a->email, 'existing@example.com', 'Found existing record data');
    ok($user_a->in_storage, 'Existing record is flagged as in_storage');

    my $user_b = $rs->find_or_new({ name => 'BrandNew', email => 'new@example.com' })->get;
    is($user_b->name, 'BrandNew', 'Instantiated new object');
    ok(!$user_b->in_storage, 'New object is NOT in storage');
};

subtest 'find_or_new with ResultSet conditions' => sub {
    # If the ResultSet is restricted (e.g. active => 1),
    # find_or_new should include that in the new object.
    my $active_rs = $rs->search({ 'me.active' => 1 });

    my $user = $active_rs->find_or_new({ name => 'ConstrainedUser' })->get;

    is($user->active, 1, 'Correctly merged "me.active" into the new result object');
    ok(!$user->in_storage, 'Object ready for manual insertion');
};

subtest 'Unique Constraint handling' => sub {
     # Crucial: await/get these to ensure DB state is ready
     $schema->resultset('User')->delete_all->get;
     $schema->resultset('User')->create({
          name  => "ExistingUser",
          email => 'existing@example.com',
     })->get;

     my $f = $rs->find_or_create(
          { email => 'existing@example.com', name => 'DuplicateEmail' },
          { key   => 'user_email' }
     );

     my $user = $f->get;
     is($user->name, 'ExistingUser', 'Matched existing record');

     # FIX: Added ->get to the count call
     is($schema->resultset('User')->count->get, 1, 'No duplicate record created');
};

subtest 'find_or_create race condition' => sub {
     my $email = 'race_recovery@example.com';

     # 1. Ensure the winner is created and finished
     $schema->resultset('User')->create({ name => 'Winner', email => $email })->get;

     # 2. Call find_or_create.
     my $f = $rs->find_or_create(
          { name => 'Loser', email => $email },
          { key  => 'user_email' }
     );

     my $user;
     # Future->get will throw an exception if the future failed
     # and wasn't caught inside the ResultSet logic.
     eval { $user = $f->get; };

     if ($@) {
          fail("find_or_create died: $@");
     } else {
          ok($user, "Got a user object back from recovery");
          is($user->name, 'Winner', 'Correctly ignored "Loser" and recovered "Winner"');
     }
};

$schema->disconnect;

done_testing;

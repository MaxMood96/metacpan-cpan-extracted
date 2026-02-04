#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use Test::Exception;

use lib 't/lib';

use TestSchema;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

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

$schema->deploy({ add_drop_table => 1 })->get;

my $user = $schema->resultset('User')
                  ->create({
                    name => 'deploy_bot',
                    email=> 'bot@async.com',
                  })->get;

ok($user->id, "Table 'User' exists and record was created (ID: " .
              ($user->id // 'N/A') . ")");

$schema->unregister_source('User');

eval { $schema->resultset('User') };
like($@, qr/(?:is not registered|Can't find source for|Can't locate object method)/i,
     "Metadata remains consistent after deployment: User source is gone");

$schema->disconnect;

done_testing;

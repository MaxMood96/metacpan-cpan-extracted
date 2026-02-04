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

# 1. Test schema_version
is($schema->schema_version, $TestSchema::VERSION, 'schema_version matches TestSchema');

# 2. Verify source exists via the CLASS name
my $schema_class = $schema->{_async_db}->{_schema_class};
ok($schema_class->source('User'), 'User source exists initially in class');

# 3. Perform the unregister via your async wrapper
$schema->unregister_source('User');

# 4. Verify it's gone from the class
eval { $schema_class->source('User') };
like($@, qr/(?:is not registered|Can't find source for)/, 'User source was successfully unregistered');

$schema->disconnect;

done_testing;

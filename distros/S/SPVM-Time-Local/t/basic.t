use Test::More;

use strict;
use warnings;
use lib "t/lib";

use SPVM 'TestCase::Time::Local';
use SPVM 'Time::Local';
use SPVM::Time::Local;

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

# timelocal
{
  ok(SPVM::TestCase::Time::Local->timelocal);
}

# timegm
{
  ok(SPVM::TestCase::Time::Local->timegm);
}

# Version check
{
  my $version_string = $api->get_version_string("Time::Local");
  is($SPVM::Time::Local::VERSION, $version_string);
}

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

use Test::More;

use strict;
use warnings;
use lib "t/lib";

use SPVM 'TestCase::Time::Seconds';

use SPVM 'Time::Seconds';
use SPVM::Time::Seconds;

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

{
  ok(SPVM::TestCase::Time::Seconds->constant_values);
}

{
  ok(SPVM::TestCase::Time::Seconds->add);
}

{
  ok(SPVM::TestCase::Time::Seconds->subtract);
}

{
  ok(SPVM::TestCase::Time::Seconds->unit_methods);
}

{
  ok(SPVM::TestCase::Time::Seconds->clone);
}

{
  ok(SPVM::TestCase::Time::Seconds->pretty);
}

# Version check
{
  my $version_string = $api->get_version_string("Time::Seconds");
  is($SPVM::Time::Seconds::VERSION, $version_string);
}

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

use Test::More;

use strict;
use warnings;
use lib "t/lib";

use SPVM 'Resource::Libpng';
use SPVM::Resource::Libpng;

use SPVM 'TestCase::Resource::Libpng';

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

is(SPVM::TestCase::Resource::Libpng->test, 1);

is($SPVM::Resource::Libpng::VERSION, $api->get_version_string('Resource::Libpng'));

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

use Test::More;

use strict;
use warnings;
use lib "t/lib";

use SPVM 'Resource::RE2';
use SPVM::Resource::RE2;

use SPVM 'TestCase::Resource::RE2';

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

ok(SPVM::TestCase::Resource::RE2->test);

is($SPVM::Resource::RE2::VERSION, $api->get_version_string('Resource::RE2'));

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

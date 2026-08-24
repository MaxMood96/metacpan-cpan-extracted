use Test::More;

use strict;
use warnings;
use lib "t/lib";

use SPVM 'TestCase::Zlib';

use SPVM 'Resource::Zlib';
use SPVM::Resource::Zlib;

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

my $gz_file = "$FindBin::Bin/minitest.txt.gz";
SPVM::TestCase::Zlib->gzopen_gzread($gz_file);

ok(1);

is($SPVM::Resource::Zlib::VERSION, $api->get_version_string('Resource::Zlib'));

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

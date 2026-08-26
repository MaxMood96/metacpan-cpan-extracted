use Test::More;

use strict;
use warnings;
use lib "t/lib";

use SPVM 'Unicode::Normalize';
use SPVM::Unicode::Normalize;

use SPVM 'TestCase::Unicode::Normalize';

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

{
  ok(SPVM::TestCase::Unicode::Normalize->NFC);
  
  ok(SPVM::TestCase::Unicode::Normalize->NFD);
  
  ok(SPVM::TestCase::Unicode::Normalize->NFKC);
  
  ok(SPVM::TestCase::Unicode::Normalize->NFKD);
}

# Version
{
  is($SPVM::Unicode::Normalize::VERSION, $api->get_version_string('Unicode::Normalize'));
}

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

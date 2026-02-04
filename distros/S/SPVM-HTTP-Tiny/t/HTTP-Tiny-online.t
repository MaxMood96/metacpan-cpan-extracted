use Test::More;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
BEGIN { $ENV{SPVM_BUILD_DIR} = "$FindBin::Bin/.spvm_build"; }

use SPVM 'Fn';
use SPVM 'TestCase::HTTP::Tiny';

# Check network connectivity to httpbin.org using Perl's HTTP::Tiny
use HTTP::Tiny;
my $res = HTTP::Tiny->new(timeout => 5)->get("http://httpbin.org/get");
unless ($res->{success}) {
  plan skip_all => "No internet connection or httpbin.org is down (verified by Perl's HTTP::Tiny)";
}

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count();

ok(SPVM::TestCase::HTTP::Tiny->test);

ok(SPVM::TestCase::HTTP::Tiny->test_methods);

ok(SPVM::TestCase::HTTP::Tiny->go);

SPVM::Fn->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count();
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

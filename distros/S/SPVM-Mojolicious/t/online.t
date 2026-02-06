use Test::More;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
BEGIN { $ENV{SPVM_BUILD_DIR} = "$FindBin::Bin/.spvm_build"; }

use SPVM 'TestCase::Online';

# Check network connectivity to httpbin.org using Perl's HTTP::Tiny
use HTTP::Tiny;
my $res = HTTP::Tiny->new(timeout => 5)->get("http://httpbin.org/get");
unless ($res->{success}) {
  plan skip_all => "No internet connection or httpbin.org is down (verified by Perl's HTTP::Tiny)";
}

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count();

ok(SPVM::TestCase::Online->one_get_request);

ok(SPVM::TestCase::Online->one_get_request_https);

# TODO: redirect does not work well
# ok(SPVM::TestCase::Online->one_get_request_redirect);

ok(SPVM::TestCase::Online->test_keep_alive_no_redirect);

ok(SPVM::TestCase::Online->test_https_tiny);

ok(SPVM::TestCase::Online->test_http_tiny);

ok(SPVM::TestCase::Online->go);

$api->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count();
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

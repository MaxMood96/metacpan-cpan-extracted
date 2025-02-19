use Test::More;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib";
BEGIN { $ENV{SPVM_BUILD_DIR} = "$FindBin::Bin/.spvm_build"; }

use SPVM 'Fn';
use SPVM 'TestCase::IO::Socket::SSL::Online';

my $api = SPVM::api();

my $start_memory_blocks_count = $api->get_memory_blocks_count;

my $ok = 0;

eval { $ok = SPVM::TestCase::IO::Socket::SSL::Online->https_google };

if ($@) {
  warn "[Skip]https_google test failed. The system may be offline:$@";
}
else {
  ok($ok);
}

eval { $ok = SPVM::TestCase::IO::Socket::SSL::Online->https_google_SSL_startHandshake_false };

if ($@) {
  warn "[Skip]https_google_SSL_startHandshake_false test failed. The system may be offline:$@";
}
else {
  ok($ok);
}

eval { $ok = SPVM::TestCase::IO::Socket::SSL::Online->https_google_with_mozilla_ca };

if ($@) {
  warn "[Skip]https_google_with_mozilla_ca test failed. The system may be offline:$@";
}
else {
  ok($ok);
}

eval { $ok = SPVM::TestCase::IO::Socket::SSL::Online->https_google_with_mozilla_ca_SSL_ca_file };

if ($@) {
  warn "[Skip]https_google_with_mozilla_ca_SSL_ca_file test failed. The system may be offline:$@";
}
else {
  ok($ok);
}

$ok = SPVM::TestCase::IO::Socket::SSL::Online->https_google_with_mozilla_ca_SSL_ca_path;

if ($@) {
  warn "[Skip]https_google_with_mozilla_ca_SSL_ca_path test failed. The system may be offline:$@";
}
else {
  ok($ok);
}

SPVM::Fn->destroy_runtime_permanent_vars;

my $end_memory_blocks_count = $api->get_memory_blocks_count;
is($end_memory_blocks_count, $start_memory_blocks_count);

done_testing;

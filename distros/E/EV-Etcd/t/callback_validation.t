#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Test that callback validation works correctly
# These tests verify that passing non-coderef values as callbacks
# results in an immediate error rather than a delayed failure

BEGIN {
    eval { require EV };
    if ($@) {
        plan skip_all => 'EV module not available';
        exit;
    }
}

plan tests => 12;

use_ok('EV::Etcd');

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

ok($client, 'client created');

# Test that invalid callbacks are rejected with proper error message

# Test get with invalid callback
eval { $client->get('/test/key', 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'get rejects non-coderef callback');

# Test put with invalid callback
eval { $client->put('/test/key', 'value', 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'put rejects non-coderef callback');

# Test delete with invalid callback
eval { $client->delete('/test/key', 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'delete rejects non-coderef callback');

# Test watch with invalid callback
eval { $client->watch('/test/key', 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'watch rejects non-coderef callback');

# Test lease_grant with invalid callback
eval { $client->lease_grant(60, 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'lease_grant rejects non-coderef callback');

# Test lease_revoke with invalid callback
eval { $client->lease_revoke(12345, 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'lease_revoke rejects non-coderef callback');

# Test lease_time_to_live with invalid callback
eval { $client->lease_time_to_live(12345, 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'lease_time_to_live rejects non-coderef callback');

# Test lease_leases with invalid callback
eval { $client->lease_leases('not_a_callback'); };
like($@, qr/callback must be a code reference/, 'lease_leases rejects non-coderef callback');

# Test compact with invalid callback
eval { $client->compact(1, 'not_a_callback'); };
like($@, qr/callback must be a code reference/, 'compact rejects non-coderef callback');

# Test status with invalid callback
eval { $client->status('not_a_callback'); };
like($@, qr/callback must be a code reference/, 'status rejects non-coderef callback');

done_testing();

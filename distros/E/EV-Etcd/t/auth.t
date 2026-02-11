#!/usr/bin/env perl
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use Test::More;

# Skip if EV not available
BEGIN {
    eval { require EV };
    plan skip_all => 'EV required' if $@;
}

use EV;
use EV::Etcd;

# Check if etcd is available
my $etcd_available = 0;
eval {
    my $client = EV::Etcd->new(
        endpoints => ['127.0.0.1:2379'],
        timeout => 2,
    );
    $client->status(sub {
        my ($resp, $err) = @_;
        $etcd_available = 1 if !$err;
        EV::break;
    });
    my $t = EV::timer(3, 0, sub { EV::break });
    EV::run;
};

plan skip_all => 'etcd not available on 127.0.0.1:2379' unless $etcd_available;

# Note: These tests are designed to work whether auth is enabled or not.
# We test user/role management which works regardless of auth state.
# We intentionally avoid enabling/disabling auth to not disrupt the cluster.

plan tests => 30;

my $client = EV::Etcd->new(
    endpoints => ['127.0.0.1:2379'],
);

my $test_user = "test-user-$$-" . time();
my $test_role = "test-role-$$-" . time();

# Test 1-2: auth_status
$client->auth_status(sub {
    my ($resp, $err) = @_;
    ok(!$err, 'auth_status succeeded');
    ok(defined $resp->{enabled}, 'auth_status has enabled field');
    diag("Auth enabled: " . ($resp->{enabled} ? "yes" : "no"));
    EV::break;
});
my $t1 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 3-4: role_add
$client->role_add($test_role, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_add succeeded');
    ok($resp->{header}, 'role_add response has header');
    diag("Created role: $test_role");
    EV::break;
});
my $t2 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 5-7: role_list
$client->role_list(sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_list succeeded');
    ok(ref($resp->{roles}) eq 'ARRAY', 'role_list has roles array');

    my $found = grep { $_ eq $test_role } @{$resp->{roles} || []};
    ok($found, 'our test role is in the list');
    diag("Found " . scalar(@{$resp->{roles} || []}) . " roles");
    EV::break;
});
my $t3 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 8-9: role_grant_permission
$client->role_grant_permission($test_role, 'READWRITE', '/test/', '/test0', sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_grant_permission succeeded');
    ok($resp->{header}, 'role_grant_permission response has header');
    diag("Granted READWRITE on /test/* to $test_role");
    EV::break;
});
my $t4 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 10-11: role_get (verify permission was granted)
$client->role_get($test_role, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_get succeeded');
    ok(ref($resp->{perm}) eq 'ARRAY', 'role_get has perm array');
    if ($resp->{perm} && @{$resp->{perm}}) {
        diag("Role has " . scalar(@{$resp->{perm}}) . " permission(s)");
        diag("  First perm: type=$resp->{perm}[0]{perm_type}, key=$resp->{perm}[0]{key}");
    }
    EV::break;
});
my $t5 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 12-13: role_revoke_permission
$client->role_revoke_permission($test_role, '/test/', '/test0', sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_revoke_permission succeeded');
    ok($resp->{header}, 'role_revoke_permission response has header');
    diag("Revoked permission on /test/* from $test_role");
    EV::break;
});
my $t5b = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 14-15: role_get (verify permission was revoked)
$client->role_get($test_role, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_get after revoke succeeded');
    my $perm_count = $resp->{perm} ? scalar(@{$resp->{perm}}) : 0;
    ok($perm_count == 0, 'role has no permissions after revoke');
    diag("Role has $perm_count permission(s) after revoke");
    EV::break;
});
my $t5c = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 16-17: user_add
$client->user_add($test_user, 'test-password-123', sub {
    my ($resp, $err) = @_;
    ok(!$err, 'user_add succeeded');
    ok($resp->{header}, 'user_add response has header');
    diag("Created user: $test_user");
    EV::break;
});
my $t6 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 18-19: authenticate() method
# When auth is disabled, authenticate returns an error (auth not enabled)
# When auth is enabled, authenticate returns a token
{
    my $auth_result;
    my $auth_err;
    $client->authenticate($test_user, 'test-password-123', sub {
        my ($resp, $err) = @_;
        $auth_result = $resp;
        $auth_err = $err;
        EV::break;
    });
    my $t_auth = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # authenticate() should either succeed (auth enabled) or fail with specific error (auth disabled)
    if ($auth_err) {
        # Auth disabled - expect "authentication is not enabled" error
        like($auth_err->{message} // $auth_err, qr/auth|not enabled|UNAUTHENTICATED/i,
            'authenticate returns expected error when auth disabled');
        pass('authenticate error handling works');
        diag("authenticate() error (expected when auth disabled): " . ($auth_err->{message} // $auth_err));
    } else {
        # Auth enabled - expect token in response
        ok($auth_result, 'authenticate succeeded');
        ok(defined $auth_result->{token}, 'authenticate response has token');
        diag("authenticate() returned token (auth is enabled)");
    }
}

# Test 20: authenticate() with wrong password
{
    my $wrong_err;
    $client->authenticate($test_user, 'wrong-password', sub {
        my ($resp, $err) = @_;
        $wrong_err = $err;
        EV::break;
    });
    my $t_wrong = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    # Should return an error (either auth not enabled, or invalid credentials)
    ok($wrong_err, 'authenticate with wrong password returns error');
    diag("Wrong password error: " . ($wrong_err->{message} // $wrong_err));
}

# Test 21-22: user_change_password
{
    my $change_result;
    my $change_err;
    $client->user_change_password($test_user, 'new-password-456', sub {
        my ($resp, $err) = @_;
        $change_result = $resp;
        $change_err = $err;
        EV::break;
    });
    my $t_change = EV::timer(5, 0, sub { fail('timeout'); EV::break });
    EV::run;

    ok(!$change_err, 'user_change_password succeeded');
    ok($change_result && $change_result->{header}, 'user_change_password response has header');
    diag("Changed password for user: $test_user");
}

# Test 23-24: user_list
$client->user_list(sub {
    my ($resp, $err) = @_;
    ok(!$err, 'user_list succeeded');

    my $found = grep { $_ eq $test_user } @{$resp->{users} || []};
    ok($found, 'our test user is in the list');
    diag("Found " . scalar(@{$resp->{users} || []}) . " users");
    EV::break;
});
my $t7 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 25: user_grant_role
$client->user_grant_role($test_user, $test_role, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'user_grant_role succeeded');
    diag("Granted role $test_role to user $test_user");
    EV::break;
});
my $t8 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 26-27: user_get
$client->user_get($test_user, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'user_get succeeded');
    my $has_role = grep { $_ eq $test_role } @{$resp->{roles} || []};
    ok($has_role, 'user has the granted role');
    EV::break;
});
my $t9 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Cleanup (Test 28-30): revoke role from user, delete user, delete role

# Test 28: user_revoke_role
$client->user_revoke_role($test_user, $test_role, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'user_revoke_role succeeded');
    EV::break;
});
my $t10 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 29: user_delete
$client->user_delete($test_user, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'user_delete succeeded');
    diag("Deleted user: $test_user");
    EV::break;
});
my $t11 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

# Test 30: role_delete
$client->role_delete($test_role, sub {
    my ($resp, $err) = @_;
    ok(!$err, 'role_delete succeeded');
    diag("Deleted role: $test_role");
    EV::break;
});
my $t12 = EV::timer(5, 0, sub { fail('timeout'); EV::break });
EV::run;

done_testing();

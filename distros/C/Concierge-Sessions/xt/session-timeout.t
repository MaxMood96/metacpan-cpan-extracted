#!/usr/bin/env perl

# Real-time session timeout tests -- uses actual sleep() calls.
# Run with: prove -l xt/
# Skipped under AUTOMATED_TESTING (CPAN testers, CI) to avoid
# false failures on slow or heavily loaded machines.

use strict;
use warnings;
use Test2::V0;
use lib 'lib';
use File::Temp qw(tempdir);

use Concierge::Sessions;

skip_all 'Skipping real-time timeout tests under AUTOMATED_TESTING'
    if $ENV{AUTOMATED_TESTING};

my $temp_dir = tempdir(CLEANUP => 1);

subtest 'Session expiration detection (real-time)' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $session = $manager->new_session(
        user_id         => 'expire_test_rt',
        session_timeout => 2,
    );

    my $session_id = $session->{session}->session_id();

    # Session should be valid immediately
    my $check = $manager->get_session($session_id);
    ok($check->{success}, 'Session valid immediately after creation');

    # Wait for expiry
    sleep 4;

    # Session should now be expired
    $check = $manager->get_session($session_id);
    ok(!$check->{success}, 'Session expired after timeout');
};

subtest 'Sliding window extends session (real-time)' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $session = $manager->new_session(
        user_id         => 'slide_test_rt',
        session_timeout => 4,
        data            => { counter => 0 },
    );

    my $session_id = $session->{session}->session_id();

    # Wait 2 seconds (half the timeout)
    sleep 2;

    # Save session (should extend expiration)
    $session->{session}->set_data({ counter => 1 });
    $session->{session}->save();

    # Wait another 3 seconds (total 5s from creation, past original 4s expiry)
    sleep 3;

    # Session should still be valid (extended at 2s, expires at 6s)
    my $retrieved = $manager->get_session($session_id);
    ok($retrieved->{success}, 'Session still valid after sliding window extension');

    my $data_result = $retrieved->{session}->get_data();
    is($data_result->{value}{counter}, 1, 'Extended session has correct data');
};

subtest 'is_expired() detects expiration (real-time)' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->new_session(
        user_id         => 'expired_obj_rt',
        session_timeout => 2,
    );

    my $session = $result->{session};

    is($session->is_expired(), 0, 'Session not expired initially');
    is($session->is_valid(), 1, 'Session valid initially');

    sleep 4;

    is($session->is_expired(), 1, 'Session expired after timeout');
    is($session->is_valid(), 0, 'Session no longer valid');
};

done_testing;

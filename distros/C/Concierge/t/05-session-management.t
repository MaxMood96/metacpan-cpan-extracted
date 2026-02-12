#!/usr/bin/env perl
use v5.36;
use lib 'lib';
use Test2::V0;
use File::Temp qw(tempdir);

use Concierge::Setup;
use Concierge;

# Setup test desk
my $test_dir = tempdir(CLEANUP => 1);

Concierge::Setup::build_quick_desk($test_dir, ['pref']);
my $desk = Concierge->open_desk($test_dir);
my $concierge = $desk->{concierge};

# Add test user
$concierge->add_user({
    user_id  => 'sessiontest',
    moniker  => 'SessionTest',
    password => 'testpass123',
});

subtest 'login_user creates session' => sub {
    my $result = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });

    ok $result->{success}, 'login succeeds';
    isa_ok $result->{user}, ['Concierge::User'], 'returns User object';

    my $user = $result->{user};
    ok $user->session_id(), 'session_id assigned';
    isa_ok $user->session(), ['Concierge::Sessions::Session'], 'has session object';

    # Verify user_key mapping created
    my $user_key = $user->user_key();
    ok exists $concierge->{user_keys}{$user_key}, 'user_key mapping exists';
    is $concierge->{user_keys}{$user_key}{user_id}, 'sessiontest', 'mapping user_id correct';
    is $concierge->{user_keys}{$user_key}{session_id}, $user->session_id(), 'mapping session_id correct';
};

subtest 'session data operations' => sub {
    my $login = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $user = $login->{user};

    # Set session data via User object
    my $set_ok = $user->update_session_data({ cart => ['item1'], page => '/home' });
    ok $set_ok, 'update_session_data succeeds';

    # Get session data via User object
    my $data = $user->get_session_data();
    is $data->{cart}, ['item1'], 'cart data correct';
    is $data->{page}, '/home', 'page data correct';

    # Update session data (merge)
    $user->update_session_data({ cart => ['item1', 'item2'] });

    my $updated = $user->get_session_data();
    is $updated->{cart}, ['item1', 'item2'], 'cart updated correctly';
    is $updated->{page}, '/home', 'page preserved after merge';
};

subtest 'session info methods' => sub {
    my $login = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $session = $login->{user}->session();

    ok $session->is_active(), 'session is active';
    ok !$session->is_expired(), 'session not expired';
    ok $session->is_valid(), 'session is valid';
    ok $session->session_id(), 'has session_id';
    ok $session->created_at(), 'has created_at';
    ok $session->expires_at(), 'has expires_at';
};

subtest 'logout_user removes session' => sub {
    my $login = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $user = $login->{user};
    my $session_id = $user->session_id();
    my $user_key = $user->user_key();

    # Verify session exists
    my $check_session = $concierge->sessions->get_session($session_id);
    ok $check_session->{success}, 'session exists before logout';

    # Logout
    my $result = $concierge->logout_user($session_id);
    ok $result->{success}, 'logout_user succeeds';

    # Verify session deleted
    $check_session = $concierge->sessions->get_session($session_id);
    ok !$check_session->{success}, 'session deleted';

    # Verify user_key mapping removed
    ok !exists $concierge->{user_keys}{$user_key}, 'user_key mapping removed';
};

subtest 'user data operations through User object' => sub {
    my $login = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $user = $login->{user};

    # Quick access from memory
    is $user->user_id(), 'sessiontest', 'user_id accessible';
    is $user->moniker(), 'SessionTest', 'moniker accessible';

    # Update via User object
    my $update_ok = $user->update_user_data({ pref => 'value1' });
    ok $update_ok, 'update_user_data succeeds';
    is $user->get_user_field('pref'), 'value1', 'field updated in memory';

    # Refresh from backend
    my $refresh_ok = $user->refresh_user_data();
    ok $refresh_ok, 'refresh_user_data succeeds';
    is $user->get_user_field('pref'), 'value1', 'field persisted to backend';
};

subtest 'restore_user restores logged-in user' => sub {
    my $login = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $user = $login->{user};
    my $user_key   = $user->user_key();
    my $session_id = $user->session_id();

    # Restore from user_key
    my $result = $concierge->restore_user($user_key);
    ok $result->{success}, 'restore_user succeeds';

    my $restored = $result->{user};
    isa_ok $restored, ['Concierge::User'], 'returns User object';
    is $restored->user_id(), 'sessiontest', 'user_id correct';
    is $restored->user_key(), $user_key, 'user_key preserved';
    is $restored->session_id(), $session_id, 'session_id preserved';
    ok $restored->is_logged_in(), 'is_logged_in true';
    ok !$restored->is_guest(), 'is_guest false';
    is $restored->moniker(), 'SessionTest', 'user data loaded';

    # Backend closures work
    my $update_ok = $restored->update_user_data({ pref => 'restored_val' });
    ok $update_ok, 'update_user_data works on restored user';
    my $refresh_ok = $restored->refresh_user_data();
    ok $refresh_ok, 'refresh_user_data works on restored user';
    is $restored->get_user_field('pref'), 'restored_val', 'backend write persisted';
};

subtest 'restore_user restores guest' => sub {
    my $guest_result = $concierge->checkin_guest();
    my $guest = $guest_result->{user};
    my $user_key = $guest->user_key();

    # Store some session data
    $guest->update_session_data({ cart => ['item1'] });

    # Restore from user_key
    my $result = $concierge->restore_user($user_key);
    ok $result->{success}, 'restore_user succeeds for guest';
    ok $result->{is_guest}, 'is_guest flag in response';

    my $restored = $result->{user};
    ok $restored->is_guest(), 'restored user is_guest';
    ok !$restored->is_logged_in(), 'restored user not logged_in';
    is $restored->user_key(), $user_key, 'user_key preserved';

    # Session data accessible
    my $data = $restored->get_session_data();
    is $data->{cart}, ['item1'], 'session data preserved';
};

subtest 'restore_user fails for invalid key' => sub {
    my $result = $concierge->restore_user('nonexistent_key');
    ok !$result->{success}, 'fails for unknown key';
    like $result->{message}, qr/not found/, 'message mentions not found';
};

subtest 'restore_user fails for expired session' => sub {
    # Create a guest with a very short timeout
    my $guest_result = $concierge->checkin_guest({ timeout => 1 });
    my $user_key = $guest_result->{user}->user_key();

    # Wait for session to expire
    sleep 2;

    my $result = $concierge->restore_user($user_key);
    ok !$result->{success}, 'fails for expired session';
    like $result->{message}, qr/expired/i, 'message mentions expired';

    # Stale mapping cleaned up
    ok !exists $concierge->{user_keys}{$user_key}, 'stale mapping removed';
};

subtest 'multiple logins replace previous session' => sub {
    # Login first time
    my $login1 = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $session_id1 = $login1->{user}->session_id();

    # Login again (should delete first session)
    my $login2 = $concierge->login_user({
        user_id  => 'sessiontest',
        password => 'testpass123',
    });
    my $session_id2 = $login2->{user}->session_id();

    isnt $session_id1, $session_id2, 'different session_ids';

    # First session should be deleted
    my $check = $concierge->sessions->get_session($session_id1);
    ok !$check->{success}, 'previous session deleted';

    # Second session should exist
    $check = $concierge->sessions->get_session($session_id2);
    ok $check->{success}, 'new session exists';
};

done_testing;

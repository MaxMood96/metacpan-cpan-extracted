#!/usr/bin/env perl

use strict;
use warnings;
use Test2::V0;
use Test2::Tools::Exception;
use lib 'lib';
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);

use Concierge::Sessions;

# Create temporary directory for test storage
my $temp_dir = tempdir(CLEANUP => 1);

note("Testing Concierge::Sessions manager functionality");

# ===================================================================
# Test 1-3: Constructor with different backends
# ===================================================================

subtest 'Constructor with database backend' => sub {
    my $manager = Concierge::Sessions->new(
        backend    => 'database',
        storage_dir => $temp_dir,
    );

    ok($manager, 'Manager object created');
    isa_ok($manager, ['Concierge::Sessions']);
};

subtest 'Constructor with file backend' => sub {
    my $manager = Concierge::Sessions->new(
        backend    => 'file',
        storage_dir => $temp_dir,
    );

    ok($manager, 'Manager object created');
    isa_ok($manager, ['Concierge::Sessions']);
};

subtest 'Constructor with default backend' => sub {
    my $manager = Concierge::Sessions->new(
        storage_dir => $temp_dir,
    );

    ok($manager, 'Manager object created');
    isa_ok($manager, ['Concierge::Sessions']);
};

subtest 'Constructor with invalid backend' => sub {
    like(
        dies { Concierge::Sessions->new(backend => 'InvalidBackend', storage_dir => $temp_dir) },
        qr/Failed to initialize backend/,
        'Dies with invalid backend'
    );
};

# ===================================================================
# Test 4-8: new_session() method
# ===================================================================

subtest 'new_session() with valid user_id' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->new_session(user_id => 'test_user_001');

    ok($result, 'new_session returns a result');
    ref_ok($result, 'HASH', 'Result is a hashref');

    ok($result->{success}, 'Session creation successful');
    isa_ok($result->{session}, ['Concierge::Sessions::Session']);

    my $session = $result->{session};

    ok($session->created_at(), 'created_at timestamp set via accessor');
    ok($session->expires_at(), 'expires_at timestamp set via accessor');
    is($session->status()->{state}, 'active', 'Initial state is active');
    is($session->is_dirty(), 0, 'Initial dirty flag is 0 via accessor');

    my $data_result = $session->get_data();
    ref_ok($data_result->{value}, 'HASH', 'Data is a hashref via accessor');
};

subtest 'new_session() without user_id fails' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->new_session();

    ok($result, 'Returns error result');
    is($result->{success}, 0, 'Creation failed without user_id');
    like($result->{message}, qr/user_id required/, 'Error message mentions user_id requirement');
};

subtest 'new_session() with custom timeout' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->new_session(
        user_id          => 'test_user_timeout',
        session_timeout  => 7200,  # 2 hours
    );

    ok($result->{success}, 'Session created with custom timeout');
    my $session = $result->{session};

    my $created = $session->created_at();
    my $expires = $session->expires_at();
    my $expected_expires = $created + 7200;

    is($expires, $expected_expires, 'Custom timeout applied correctly');
};

subtest 'new_session() with default timeout' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->new_session(user_id => 'test_user_default');

    ok($result->{success}, 'Session created with default timeout');
    my $session = $result->{session};

    my $created = $session->created_at();
    my $expires = $session->expires_at();
    my $expected_expires = $created + 3600;  # DEFAULT_SESSION_TIMEOUT

    is($expires, $expected_expires, 'Default timeout applied correctly');
};

subtest 'new_session() with initial data' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $initial_data = { foo => 'bar', count => 42 };

    my $result = $manager->new_session(
        user_id => 'test_user_with_data',
        data    => $initial_data,
    );

    ok($result->{success}, 'Session created with initial data');
    my $session = $result->{session};

    my $data_result = $session->get_data();
    is($data_result->{value}, $initial_data, 'Initial data stored correctly via accessor');
};

# ===================================================================
# Test 9-12: get_session() method
# ===================================================================

subtest 'get_session() with valid session_id' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    # Create a session first
    my $create_result = $manager->new_session(user_id => 'test_user_get');

    # Get the session_id via accessor
    my $session_id = $create_result->{session}->session_id();

    # Retrieve it
    my $get_result = $manager->get_session($session_id);

    ok($get_result->{success}, 'Session retrieved successfully');
    isa_ok($get_result->{session}, ['Concierge::Sessions::Session']);
};

subtest 'get_session() without session_id fails' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->get_session();

    is($result->{success}, 0, 'Get fails without session_id');
    like($result->{message}, qr/Session ID required/, 'Error message mentions session_id requirement');
};

subtest 'get_session() with non-existent session_id' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->get_session('non-existent-session-id');

    is($result->{success}, 0, 'Get fails for non-existent session');
    like($result->{message}, qr/get_session_info/, 'Error from backend propagated');
};

subtest 'get_session() with expired session' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    # Create a session with 1 second timeout
    my $create_result = $manager->new_session(
        user_id          => 'test_user_expired',
        session_timeout  => 600,
    );

    my $session_id = $create_result->{session}->session_id();

    # Wait for session to expire
    # sleep(2);
    # Force-expire via direct DB update (no sleep needed)
    my $db_file = File::Spec->catfile($temp_dir, 'sessions.db');
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1 });
    $dbh->do("UPDATE sessions SET expires_at = ? WHERE session_id = ?",
        undef, time() - 3600, $session_id);
    $dbh->disconnect;

    # Try to retrieve it - backend filters expired sessions
    my $get_result = $manager->get_session($session_id);

    # Backend automatically filters expired sessions
    is($get_result->{success}, 0, 'Expired session cannot be retrieved (filtered by backend)');
    like($get_result->{message}, qr/(not found|expired)/i, 'Error indicates session not found or expired');
};

subtest 'delete_session() with valid session_id' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    # Create a session first
    my $create_result = $manager->new_session(user_id => 'test_user_delete');
    my $session_id = $create_result->{session}->session_id();

    # Delete it
    my $delete_result = $manager->delete_session($session_id);

    ok($delete_result->{success}, 'Session deleted successfully');

    # Verify it's gone
    my $get_result = $manager->get_session($session_id);
    is($get_result->{success}, 0, 'Session no longer retrievable after deletion');
};

subtest 'delete_session() without session_id fails' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->delete_session();

    is($result->{success}, 0, 'Delete fails without session_id');
    like($result->{message}, qr/Session ID required/, 'Error message mentions session_id requirement');
};

subtest 'delete_session() with non-existent session_id' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    my $result = $manager->delete_session('non-existent-session-id');

    # Different backends handle this differently
    # SQLite returns success even if session doesn't exist
    ok(exists $result->{success}, 'Returns a result');
};

# ===================================================================
# Test 16-17: cleanup_sessions() method
# ===================================================================

subtest 'cleanup_sessions() with expired sessions' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    # Create active session
    $manager->new_session(
        user_id          => 'active_user',
        session_timeout  => 3600,
    );

    # Create expired session
    $manager->new_session(
        user_id          => 'expired_user',
        session_timeout  => 0,
    );

    my $cleanup_result = $manager->cleanup_sessions();

    ok($cleanup_result->{success}, 'Cleanup completed');
    ok(exists $cleanup_result->{deleted_count}, 'Returns deleted_count');
};

subtest 'cleanup_sessions() with no expired sessions' => sub {
    my $manager = Concierge::Sessions->new(
        backend     => 'database',
        storage_dir => $temp_dir,
    );

    # Create only active sessions
    $manager->new_session(user_id => 'user1', session_timeout => 3600);
    $manager->new_session(user_id => 'user2', session_timeout => 3600);

    my $cleanup_result = $manager->cleanup_sessions();

    ok($cleanup_result->{success}, 'Cleanup completed');
    is($cleanup_result->{deleted_count} || 0, 0, 'No sessions deleted');
};

# ===================================================================
# Test 18-19: File backend tests
# ===================================================================

subtest 'Manager with File backend - basic operations' => sub {
    my $file_dir = "$temp_dir/file_sessions";

    my $manager = Concierge::Sessions->new(
        backend     => 'file',
        storage_dir => $file_dir,
    );

    # Create session
    my $create_result = $manager->new_session(user_id => 'file_test_user');
    ok($create_result->{success}, 'Session created with File backend');

    my $session_id = $create_result->{session}->session_id();

    # Retrieve session
    my $get_result = $manager->get_session($session_id);
    ok($get_result->{success}, 'Session retrieved with File backend');

    # Delete session
    my $delete_result = $manager->delete_session($session_id);
    ok($delete_result->{success}, 'Session deleted with File backend');
};

subtest 'File backend cleanup' => sub {
    my $file_dir = "$temp_dir/file_cleanup";

    my $manager = Concierge::Sessions->new(
        backend     => 'file',
        storage_dir => $file_dir,
    );

    # Create active and expired sessions
    $manager->new_session(user_id => 'active', session_timeout => 3600);
    $manager->new_session(user_id => 'expired', session_timeout => 0);

    my $cleanup_result = $manager->cleanup_sessions();

    ok($cleanup_result->{success}, 'File cleanup completed');
    ok(exists $cleanup_result->{deleted_count}, 'Returns deleted_count');
};

done_testing;

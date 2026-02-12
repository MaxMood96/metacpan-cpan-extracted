#!/usr/bin/env perl

=head1 NAME

04-session-management.pl - Session management system example

=head1 DESCRIPTION

Demonstrates how to build a simple session management system
using Concierge::Auth for authentication and token generation.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempfile);
use Time::HiRes qw(time);

print "=== Session Management Example ===\n\n";

# Setup authentication system
my ($fh, $auth_file) = tempfile(CLEANUP => 1);
close $fh;

my $auth = Concierge::Auth->new({file => $auth_file});

# Register some test users
my %test_users = (
    'alice'   => 'secure_password_123',
    'bob'     => 'bobs_secret_key',
    'charlie' => 'charlie_strong_pass'
);

print "--- User Registration ---\n";
for my $username (sort keys %test_users) {
    my $password = $test_users{$username};
    my ($success, $message) = $auth->setPwd($username, $password);
    printf "%-10s: %s\n", $username, $success ? "registered" : "failed";
}

# Simple session management system
my %active_sessions;
my $SESSION_TIMEOUT = 3600;  # 1 hour in seconds

sub create_session {
    my ($username, $password) = @_;
    
    # Authenticate user
    return (0, "Invalid credentials") unless $auth->checkPwd($username, $password);
    
    # Generate secure session token
    my $session_token = $auth->gen_random_token(32, 'url_safe');
    
    # Store session data
    $active_sessions{$session_token} = {
        username    => $username,
        created_at  => time(),
        last_active => time(),
        ip_address  => '127.0.0.1',  # In real app, get from request
        user_agent  => 'Example-Client/1.0'
    };
    
    return (1, $session_token);
}

sub validate_session {
    my ($session_token) = @_;
    
    return unless $session_token;
    return unless exists $active_sessions{$session_token};
    
    my $session = $active_sessions{$session_token};
    my $now = time();
    
    # Check if session has expired
    if (($now - $session->{last_active}) > $SESSION_TIMEOUT) {
        delete $active_sessions{$session_token};
        return;
    }
    
    # Update last active time
    $session->{last_active} = $now;
    
    return $session->{username};
}

sub refresh_session {
    my ($session_token) = @_;
    
    return unless exists $active_sessions{$session_token};
    
    my $session = $active_sessions{$session_token};
    $session->{last_active} = time();
    
    return 1;
}

sub destroy_session {
    my ($session_token) = @_;
    
    return delete $active_sessions{$session_token} ? 1 : 0;
}

sub list_active_sessions {
    my ($username) = @_;
    
    my @user_sessions;
    
    for my $token (keys %active_sessions) {
        my $session = $active_sessions{$token};
        if (!$username || $session->{username} eq $username) {
            push @user_sessions, {
                token       => $token,
                username    => $session->{username},
                created_at  => $session->{created_at},
                last_active => $session->{last_active},
                age         => time() - $session->{created_at}
            };
        }
    }
    
    return @user_sessions;
}

print "\n--- Session Creation ---\n";

# Create sessions for users
my %user_sessions;

# Successful logins
for my $username (qw(alice bob)) {
    my $password = $test_users{$username};
    my ($success, $token) = create_session($username, $password);
    
    if ($success) {
        $user_sessions{$username} = $token;
        printf "%-10s: ✓ session created: %s...\n", $username, substr($token, 0, 16);
    } else {
        printf "%-10s: ✗ login failed: %s\n", $username, $token;
    }
}

# Failed login attempt
my ($fail_success, $fail_token) = create_session('alice', 'wrong_password');
printf "%-10s: %s\n", 'alice/wrong', $fail_success ? "✓ unexpected success" : "✗ failed (expected)";

# Login for non-existent user
my ($missing_success, $missing_token) = create_session('david', 'any_password');
printf "%-10s: %s\n", 'david', $missing_success ? "✓ unexpected success" : "✗ failed (expected)";

print "\n--- Session Validation ---\n";

# Validate active sessions
for my $username (qw(alice bob)) {
    next unless $user_sessions{$username};
    
    my $token = $user_sessions{$username};
    my $validated_user = validate_session($token);
    
    printf "%-10s: %s\n", $username, 
           $validated_user ? "✓ session valid" : "✗ session invalid";
}

# Test invalid session tokens
my @invalid_tokens = (
    'invalid_token_123',
    'another_fake_token',
    $auth->gen_random_token(32),  # Valid format but not in our system
);

print "\nInvalid token tests:\n";
for my $i (0..$#invalid_tokens) {
    my $token = $invalid_tokens[$i];
    my $validated_user = validate_session($token);
    
    printf "Invalid %d: %s\n", $i+1,
           $validated_user ? "✓ validated (unexpected)" : "✗ rejected (expected)";
}

print "\n--- Active Sessions List ---\n";

my @all_sessions = list_active_sessions();
printf "Total active sessions: %d\n\n", scalar @all_sessions;

for my $session (@all_sessions) {
    printf "User: %-10s | Token: %s... | Age: %ds\n",
           $session->{username},
           substr($session->{token}, 0, 16),
           int($session->{age});
}

print "\n--- Session Refresh ---\n";

# Simulate some activity
sleep 1;

for my $username (qw(alice bob)) {
    next unless $user_sessions{$username};
    
    my $token = $user_sessions{$username};
    my $refreshed = refresh_session($token);
    
    printf "%-10s: %s\n", $username,
           $refreshed ? "✓ session refreshed" : "✗ refresh failed";
}

print "\n--- Session Destruction ---\n";

# Destroy Alice's session
my $alice_token = $user_sessions{alice};
my $destroyed = destroy_session($alice_token);
printf "Alice logout: %s\n", $destroyed ? "✓ session destroyed" : "✗ destruction failed";

# Try to validate destroyed session
my $still_valid = validate_session($alice_token);
printf "Alice session: %s\n", $still_valid ? "✗ still valid (bad)" : "✓ invalidated (good)";

# Bob's session should still be active
my $bob_token = $user_sessions{bob};
my $bob_still_valid = validate_session($bob_token);
printf "Bob session: %s\n", $bob_still_valid ? "✓ still active" : "✗ incorrectly destroyed";

print "\n--- Final Session Status ---\n";

@all_sessions = list_active_sessions();
printf "Remaining active sessions: %d\n", scalar @all_sessions;

for my $session (@all_sessions) {
    printf "User: %-10s | Created: %ds ago\n",
           $session->{username},
           int(time() - $session->{created_at});
}

print "\n=== Session Management Complete ===\n";

__END__

=head1 SESSION MANAGEMENT CONCEPTS

=head2 Session Lifecycle

=over 4

=item 1. B<Creation> - User authenticates, session token generated

=item 2. B<Validation> - Each request validates session token

=item 3. B<Refresh> - Update last active time on valid requests

=item 4. B<Expiration> - Sessions expire after timeout period

=item 5. B<Destruction> - Explicit logout or cleanup

=back

=head2 Security Features

=over 4

=item * Cryptographically secure session tokens

=item * Session timeout for idle sessions  

=item * Validation on every request

=item * Clean session destruction

=item * No session data stored client-side

=back

=head2 Production Considerations

In a production system, consider:

=over 4

=item * Store sessions in database or cache (Redis/Memcached)

=item * Include IP address and User-Agent validation

=item * Implement session fixation protection

=item * Add CSRF token generation

=item * Log security events (login, logout, failures)

=item * Implement rate limiting for login attempts

=item * Support multiple concurrent sessions per user

=back

=head1 INTEGRATION EXAMPLE

    # Web framework integration
    use Concierge::Auth;
    
    my $auth = Concierge::Auth->new({file => '/secure/path/users.db'});
    my %sessions;  # In production: use database/cache
    
    # Login endpoint
    sub handle_login {
        my ($username, $password) = @_;
        
        my ($success, $token) = create_session($username, $password);
        if ($success) {
            # Set secure cookie
            set_cookie('session_token' => $token, {
                secure   => 1,
                httponly => 1,
                samesite => 'strict'
            });
            return success_response();
        }
        return error_response('Invalid credentials');
    }
    
    # Authentication middleware  
    sub authenticate_request {
        my $token = get_cookie('session_token');
        my $username = validate_session($token);
        
        return $username || unauthenticated_response();
    }

=head1 SEE ALSO

L<Concierge::Auth>, 05-api-keys.pl, 01-basic-authentication.pl

=cut
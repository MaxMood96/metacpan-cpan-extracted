#!/usr/bin/env perl

=head1 NAME

01-basic-authentication.pl - Basic authentication system example

=head1 DESCRIPTION

Demonstrates core user registration and authentication functionality
using Concierge::Auth.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempfile);

print "=== Basic Authentication Example ===\n\n";

# Create temporary auth file for demo
my ($fh, $auth_file) = tempfile(CLEANUP => 1);
close $fh;

# Initialize auth system
my $auth = Concierge::Auth->new({file => $auth_file});
print "Auth system initialized with file: $auth_file\n\n";

# Register some users
my @users = (
    ['alice', 'secure_password_123'],
    ['bob', 'another_strong_pass'],
    ['charlie', 'yet_another_password']
);

print "--- User Registration ---\n";
for my $user_data (@users) {
    my ($username, $password) = @$user_data;
    my ($success, $message) = $auth->setPwd($username, $password);
    
    printf "%-10s: %s\n", $username, 
           $success ? "✓ registered" : "✗ failed ($message)";
}

print "\n--- Authentication Tests ---\n";

# Test correct passwords
for my $user_data (@users) {
    my ($username, $password) = @$user_data;
    my $authenticated = $auth->checkPwd($username, $password);
    
    printf "%-10s: %s\n", $username,
           $authenticated ? "✓ authenticated" : "✗ authentication failed";
}

print "\n--- Invalid Login Attempts ---\n";

# Test wrong passwords
my @wrong_attempts = (
    ['alice', 'wrong_password'],
    ['bob', ''],
    ['charlie', 'charlie123'],  # Similar but wrong
    ['david', 'any_password']   # Non-existent user
);

for my $attempt (@wrong_attempts) {
    my ($username, $password) = @$attempt;
    my $authenticated = $auth->checkPwd($username, $password);
    
    printf "%-10s: %s\n", "$username/'$password'",
           $authenticated ? "✓ authenticated (unexpected!)" : "✗ failed (expected)";
}

print "\n--- User Existence Check ---\n";

# Check which users exist
my @check_users = qw(alice bob charlie david eve);
for my $username (@check_users) {
    my $exists = $auth->checkID($username);
    printf "%-10s: %s\n", $username,
           $exists ? "exists" : "not found";
}

print "\n=== Example Complete ===\n";

__END__

=head1 OUTPUT EXAMPLE

=begin text

=== Basic Authentication Example ===

Auth system initialized with file: /tmp/2rF7X8xabc

--- User Registration ---
alice     : ✓ registered
bob       : ✓ registered  
charlie   : ✓ registered

--- Authentication Tests ---
alice     : ✓ authenticated
bob       : ✓ authenticated
charlie   : ✓ authenticated

--- Invalid Login Attempts ---
alice/'wrong_password': ✗ failed (expected)
bob/'': ✗ failed (expected)
charlie/'charlie123': ✗ failed (expected)
david/'any_password': ✗ failed (expected)

--- User Existence Check ---
alice     : exists
bob       : exists
charlie   : exists
david     : not found
eve       : not found

=== Example Complete ===

=end text

=head1 SEE ALSO

L<Concierge::Auth>, 02-user-management.pl, 03-token-generation.pl

=cut
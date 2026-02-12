#!/usr/bin/env perl

=head1 NAME

02-user-management.pl - User lifecycle management example

=head1 DESCRIPTION

Demonstrates password resets, user deletion, and other user
management operations with Concierge::Auth.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempfile);

print "=== User Management Example ===\n\n";

# Create temporary auth file
my ($fh, $auth_file) = tempfile(CLEANUP => 1);
close $fh;

my $auth = Concierge::Auth->new({file => $auth_file});

# Initial user setup
print "--- Initial Setup ---\n";
my @initial_users = (
    ['alice', 'original_password'],
    ['bob', 'bob_secret_123'],  
    ['charlie', 'charlie_pass']
);

for my $user_data (@initial_users) {
    my ($username, $password) = @$user_data;
    my ($success, $message) = $auth->setPwd($username, $password);
    printf "%-10s: %s\n", $username, $success ? "registered" : "failed";
}

print "\n--- Password Reset Operations ---\n";

# Reset Alice's password
print "Resetting Alice's password:\n";
my ($reset_success, $reset_msg) = $auth->resetPwd('alice', 'new_secure_password');
printf "Reset result: %s\n", $reset_success ? "✓ success" : "✗ failed ($reset_msg)";

if ($reset_success) {
    # Test old password no longer works
    my $old_works = $auth->checkPwd('alice', 'original_password');
    printf "Old password: %s\n", $old_works ? "✗ still works (BAD)" : "✓ disabled (GOOD)";
    
    # Test new password works
    my $new_works = $auth->checkPwd('alice', 'new_secure_password');
    printf "New password: %s\n", $new_works ? "✓ works" : "✗ doesn't work (BAD)";
}

# Try to reset password for non-existent user
print "\nTrying to reset non-existent user:\n";
my ($bad_reset, $bad_msg) = $auth->resetPwd('david', 'some_password');
printf "Reset 'david': %s\n", $bad_reset ? "✓ success (unexpected)" : "✗ failed: $bad_msg";

print "\n--- User Deletion Operations ---\n";

# Delete Charlie
print "Deleting user 'charlie':\n";
my ($delete_success, $delete_msg) = $auth->deleteID('charlie');
printf "Delete result: %s\n", $delete_success ? "✓ success" : "✗ failed ($delete_msg)";

if ($delete_success) {
    # Verify charlie no longer exists
    my $charlie_exists = $auth->checkID('charlie');
    printf "Charlie exists: %s\n", $charlie_exists ? "✗ still exists (BAD)" : "✓ gone (GOOD)";
    
    # Try to authenticate deleted user
    my $auth_deleted = $auth->checkPwd('charlie', 'charlie_pass');
    printf "Auth deleted user: %s\n", $auth_deleted ? "✗ still works (BAD)" : "✓ disabled (GOOD)";
}

# Try to delete non-existent user
print "\nTrying to delete non-existent user:\n";
my ($bad_delete, $bad_delete_msg) = $auth->deleteID('eve');
printf "Delete 'eve': %s\n", $bad_delete ? "✓ success (unexpected)" : "✗ failed: $bad_delete_msg";

print "\n--- Duplicate Registration Prevention ---\n";

# Try to register existing user
my ($dup_success, $dup_msg) = $auth->setPwd('alice', 'another_password');
printf "Register existing 'alice': %s\n", 
       $dup_success ? "✓ allowed (unexpected)" : "✗ prevented: $dup_msg";

# Verify original password still works if duplicate was prevented
if (!$dup_success) {
    my $original_still_works = $auth->checkPwd('alice', 'new_secure_password');
    printf "Original password: %s\n", 
           $original_still_works ? "✓ unchanged" : "✗ corrupted (BAD)";
}

print "\n--- Final User Status ---\n";

my @final_check = qw(alice bob charlie david eve);
for my $username (@final_check) {
    my $exists = $auth->checkID($username);
    printf "%-10s: %s\n", $username, $exists ? "exists" : "not found";
}

print "\n=== Example Complete ===\n";

__END__

=head1 KEY CONCEPTS DEMONSTRATED

=over 4

=item * Password resets completely replace old passwords

=item * Deleted users cannot authenticate or be found

=item * Operations on non-existent users fail gracefully

=item * Duplicate registrations are prevented

=item * All operations return both success status and descriptive messages

=back

=head1 BEST PRACTICES

=over 4

=item * Always check return values from user management operations

=item * Verify operations succeeded before proceeding

=item * Handle error messages appropriately for your application

=item * Test that old credentials no longer work after resets/deletions

=back

=head1 SEE ALSO

L<Concierge::Auth>, 01-basic-authentication.pl, 03-token-generation.pl

=cut
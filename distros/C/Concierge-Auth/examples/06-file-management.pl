#!/usr/bin/env perl

=head1 NAME

06-file-management.pl - Authentication file management example

=head1 DESCRIPTION

Demonstrates file operations, backup management, and multi-file
authentication scenarios using Concierge::Auth.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempdir tempfile);
use File::Spec;

print "=== File Management Examples ===\n\n";

# Create temporary directory for demo files
my $temp_dir = tempdir(CLEANUP => 1);
print "Working in temporary directory: $temp_dir\n\n";

print "--- Basic File Operations ---\n";

# Create primary auth file
my $primary_file = File::Spec->catfile($temp_dir, 'primary_users.db');
my $auth1 = Concierge::Auth->new({file => $primary_file});

print "Created primary auth file: " . $auth1->pfile() . "\n";
print "Field separator: '" . $auth1->psep() . "'\n";

# Add some users to primary file
my @primary_users = (
    ['alice', 'password123'],
    ['bob', 'secure_pass'],
    ['charlie', 'strong_password']
);

print "\nPopulating primary file:\n";
for my $user_data (@primary_users) {
    my ($username, $password) = @$user_data;
    my ($success, $message) = $auth1->setPwd($username, $password);
    printf "  %-10s: %s\n", $username, $success ? "✓ added" : "✗ failed";
}

print "\n--- Alternative Separators ---\n";

# Create auth file with pipe separator
my $pipe_file = File::Spec->catfile($temp_dir, 'pipe_users.db');
my $auth2 = Concierge::Auth->new({file => $pipe_file, sep => '|'});

print "Created pipe-separated file: " . $auth2->pfile() . "\n";
print "Field separator: '" . $auth2->psep() . "'\n";

# Add users to pipe-separated file
for my $user_data (@primary_users) {
    my ($username, $password) = @$user_data;
    $auth2->setPwd($username, $password);
}

# Create auth file with comma separator
my $csv_file = File::Spec->catfile($temp_dir, 'csv_users.db');
my $auth3 = Concierge::Auth->new({file => $csv_file, sep => ','});

print "Created comma-separated file: " . $auth3->pfile() . "\n";
print "Field separator: '" . $auth3->psep() . "'\n";

print "\n--- File Format Demonstration ---\n";

# Show the actual file contents to demonstrate separators
print "Tab-separated format:\n";
if (open my $fh1, '<', $primary_file) {
    while (my $line = <$fh1>) {
        chomp $line;
        $line =~ s/\t/<TAB>/g;  # Make tabs visible
        print "  $line\n";
        last if $. >= 3;  # Show first 3 lines
    }
    close $fh1;
}

print "\nPipe-separated format:\n";
if (open my $fh2, '<', $pipe_file) {
    while (my $line = <$fh2>) {
        chomp $line;
        print "  $line\n";
        last if $. >= 3;
    }
    close $fh2;
}

print "\n--- File Switching ---\n";

# Demonstrate changing files on existing auth object
my $new_file = File::Spec->catfile($temp_dir, 'switched_users.db');

print "Original file: " . $auth1->pfile() . "\n";

my ($switch_success, $switch_msg) = $auth1->setFile($new_file);
print "Switch result: " . ($switch_success ? "✓ success" : "✗ failed") . " - $switch_msg\n";
print "New file: " . $auth1->pfile() . "\n";

# Add user to new file
my ($add_success, $add_msg) = $auth1->setPwd('david', 'david_password');
print "Add to new file: " . ($add_success ? "✓ success" : "✗ failed") . "\n";

# Verify user exists in new file but not old file
print "David in new file: " . ($auth1->checkID('david') ? "YES" : "NO") . "\n";

# Switch back to original file
$auth1->setFile($primary_file);
print "David in original file: " . ($auth1->checkID('david') ? "YES" : "NO") . "\n";

print "\n--- File Validation ---\n";

# Test file validation methods
my @test_files = (
    $primary_file,                              # Exists, readable
    File::Spec->catfile($temp_dir, 'missing.db'), # Doesn't exist
    $temp_dir,                                  # Directory, not file
);

for my $file (@test_files) {
    my $valid = $auth1->validateFile($file);
    my $exists = -e $file;
    my $readable = -r $file;
    my $is_file = -f $file;
    
    printf "%-20s: %s (exists:%s readable:%s file:%s)\n",
           (split '/', $file)[-1] || 'temp_dir',
           $valid ? "✓ valid" : "✗ invalid",
           $exists ? "Y" : "N",
           $readable ? "Y" : "N",
           $is_file ? "Y" : "N";
}

print "\n--- File Clearing ---\n";

# Create a file to demonstrate clearing
my $clear_file = File::Spec->catfile($temp_dir, 'clear_test.db');
my $clear_auth = Concierge::Auth->new({file => $clear_file});

# Add some users
$clear_auth->setPwd('user1', 'password1');
$clear_auth->setPwd('user2', 'password2');
$clear_auth->setPwd('user3', 'password3');

print "Users before clear:\n";
for my $user (qw(user1 user2 user3)) {
    my $exists = $clear_auth->checkID($user);
    printf "  %-10s: %s\n", $user, $exists ? "exists" : "not found";
}

# Clear the file
my ($clear_success, $clear_msg) = $clear_auth->clearFile();
print "\nClear result: " . ($clear_success ? "✓ success" : "✗ failed") . " - $clear_msg\n";

print "Users after clear:\n";
for my $user (qw(user1 user2 user3)) {
    my $exists = $clear_auth->checkID($user);
    printf "  %-10s: %s\n", $user, $exists ? "exists" : "not found";
}

print "\n--- File Removal ---\n";

# Create a file to demonstrate removal
my $remove_file = File::Spec->catfile($temp_dir, 'remove_test.db');
my $remove_auth = Concierge::Auth->new({file => $remove_file});

$remove_auth->setPwd('temp_user', 'temp_password');

print "File exists before removal: " . (-e $remove_file ? "YES" : "NO") . "\n";
print "Auth object file: " . $remove_auth->pfile() . "\n";

# Remove the file
my ($remove_success, $remove_msg) = $remove_auth->rmFile();
print "Remove result: " . ($remove_success ? "✓ success" : "✗ failed") . " - $remove_msg\n";

print "File exists after removal: " . (-e $remove_file ? "YES" : "NO") . "\n";
print "Auth object file: '" . $remove_auth->pfile() . "'\n";

print "\n--- Multi-File Authentication ---\n";

# Demonstrate using multiple auth files for different purposes
my %auth_systems = (
    'users'  => Concierge::Auth->new({file => File::Spec->catfile($temp_dir, 'users.db')}),
    'admins' => Concierge::Auth->new({file => File::Spec->catfile($temp_dir, 'admins.db')}),
    'guests' => Concierge::Auth->new({file => File::Spec->catfile($temp_dir, 'guests.db')})
);

# Populate different auth systems
$auth_systems{users}->setPwd('alice', 'user_password');
$auth_systems{users}->setPwd('bob', 'user_password');

$auth_systems{admins}->setPwd('admin', 'admin_super_secure');
$auth_systems{admins}->setPwd('root', 'root_password');

$auth_systems{guests}->setPwd('guest', 'guest_password');

# Demonstrate role-based authentication function
sub authenticate_user {
    my ($username, $password, $required_role) = @_;
    $required_role ||= 'users';
    
    return unless exists $auth_systems{$required_role};
    
    return $auth_systems{$required_role}->checkPwd($username, $password);
}

# Test authentication across systems
my @auth_tests = (
    ['alice', 'user_password', 'users', 'should succeed'],
    ['alice', 'user_password', 'admins', 'should fail - wrong system'],
    ['admin', 'admin_super_secure', 'admins', 'should succeed'],
    ['admin', 'admin_super_secure', 'users', 'should fail - wrong system'],
    ['guest', 'guest_password', 'guests', 'should succeed'],
    ['bob', 'wrong_password', 'users', 'should fail - wrong password']
);

print "Multi-system authentication tests:\n";
for my $test (@auth_tests) {
    my ($user, $pass, $role, $expected) = @$test;
    my $result = authenticate_user($user, $pass, $role);
    
    printf "  %-20s: %s (%s)\n",
           "$user/$role",
           $result ? "✓ authenticated" : "✗ failed",
           $expected;
}

print "\n--- File Security Demonstration ---\n";

# Show file permissions
my @auth_files = (
    $auth_systems{users}->pfile(),
    $auth_systems{admins}->pfile(),
    $auth_systems{guests}->pfile()
);

print "File permissions:\n";
for my $file (@auth_files) {
    next unless -e $file;
    my $mode = (stat $file)[2];
    my $perms = sprintf "%04o", $mode & 07777;
    printf "  %-12s: %s\n", (split '/', $file)[-1], $perms;
}

print "\n--- Utility-Only Mode ---\n";

# Demonstrate using Concierge::Auth without file (utilities only)
my $util_auth = Concierge::Auth->new({no_file => 1});

print "Utility-only auth object created (no file)\n";
print "File: '" . $util_auth->pfile() . "'\n";

# Can still use utility methods
print "UUID: " . $util_auth->gen_uuid() . "\n";
print "Token: " . $util_auth->gen_random_token(16) . "\n";
print "Crypt token: " . $util_auth->gen_crypt_token() . "\n";

print "\n=== File Management Complete ===\n";

__END__

=head1 FILE MANAGEMENT CONCEPTS

=head2 File Formats

Concierge::Auth supports customizable field separators:

=over 4

=item * Tab-separated (default): C<username\tpassword_hash\t|>

=item * Pipe-separated: C<username|password_hash||>

=item * Comma-separated: C<username,password_hash,|>

=item * Custom separator: Any single character

=back

=head2 File Operations

=over 4

=item * B<Creation> - Files created automatically with secure permissions (0600)

=item * B<Switching> - Change files on existing auth objects

=item * B<Validation> - Check file existence and readability

=item * B<Clearing> - Remove all users while keeping file

=item * B<Removal> - Delete file completely

=back

=head2 Security Features

=over 4

=item * Files created with restrictive permissions (0600)

=item * Atomic file operations with locking

=item * Backup file cleanup

=item * Safe in-place editing

=back

=head1 MULTI-FILE PATTERNS

=head2 Role-Based Separation

    my %auth_systems = (
        users  => Concierge::Auth->new({file => 'users.db'}),
        admins => Concierge::Auth->new({file => 'admins.db'}),
        api    => Concierge::Auth->new({file => 'api_keys.db'})
    );

=head2 Environment Separation

    my $env = $ENV{APP_ENV} || 'development';
    my $auth = Concierge::Auth->new({
        file => "users_$env.db"
    });

=head2 Application Separation

    my %apps = (
        web    => Concierge::Auth->new({file => 'web_users.db'}),
        mobile => Concierge::Auth->new({file => 'mobile_users.db'}),
        cli    => Concierge::Auth->new({file => 'cli_users.db'})
    );

=head1 BEST PRACTICES

=over 4

=item * Use absolute paths for auth files

=item * Place auth files outside web-accessible directories

=item * Use restrictive directory permissions (0700)

=item * Implement regular backup strategies

=item * Monitor file access and modifications

=item * Use separate files for different security levels

=back

=head1 SEE ALSO

L<Concierge::Auth>, 07-error-handling.pl, 04-session-management.pl

=cut
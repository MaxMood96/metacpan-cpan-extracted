#!/usr/bin/env perl

=head1 NAME

07-error-handling.pl - Error handling and validation examples

=head1 DESCRIPTION

Demonstrates proper error handling, input validation, and edge case
management with Concierge::Auth.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempfile);

print "=== Error Handling Examples ===\n\n";

# Create auth system for testing
my ($fh, $auth_file) = tempfile(CLEANUP => 1);
close $fh;

my $auth = Concierge::Auth->new({file => $auth_file});

print "--- Input Validation Errors ---\n";

# Test invalid user IDs
print "Invalid User ID tests:\n";
my @invalid_ids = (
    ['', 'empty string'],
    [undef, 'undefined value'],
    ['x', 'too short (1 char)'],
    ['a' x 33, 'too long (33 chars)'],
    ['user name', 'contains space'],
    ['user!', 'contains exclamation'],
    ['user@host.com$', 'contains dollar sign'],
    ['user#123', 'contains hash'],
    ['user%admin', 'contains percent'],
);

for my $test (@invalid_ids) {
    my ($id, $desc) = @$test;
    
    eval { $auth->validateID($id) };
    my $error = $@;
    
    printf "  %-20s: %s\n", $desc,
           $error ? "✓ rejected" : "✗ accepted (unexpected)";
    
    if ($error) {
        chomp $error;
        print "    Error: $error\n";
    }
    print "\n";
}

# Test valid user IDs that should pass
print "Valid User ID tests:\n";
my @valid_ids = (
    'ab',                    # minimum length
    'a' x 32,               # maximum length  
    'user123',              # alphanumeric
    'user.name',            # with dot
    'user_name',            # with underscore
    'user-name',            # with hyphen
    'user@domain.com',      # with at-sign
    'User.123_test-id@x.y'  # complex but valid
);

for my $id (@valid_ids) {
    eval { $auth->validateID($id) };
    my $error = $@;
    
    printf "  %-25s: %s\n", "'" . substr($id, 0, 20) . "'",
           $error ? "✗ rejected: $error" : "✓ accepted";
}

print "\n--- Password Validation Errors ---\n";

# Test invalid passwords
print "Invalid Password tests:\n";
my @invalid_passwords = (
    ['', 'empty string'],
    [undef, 'undefined value'],
    ['short', 'too short (5 chars)'],
    ['1234567', 'too short (7 chars)'],
    ['x' x 73, 'too long (73 chars)'],
);

for my $test (@invalid_passwords) {
    my ($password, $desc) = @$test;
    
    eval { $auth->validatePwd($password) };
    my $error = $@;
    
    printf "  %-20s: %s\n", $desc,
           $error ? "✓ rejected" : "✗ accepted (unexpected)";
           
    if ($error) {
        chomp $error;
        print "    Error: $error\n";
    }
    print "\n";
}

# Test valid passwords
print "Valid Password tests:\n";
my @valid_passwords = (
    'password',              # minimum length (8 chars)
    'secure_password_123',   # good password
    'x' x 72,               # maximum length
    'Pássw0rd!@#$%^&*()',   # Unicode and symbols
    '🔐🔑🗝️',                 # Unicode emoji
);

for my $password (@valid_passwords) {
    eval { $auth->validatePwd($password) };
    my $error = $@;
    
    my $display = length($password) > 20 ? 
                  substr($password, 0, 17) . '...' : 
                  $password;
    
    printf "  %-25s: %s\n", "'$display'",
           $error ? "✗ rejected: $error" : "✓ accepted";
}

print "\n--- Operation Error Handling ---\n";

# Add a valid user for testing
$auth->setPwd('testuser', 'testpassword');

print "User operation error tests:\n";

# Test duplicate user registration
my ($dup_success, $dup_msg) = $auth->setPwd('testuser', 'newpassword');
printf "Duplicate user: %s - %s\n", 
       $dup_success ? "✓ allowed (unexpected)" : "✗ prevented", $dup_msg;

# Test operations on non-existent users
my ($reset_success, $reset_msg) = $auth->resetPwd('nonexistent', 'newpassword');
printf "Reset non-existent: %s - %s\n",
       $reset_success ? "✓ success (unexpected)" : "✗ failed", $reset_msg;

my ($delete_success, $delete_msg) = $auth->deleteID('nonexistent');
printf "Delete non-existent: %s - %s\n",
       $delete_success ? "✓ success (unexpected)" : "✗ failed", $delete_msg;

print "\n--- File Operation Errors ---\n";

# Test operations with invalid file paths
print "File operation error tests:\n";

# Test setFile with invalid path
eval {
    my ($bad_success, $bad_msg) = $auth->setFile('');
    printf "Empty file path: %s\n", $bad_success ? "✓ accepted" : "✗ rejected";
};
if ($@) {
    chomp $@;
    print "Empty file path: ✓ rejected - $@\n";
}

# Test with directory instead of file
my $temp_dir = File::Temp::tempdir(CLEANUP => 1);
eval {
    my ($dir_success, $dir_msg) = $auth->setFile($temp_dir);
    printf "Directory as file: %s - %s\n", 
           $dir_success ? "✓ accepted" : "✗ rejected", $dir_msg;
};
if ($@) {
    chomp $@;  
    print "Directory as file: ✓ rejected - $@\n";
}

print "\n--- Exception vs Return Value Patterns ---\n";

print "Methods that throw exceptions:\n";
my @exception_methods = (
    ['validateID', 'invalid_id!'],
    ['validatePwd', 'short'],
    ['encryptPwd', 'short'],
);

for my $method_test (@exception_methods) {
    my ($method, $bad_input) = @$method_test;
    
    eval { $auth->$method($bad_input) };
    my $error = $@;
    
    printf "  %-15s: %s\n", $method, 
           $error ? "✓ throws exception" : "✗ returns normally";
}

print "\nMethods that return error status:\n";
my @return_methods = (
    ['setPwd', 'testuser', 'password123'],      # duplicate user
    ['resetPwd', 'baduser', 'password123'],     # non-existent user
    ['deleteID', 'baduser'],                    # non-existent user
);

for my $method_test (@return_methods) {
    my ($method, @args) = @$method_test;
    
    my ($success, $message) = $auth->$method(@args);
    
    printf "  %-15s: %s - %s\n", $method,
           $success ? "✓ success" : "✗ error", $message || 'no message';
}

print "\n--- Context-Sensitive Return Values ---\n";

print "Scalar vs List context behavior:\n";

# Test in scalar context
my $scalar_result = $auth->setPwd('newuser', 'password123');
printf "Scalar context: %s (type: %s)\n", 
       $scalar_result, ref($scalar_result) || 'scalar';

# Test in list context  
my ($list_success, $list_message) = $auth->setPwd('newuser2', 'password123');
printf "List context: success=%s, message='%s'\n", $list_success, $list_message;

# Clean up test users
$auth->deleteID('newuser');
$auth->deleteID('newuser2');

print "\n--- Defensive Programming Examples ---\n";

sub safe_user_registration {
    my ($auth, $username, $password) = @_;
    
    # Validate inputs before attempting operation
    eval {
        $auth->validateID($username);
        $auth->validatePwd($password);
    };
    
    if ($@) {
        my $error = $@;
        chomp $error;
        return (0, "Validation failed: $error");
    }
    
    # Check if user already exists
    if ($auth->checkID($username)) {
        return (0, "User already exists");
    }
    
    # Attempt registration
    my ($success, $message) = $auth->setPwd($username, $password);
    
    return ($success, $message);
}

sub safe_user_authentication {
    my ($auth, $username, $password) = @_;
    
    # Basic input validation
    return (0, "Username required") unless defined $username && length $username;
    return (0, "Password required") unless defined $password && length $password;
    
    # Validate inputs
    eval {
        $auth->validateID($username);
        $auth->validatePwd($password);
    };
    
    if ($@) {
        return (0, "Invalid credentials format");
    }
    
    # Check if user exists first
    unless ($auth->checkID($username)) {
        return (0, "Invalid credentials");
    }
    
    # Attempt authentication
    my $authenticated = $auth->checkPwd($username, $password);
    
    return $authenticated ? (1, "Authentication successful") : (0, "Invalid credentials");
}

print "Defensive programming demonstration:\n";

# Test safe registration
my @test_registrations = (
    ['validuser', 'validpassword123', 'should succeed'],
    ['', 'validpassword123', 'should fail - empty username'],
    ['validuser2', 'short', 'should fail - short password'],  
    ['invalid user', 'validpassword123', 'should fail - invalid username'],
    ['validuser', 'validpassword123', 'should fail - duplicate user'],
);

for my $test (@test_registrations) {
    my ($username, $password, $expected) = @$test;
    my ($success, $message) = safe_user_registration($auth, $username, $password);
    
    printf "  Register %-15s: %s (%s)\n",
           "'$username'",
           $success ? "✓ success" : "✗ failed - $message",
           $expected;
}

print "\nAuthentication with defensive validation:\n";

my @test_authentications = (
    ['validuser', 'validpassword123', 'should succeed'],
    ['validuser', 'wrongpassword', 'should fail - wrong password'],
    ['', 'validpassword123', 'should fail - empty username'],
    ['validuser', '', 'should fail - empty password'],
    ['nonexistent', 'anypassword', 'should fail - user not found'],
    ['invalid user', 'anypassword', 'should fail - invalid username format'],
);

for my $test (@test_authentications) {
    my ($username, $password, $expected) = @$test;
    my ($success, $message) = safe_user_authentication($auth, $username, $password);
    
    printf "  Auth %-15s: %s (%s)\n",
           "'$username'",
           $success ? "✓ success" : "✗ failed - $message",
           $expected;
}

print "\n=== Error Handling Complete ===\n";

__END__

=head1 ERROR HANDLING STRATEGIES

=head2 Exception vs Return Values

Concierge::Auth uses two error handling patterns:

B<Exceptions> (die/croak):
- Input validation methods (validateID, validatePwd)
- Internal errors (file I/O failures)
- Programming errors (missing required parameters)

B<Return Values> (success/failure with message):
- User operations (setPwd, resetPwd, deleteID)
- File operations (setFile, clearFile, rmFile)
- Business logic failures

=head2 Best Practices

=over 4

=item * Always validate inputs before processing

=item * Use eval{} blocks around validation methods

=item * Check return values from operational methods

=item * Provide meaningful error messages to users

=item * Log security-relevant failures

=item * Never expose internal errors to end users

=back

=head2 Input Validation Rules

B<User IDs>:
- Length: 2-32 characters
- Characters: letters, numbers, dots, underscores, at-signs, hyphens
- Cannot be empty or undefined

B<Passwords>:
- Length: 8-72 characters (bcrypt limit)
- Any characters allowed including Unicode
- Cannot be empty or undefined

=head1 DEFENSIVE PROGRAMMING PATTERN

    use Concierge::Auth;
    
    sub register_user {
        my ($username, $password) = @_;
        
        # Validate inputs first
        eval {
            $auth->validateID($username);
            $auth->validatePwd($password);
        };
        
        if ($@) {
            return {
                success => 0,
                error   => 'Invalid input format',
                details => $@
            };
        }
        
        # Check business rules
        if ($auth->checkID($username)) {
            return {
                success => 0,
                error   => 'Username already taken'
            };
        }
        
        # Attempt operation
        my ($success, $message) = $auth->setPwd($username, $password);
        
        return {
            success => $success,
            error   => $success ? undef : $message,
            message => $success ? 'User registered successfully' : undef
        };
    }

=head1 SECURITY CONSIDERATIONS

=over 4

=item * Never expose validation error details to prevent enumeration

=item * Log failed authentication attempts for monitoring

=item * Use consistent error messages for invalid credentials

=item * Implement rate limiting to prevent brute force attacks

=item * Sanitize all user input before logging

=back

=head1 SEE ALSO

L<Concierge::Auth>, 08-advanced-usage.pl, 01-basic-authentication.pl

=cut
#!/usr/bin/env perl

=head1 NAME

08-advanced-usage.pl - Advanced usage patterns and integration examples

=head1 DESCRIPTION

Demonstrates advanced Concierge::Auth usage patterns including integration
with web frameworks, CLI applications, and complex authentication scenarios.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempfile tempdir);
use File::Spec;
use Time::HiRes qw(time sleep);

print "=== Advanced Usage Examples ===\n\n";

print "--- Multi-Tier Authentication System ---\n";

# Simulate a multi-tier system with different authentication levels
my $temp_dir = tempdir(CLEANUP => 1);

my %auth_tiers = (
    'public' => Concierge::Auth->new({
        file => File::Spec->catfile($temp_dir, 'public_users.db'),
        sep => "\t"
    }),
    'premium' => Concierge::Auth->new({
        file => File::Spec->catfile($temp_dir, 'premium_users.db'),
        sep => "\t" 
    }),
    'admin' => Concierge::Auth->new({
        file => File::Spec->catfile($temp_dir, 'admin_users.db'),
        sep => "\t"
    }),
    'system' => Concierge::Auth->new({
        file => File::Spec->catfile($temp_dir, 'system_users.db'),
        sep => "\t"
    })
);

# User management with tier system
sub add_user_to_tier {
    my ($username, $password, $tier) = @_;
    $tier ||= 'public';
    
    return unless exists $auth_tiers{$tier};
    
    my ($success, $message) = $auth_tiers{$tier}->setPwd($username, $password);
    return ($success, $message, $tier);
}

sub authenticate_with_tier_check {
    my ($username, $password, $required_tier) = @_;
    $required_tier ||= 'public';
    
    my @tier_hierarchy = qw(public premium admin system);
    my %tier_levels = map { $tier_hierarchy[$_] => $_ } 0..$#tier_hierarchy;
    
    my $required_level = $tier_levels{$required_tier};
    return unless defined $required_level;
    
    # Check authentication in current tier and all higher tiers
    for my $tier (@tier_hierarchy[$required_level..$#tier_hierarchy]) {
        if ($auth_tiers{$tier}->checkPwd($username, $password)) {
            return ($tier, $tier_levels{$tier});
        }
    }
    
    return;
}

# Populate tiers
my @user_data = (
    ['alice', 'user_pass_123', 'public'],
    ['bob', 'premium_pass_456', 'premium'], 
    ['admin', 'admin_super_secure', 'admin'],
    ['root', 'system_level_password', 'system'],
    ['charlie', 'another_user_pass', 'public']
);

print "Setting up multi-tier users:\n";
for my $data (@user_data) {
    my ($username, $password, $tier) = @$data;
    my ($success, $message, $actual_tier) = add_user_to_tier($username, $password, $tier);
    printf "  %-10s in %-8s: %s\n", $username, $tier, 
           $success ? "✓ added" : "✗ failed";
}

print "\nTier-based authentication tests:\n";
my @auth_tests = (
    ['alice', 'user_pass_123', 'public', 'should succeed'],
    ['alice', 'user_pass_123', 'premium', 'should fail - insufficient tier'],
    ['bob', 'premium_pass_456', 'public', 'should succeed - higher tier'],
    ['bob', 'premium_pass_456', 'premium', 'should succeed - exact tier'],
    ['admin', 'admin_super_secure', 'admin', 'should succeed'],
    ['admin', 'admin_super_secure', 'public', 'should succeed - admin can access public'],
    ['root', 'system_level_password', 'system', 'should succeed'],
    ['charlie', 'another_user_pass', 'admin', 'should fail - insufficient tier']
);

for my $test (@auth_tests) {
    my ($username, $password, $required_tier, $expected) = @$test;
    my ($auth_tier, $level) = authenticate_with_tier_check($username, $password, $required_tier);
    
    printf "  %-15s for %-8s: %s (%s)\n",
           "$username/$required_tier",
           $required_tier,
           $auth_tier ? "✓ authenticated as $auth_tier" : "✗ failed",
           $expected;
}

print "\n--- Token-Based Authentication System ---\n";

# Advanced token management with metadata
my $token_auth = Concierge::Auth->new({no_file => 1});

my %active_tokens;

sub generate_advanced_token {
    my ($username, $permissions, $expires_in) = @_;
    $expires_in ||= 3600; # 1 hour default
    
    my $token = $token_auth->gen_random_token(32, 'url_safe');
    my $created_at = time();
    
    $active_tokens{$token} = {
        username    => $username,
        permissions => $permissions || [],
        created_at  => $created_at,
        expires_at  => $created_at + $expires_in,
        last_used   => $created_at,
        use_count   => 0
    };
    
    return $token;
}

sub validate_token_with_permissions {
    my ($token, $required_permission) = @_;
    
    return unless exists $active_tokens{$token};
    
    my $token_data = $active_tokens{$token};
    my $now = time();
    
    # Check expiration
    if ($now > $token_data->{expires_at}) {
        delete $active_tokens{$token};
        return;
    }
    
    # Check permissions if required
    if ($required_permission) {
        my @permissions = @{$token_data->{permissions}};
        return unless grep { $_ eq $required_permission || $_ eq 'admin' } @permissions;
    }
    
    # Update usage stats
    $token_data->{last_used} = $now;
    $token_data->{use_count}++;
    
    return $token_data->{username};
}

# Generate tokens with different permissions
my @token_specs = (
    ['alice', ['read'], 'read-only token'],
    ['bob', ['read', 'write'], 'read-write token'],
    ['admin', ['admin'], 'admin token'],
    ['charlie', ['read', 'write', 'delete'], 'full-access token']
);

print "Generating permission-based tokens:\n";
my %user_tokens;

for my $spec (@token_specs) {
    my ($username, $permissions, $description) = @$spec;
    my $token = generate_advanced_token($username, $permissions);
    $user_tokens{$username} = $token;
    
    printf "  %-10s: %s (%s)\n", $username, substr($token, 0, 16) . '...', $description;
}

print "\nPermission-based access tests:\n";
my @permission_tests = (
    ['alice', 'read', 'should succeed'],
    ['alice', 'write', 'should fail - no write permission'],
    ['bob', 'read', 'should succeed'],
    ['bob', 'write', 'should succeed'],
    ['bob', 'delete', 'should fail - no delete permission'],
    ['admin', 'read', 'should succeed - admin can do anything'],
    ['admin', 'delete', 'should succeed - admin can do anything'],
    ['charlie', 'delete', 'should succeed']
);

for my $test (@permission_tests) {
    my ($username, $permission, $expected) = @$test;
    my $token = $user_tokens{$username};
    my $validated_user = validate_token_with_permissions($token, $permission);
    
    printf "  %-15s for %-8s: %s (%s)\n",
           "$username/$permission",
           $permission,
           $validated_user ? "✓ authorized" : "✗ denied",
           $expected;
}

print "\n--- Rate Limiting and Security Features ---\n";

# Implement rate limiting for authentication attempts
my %failed_attempts;
my $MAX_ATTEMPTS = 3;
my $LOCKOUT_DURATION = 300; # 5 minutes

sub is_locked_out {
    my ($username) = @_;
    
    return unless exists $failed_attempts{$username};
    
    my $attempts = $failed_attempts{$username};
    my $now = time();
    
    # Clean up old attempts
    @$attempts = grep { $_->{timestamp} > ($now - $LOCKOUT_DURATION) } @$attempts;
    
    return scalar @$attempts >= $MAX_ATTEMPTS;
}

sub record_failed_attempt {
    my ($username) = @_;
    
    $failed_attempts{$username} ||= [];
    push @{$failed_attempts{$username}}, {
        timestamp => time(),
        ip_address => '127.0.0.1'  # In real app, get from request
    };
}

sub secure_authenticate {
    my ($auth, $username, $password) = @_;
    
    # Check if user is locked out
    if (is_locked_out($username)) {
        return (0, 'Account temporarily locked due to failed attempts');
    }
    
    # Attempt authentication
    my $success = $auth->checkPwd($username, $password);
    
    if ($success) {
        # Clear failed attempts on successful login
        delete $failed_attempts{$username};
        return (1, 'Authentication successful');
    } else {
        # Record failed attempt
        record_failed_attempt($username);
        return (0, 'Invalid credentials');
    }
}

# Setup test user for rate limiting demo
my ($rate_fh, $rate_file) = tempfile(CLEANUP => 1);
close $rate_fh;
my $rate_auth = Concierge::Auth->new({file => $rate_file});
$rate_auth->setPwd('testuser', 'correct_password');

print "Rate limiting demonstration:\n";

# Simulate multiple failed attempts
for my $attempt (1..5) {
    my ($success, $message) = secure_authenticate($rate_auth, 'testuser', 'wrong_password');
    printf "  Attempt %d: %s - %s\n", $attempt,
           $success ? "✓ success" : "✗ failed", $message;
}

print "\nAttempt with correct password after lockout:\n";
my ($locked_success, $locked_message) = secure_authenticate($rate_auth, 'testuser', 'correct_password');
printf "  Correct password: %s - %s\n",
       $locked_success ? "✓ success" : "✗ failed", $locked_message;

print "\n--- Custom Password Policy ---\n";

# Implement custom password policy
sub validate_password_policy {
    my ($password) = @_;
    
    my @errors;
    
    # Basic length check
    push @errors, "Password must be at least 8 characters" unless length($password) >= 8;
    
    # Complexity requirements
    push @errors, "Password must contain at least one uppercase letter" unless $password =~ /[A-Z]/;
    push @errors, "Password must contain at least one lowercase letter" unless $password =~ /[a-z]/;
    push @errors, "Password must contain at least one number" unless $password =~ /\d/;
    push @errors, "Password must contain at least one special character" unless $password =~ /[^A-Za-z0-9]/;
    
    # Check for common weak patterns
    push @errors, "Password cannot be all numbers" if $password =~ /^\d+$/;
    push @errors, "Password cannot contain repeated characters" if $password =~ /(.)\1{2,}/;
    
    # Dictionary check (simplified)
    my @common_passwords = qw(password 123456 admin letmein welcome);
    push @errors, "Password is too common" if grep { lc($password) eq $_ } @common_passwords;
    
    return @errors;
}

sub register_with_policy {
    my ($auth, $username, $password) = @_;
    
    # Check password policy
    my @policy_errors = validate_password_policy($password);
    if (@policy_errors) {
        return (0, join('; ', @policy_errors));
    }
    
    # Use standard Concierge::Auth registration
    return $auth->setPwd($username, $password);
}

print "Password policy validation:\n";
my @policy_tests = (
    ['ValidPass123!', 'should pass all requirements'],
    ['short', 'should fail - too short'],
    ['alllowercase123!', 'should fail - no uppercase'],
    ['ALLUPPERCASE123!', 'should fail - no lowercase'], 
    ['NoNumbers!', 'should fail - no numbers'],
    ['NoSpecialChars123', 'should fail - no special characters'],
    ['123456789', 'should fail - all numbers'],
    ['aaabbbccc', 'should fail - repeated characters'],
    ['password', 'should fail - common password']
);

for my $test (@policy_tests) {
    my ($password, $expected) = @$test;
    my @errors = validate_password_policy($password);
    
    printf "  %-25s: %s (%s)\n",
           "'$password'",
           @errors ? "✗ failed - " . $errors[0] : "✓ passed",
           $expected;
}

print "\n--- Integration Pattern Examples ---\n";

print "Web application integration pattern:\n";
print <<'EOF';
  # In your web application
  use Concierge::Auth;
  
  my $auth = Concierge::Auth->new({file => '/secure/path/users.db'});
  
  # Registration endpoint
  post '/register' => sub {
      my ($username, $password) = get_params(qw(username password));
      
      my ($success, $message) = register_with_policy($auth, $username, $password);
      
      if ($success) {
          return json({status => 'success', message => 'User registered'});
      } else {
          return json({status => 'error', message => $message});
      }
  };
  
  # Authentication middleware
  before sub {
      my $token = request->header('Authorization');
      my $username = validate_token_with_permissions($token, 'read');
      
      unless ($username) {
          halt 401, json({error => 'Unauthorized'});
      }
      
      var authenticated_user => $username;
  };
EOF

print "CLI application pattern:\n";
print <<'EOF';
  # Command-line application
  use Concierge::Auth;
  use Getopt::Long;
  
  my $auth = Concierge::Auth->new({file => "$ENV{HOME}/.myapp/users"});
  
  GetOptions(
      'register=s' => \my $register_user,
      'login=s'    => \my $login_user,
      'password=s' => \my $password
  );
  
  if ($register_user && $password) {
      my ($success, $msg) = $auth->setPwd($register_user, $password);
      print $success ? "Registration successful\n" : "Error: $msg\n";
  }
EOF

print "\n=== Advanced Usage Complete ===\n";

__END__

=head1 ADVANCED PATTERNS

=head2 Multi-Tier Authentication

Implement hierarchical access control:

    # Higher tiers can access lower-tier resources
    # Lower tiers cannot access higher-tier resources
    
    my %auth_tiers = (
        public  => Concierge::Auth->new({file => 'public.db'}),
        premium => Concierge::Auth->new({file => 'premium.db'}),
        admin   => Concierge::Auth->new({file => 'admin.db'})
    );

=head2 Token-Based Security

Advanced token management:

    # Include permissions and expiration in token metadata
    # Validate permissions on each request
    # Track usage statistics
    # Implement token refresh mechanisms

=head2 Rate Limiting

Prevent brute force attacks:

    # Track failed authentication attempts
    # Implement progressive lockout periods
    # Log security events
    # Consider IP-based restrictions

=head2 Password Policies

Enforce security requirements:

    # Minimum length and complexity
    # Prevent common passwords
    # Check for patterns and repetition
    # Integrate with breach databases

=head1 PRODUCTION CONSIDERATIONS

=head2 Scalability

=over 4

=item * Use database backends for large user bases

=item * Implement connection pooling

=item * Cache authentication results appropriately

=item * Consider sharding strategies for massive scale

=back

=head2 Security

=over 4

=item * Store authentication files outside web roots

=item * Use HTTPS for all authentication endpoints

=item * Implement proper session management

=item * Log all security-relevant events

=item * Regular security audits and updates

=back

=head2 Monitoring

=over 4

=item * Track authentication success/failure rates

=item * Monitor for suspicious patterns

=item * Alert on security events

=item * Performance monitoring for auth operations

=back

=head1 FRAMEWORK INTEGRATION

=head2 Web Frameworks

Concierge::Auth integrates well with:

=over 4

=item * Mojolicious - Use as authentication helper

=item * Dancer2 - Implement as before hook

=item * Catalyst - Create authentication realm

=item * Plack - Middleware for token validation

=back

=head2 Database Integration

Extend with database backends:

=over 4

=item * DBI - Store user metadata in database

=item * DBIx::Class - ORM integration

=item * Redis - Session and token storage

=item * Memcached - Authentication result caching

=back

=head1 SEE ALSO

L<Concierge::Auth>, L<Crypt::Passphrase>, L<Crypt::PRNG>

=cut
# Concierge::Auth Examples

Comprehensive usage examples for the Concierge::Auth module demonstrating authentication, token generation, and security best practices.

## Overview

Concierge::Auth provides secure local authentication using Argon2 password hashing with bcrypt compatibility. These examples showcase various usage patterns from basic authentication to advanced integration scenarios.

## Running Examples

### Quick Start
```bash
# From the examples directory
cd /path/to/Local/examples/Auth

# Run individual examples
perl 01-basic-authentication.pl
perl 02-user-management.pl
perl 03-token-generation.pl
```

### All Examples
```bash
# Run all examples in sequence
for example in *.pl; do
    echo "=== Running $example ==="
    perl "$example"
    echo
done
```

## Example Files

### 01-basic-authentication.pl
**Core authentication functionality**
- User registration and login
- Password verification
- User existence checking
- Basic error handling

**Key Concepts:**
- Creating auth systems
- Registering users with setPwd()
- Authenticating with checkPwd()
- Checking user existence with checkID()

### 02-user-management.pl
**User lifecycle operations**
- Password resets
- User deletion
- Duplicate prevention
- Operation validation

**Key Concepts:**
- Password changes with resetPwd()
- User removal with deleteID()
- Preventing duplicate registrations
- Verifying operations succeeded

### 03-token-generation.pl
**Token generation utilities**
- URL-safe tokens for sessions
- Alphanumeric tokens for user codes
- Custom character sets
- UUIDs and word phrases

**Key Concepts:**
- gen_random_token() variations
- Character set selection
- Cryptographic tokens
- Word phrase generation

### 04-session-management.pl
**Session handling system**
- Session creation and validation
- Token-based authentication
- Session expiration
- Logout functionality

**Key Concepts:**
- Token-based sessions
- Session metadata storage
- Timeout handling
- Security best practices

### 05-api-keys.pl
**API key management**
- Structured key generation
- Permission-based access
- Key format design
- Usage tracking

**Key Concepts:**
- Structured API key formats
- Permission validation
- Key type differentiation
- Metadata extraction

### 06-file-management.pl
**Authentication file operations**
- Multiple file systems
- File format variations
- Backup and recovery
- Permission management

**Key Concepts:**
- Multi-file authentication
- Custom field separators
- File validation
- Secure file operations

### 07-error-handling.pl
**Error handling and validation**
- Input validation patterns
- Exception vs return values
- Defensive programming
- Security considerations

**Key Concepts:**
- Validation error handling
- Safe input processing
- Context-sensitive returns
- Security-aware error messages

### 08-advanced-usage.pl
**Complex integration patterns**
- Multi-tier authentication
- Advanced token systems
- Rate limiting
- Production considerations

**Key Concepts:**
- Hierarchical access control
- Token permissions and expiration
- Brute force protection
- Framework integration

## Key Features Demonstrated

### Security Features
- ✅ Argon2 password hashing
- ✅ Cryptographically secure tokens
- ✅ File locking and atomic operations
- ✅ Input validation and sanitization
- ✅ Rate limiting and lockout protection

### Authentication Patterns
- ✅ Basic username/password auth
- ✅ Token-based authentication
- ✅ Session management
- ✅ API key validation
- ✅ Multi-tier access control

### Token Generation
- ✅ URL-safe tokens (sessions, APIs)
- ✅ Alphanumeric codes (user-facing)
- ✅ Custom character sets
- ✅ UUIDs for unique identifiers
- ✅ Word phrases for memorable passwords

### File Management
- ✅ Multiple authentication files
- ✅ Custom field separators
- ✅ Safe file operations
- ✅ Backup and cleanup

## Production Usage Patterns

### Web Application Integration
```perl
use Concierge::Auth;

# Initialize auth system
my $auth = Concierge::Auth->new({file => '/secure/path/users.db'});

# Registration endpoint
sub handle_register {
    my ($username, $password) = @_;
    my ($success, $message) = $auth->setPwd($username, $password);
    return $success ? success_response() : error_response($message);
}

# Authentication middleware
sub authenticate_request {
    my $token = get_session_token();
    my $username = validate_session($token);
    return $username || unauthorized_response();
}
```

### CLI Application
```perl
use Concierge::Auth;

# User management CLI
my $auth = Concierge::Auth->new({file => "$ENV{HOME}/.myapp/users"});

# Command handlers
sub cmd_register {
    my ($username, $password) = @_;
    my ($success, $msg) = $auth->setPwd($username, $password);
    print $success ? "User registered\n" : "Error: $msg\n";
}
```

### API Service
```perl
use Concierge::Auth;

# Token-based API
my $auth = Concierge::Auth->new({no_file => 1});

# Generate API keys
sub generate_api_key {
    my ($user_id, $permissions) = @_;
    return $auth->gen_random_token(32, 'url_safe');
}
```

## Best Practices

### Security
- Store auth files outside web-accessible directories
- Use HTTPS for all authentication endpoints
- Implement proper session management
- Log security events for monitoring
- Regular password policy updates

### Error Handling
- Validate inputs before processing
- Use consistent error messages
- Don't expose internal errors to users
- Implement proper logging
- Handle edge cases gracefully

### Performance
- Cache authentication results appropriately
- Use efficient file operations
- Consider database backends for large scale
- Monitor authentication performance
- Implement reasonable timeouts

## Testing Your Integration

```bash
# Test basic functionality
perl -MConcierge::Auth -e '
    my $auth = Concierge::Auth->new({file => "/tmp/test.db"});
    my ($s, $m) = $auth->setPwd("test", "password123");
    print $s ? "✓ Registration works\n" : "✗ Registration failed: $m\n";
    my $ok = $auth->checkPwd("test", "password123");
    print $ok ? "✓ Authentication works\n" : "✗ Authentication failed\n";
'

# Test token generation
perl -MConcierge::Auth -e '
    my $auth = Concierge::Auth->new({no_file => 1});
    print "Session token: " . $auth->gen_random_token(24) . "\n";
    print "API key: " . $auth->gen_random_token(32, "alphanumeric") . "\n";
    print "UUID: " . $auth->gen_uuid() . "\n";
'
```

## Common Patterns

### User Registration Flow
1. Validate input format
2. Check if user already exists
3. Hash password securely
4. Store user credentials
5. Return success/failure

### Authentication Flow
1. Validate input format
2. Look up user credentials
3. Verify password against hash
4. Generate session token on success
5. Return authentication result

### Session Management
1. Generate secure session token
2. Store session metadata
3. Validate token on each request
4. Update last active timestamp
5. Handle session expiration

## Security Considerations

- **Password Security**: Uses Argon2 for new passwords, bcrypt compatibility
- **File Security**: Restrictive permissions (0600), atomic operations
- **Token Security**: Cryptographically secure random generation
- **Input Validation**: Comprehensive validation with clear error messages
- **Concurrent Access**: File locking prevents corruption

## See Also

- [Concierge::Auth POD Documentation](../Auth.pm)
- [Test Suite](../tests/Auth/)
- [CPAN Page](https://metacpan.org/pod/Concierge::Auth) (when published)

## Support

For questions, bug reports, or feature requests, please contact the maintainer or create an issue in the project repository.
# Concierge::Auth

Concierge authorization using Crypt::Passphrase - a production-ready authentication and authorization framework.

## VERSION

v0.3.2

## DESCRIPTION

Concierge::Auth provides comprehensive user authentication and authorization capabilities using Crypt::Passphrase for secure password management. It supports file-based user storage, token generation, session management, and API key handling.

## FEATURES

- **Secure Password Management**: Argon2 encoder with Bcrypt fallback validators
- **User Authentication**: File-based user authentication with encrypted passwords
- **Token Generation**: Generate cryptographically secure tokens and UUIDs
- **Password Utilities**: Password strength validation, random string generation
- **Session Management**: Support for session-based authentication
- **API Key Management**: Generate and validate API keys
- **File Management**: Secure user file operations with proper locking
- **Generator Architecture**: Extensible generator system for tokens and identifiers

## MODULE STRUCTURE

- **Concierge::Auth** - Main authentication framework
- **Concierge::Auth::Generators** - Token and identifier generation system

## INSTALLATION

From source:
```bash
perl Makefile.PL
make
make test
make install
```

From CPAN:
```bash
cpanm Concierge::Auth
```

## QUICK START

```perl
use Concierge::Auth;

# Initialize auth with a password file
my $auth = Concierge::Auth->new({
    file => '/path/to/users.passwd',
});

# Or initialize without a file (utilities only)
my $auth_util = Concierge::Auth->new({
    no_file => 1,
});

# Authenticate a user
my ($ok, $msg) = $auth->checkID($user_id);
my ($ok, $msg) = $auth->checkPwd($user_id, $password);

# Create a new user
($ok, $msg) = $auth->setPwd($user_id, $password);

# Change password
($ok, $msg) = $auth->resetPwd($user_id, $new_password);

# Delete a user
($ok, $msg) = $auth->deleteID($user_id);

# Generate a token
my ($token, $msg) = $auth->gen_random_token();

# Generate a random string
my ($random, $msg) = $auth->gen_random_string(16);

# Generate a UUID
my ($uuid, $msg) = $auth->gen_uuid();
```

## DEVELOPMENT

### Repository Structure

```
Concierge-Auth/
├── lib/Concierge/          # Source modules
│   ├── Auth.pm             # Main module
│   └── Auth/               # Submodules
│       └── Generators.pm   # Generator system
├── examples/               # Example scripts
│   ├── 01-basic-authentication.pl
│   ├── 02-user-management.pl
│   ├── 03-token-generation.pl
│   ├── 04-session-management.pl
│   ├── 05-api-keys.pl
│   ├── 06-file-management.pl
│   ├── 07-error-handling.pl
│   ├── 08-advanced-usage.pl
│   ├── 09-generators-architecture.pl
│   ├── 10-architecture-comparison.pl
│   └── README.md
├── t/                      # Test suite
│   ├── 00-load.t
│   ├── 01-constructor.t
│   ├── 02-validation.t
│   ├── 03-auth.t
│   └── 04-file-management.t
├── Changes                # Revision history
├── MANIFEST               # Distribution file list
├── Makefile.PL            # CPAN installation script
└── README.md              # This file
```

### Development Workflow

1. **Edit** files in the Git repository
2. **Test** using blib (doesn't affect installed version):
   ```bash
   perl Makefile.PL
   make
   prove -blib t/*.t
   ```
3. **Commit** changes to Git
4. **Install** when ready for production:
   ```bash
   make install
   ```

This workflow lets you:
- Develop and test without breaking your production Perl environment
- Keep stable versions installed while working on new features
- Install to site_perl only when changes are tested and ready

## REQUIREMENTS

- Perl 5.36 or higher
- Carp
- Fcntl
- Crypt::Passphrase
- Crypt::PRNG
- Time::HiRes
- parent
- Exporter
- Test2::V0 (for testing)

## PASSWORD SECURITY

Concierge::Auth uses Crypt::Passphrase with:
- **Primary Encoder**: Argon2 (memory-hard, resistant to GPU/ASIC attacks)
- **Fallback Validators**: Bcrypt (for backward compatibility)
- **Password Length**: 8-72 characters (bcrypt limit)
- **User ID Validation**: 2-32 characters, alphanumeric plus . _ @ -

## PRODUCTION USE

Concierge::Auth is actively used in production environments. Key features for production:

- **File Locking**: Proper flock() support for concurrent access
- **Secure Defaults**: Argon2 encoder with reasonable defaults
- **Error Handling**: Comprehensive error checking and reporting
- **Token Security**: Cryptographically secure random token generation
- **Flexible Architecture**: Works with or without password files

## INTEGRATION

Concierge::Auth integrates with the Concierge ecosystem:
- **Concierge::Users** - User data management
- **Concierge::Sessions** - Session management

These modules together form the core of the Concierge service layer, providing:
- Authentication (Concierge::Auth)
- User data management (Concierge::Users)
- Session tracking (Concierge::Sessions)

## EXAMPLES

The `examples/` directory contains comprehensive examples covering:
1. Basic authentication
2. User management
3. Token generation
4. Session management
5. API keys
6. File management
7. Error handling
8. Advanced usage
9. Generators architecture
10. Architecture comparison

See `examples/README.md` for full details.

## ARCHITECTURE

Concierge::Auth follows a service layer pattern:
- **Constructor**: May die on fatal errors (file permissions)
- **Methods**: Never die, always return (success, message) tuples
- **Response Pattern**: confirm(), reject(), reply() helper methods
- **Graceful Degradation**: Falls back to alternative methods when possible

The module uses modern Perl practices:
- v5.36+ syntax
- Type validation
- Consistent error handling
- Clear separation of concerns

## AUTHOR

Bruce Van Allen <bva@cruzio.com>

## LICENSE

Artistic License 2.0

## SEE ALSO

- Concierge::Users
- Concierge::Sessions
- Crypt::Passphrase
- Crypt::PRNG

## CHANGES

See Changes file for revision history.

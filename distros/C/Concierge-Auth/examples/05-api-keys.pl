#!/usr/bin/env perl

=head1 NAME

05-api-keys.pl - API key management example

=head1 DESCRIPTION

Demonstrates generating and managing API keys for different
access levels and applications using Concierge::Auth.

=cut

use strict;
use warnings;
use Concierge::Auth;
use File::Temp qw(tempfile);

print "=== API Key Management Example ===\n\n";

# Initialize auth system (no file needed for token generation)
my $auth = Concierge::Auth->new({no_file => 1});

# API key generation functions
sub generate_api_key {
    my ($username, $app_name, $key_type, $permissions) = @_;
    
    $key_type ||= 'standard';
    $app_name ||= 'default';
    
    # Create prefix from username and app
    my $user_prefix = uc(substr($username, 0, 3));
    my $app_prefix = uc(substr($app_name, 0, 3));
    
    # Timestamp component
    my $timestamp = sprintf("%08x", time());
    
    # Generate key component based on type
    my ($key_part, $suffix);
    if ($key_type eq 'readonly') {
        $key_part = $auth->gen_random_token(20, 'alphanumeric');
        $suffix = 'RO';
    } elsif ($key_type eq 'admin') {
        $key_part = $auth->gen_random_token(32, 'url_safe');
        $suffix = 'ADM';
    } elsif ($key_type eq 'webhook') {
        $key_part = $auth->gen_random_token(24, 'alphanumeric');
        $suffix = 'WHK';
    } else {  # standard
        $key_part = $auth->gen_random_token(24, 'url_safe');
        $suffix = 'STD';
    }
    
    my $api_key = "${user_prefix}_${app_prefix}_${timestamp}_${key_part}_${suffix}";
    
    return {
        key         => $api_key,
        username    => $username,
        app_name    => $app_name,
        key_type    => $key_type,
        permissions => $permissions || [],
        created_at  => time(),
        last_used   => undef
    };
}

sub extract_key_info {
    my ($api_key) = @_;
    
    # Parse the structured key format
    if ($api_key =~ /^([A-Z]{3})_([A-Z]{3})_([0-9a-fA-F]{8})_([A-Za-z0-9_-]+)_([A-Z]{2,3})$/) {
        my ($user_prefix, $app_prefix, $timestamp, $key_part, $suffix) = ($1, $2, $3, $4, $5);
        
        my %type_map = (
            'RO'  => 'readonly',
            'ADM' => 'admin', 
            'WHK' => 'webhook',
            'STD' => 'standard'
        );
        
        return {
            user_prefix => $user_prefix,
            app_prefix  => $app_prefix,
            timestamp   => hex($timestamp),
            key_part    => $key_part,
            key_type    => $type_map{$suffix} || 'unknown',
            created_at  => hex($timestamp)
        };
    }
    
    return;
}

print "--- API Key Generation ---\n";

# Generate keys for different users and applications
my @key_specs = (
    ['alice',   'webapp',     'standard', ['read', 'write']],
    ['alice',   'mobile',     'readonly', ['read']],
    ['bob',     'dashboard',  'admin',    ['read', 'write', 'delete', 'admin']],
    ['charlie', 'webhook',    'webhook',  ['webhook']],
    ['alice',   'backup',     'readonly', ['read', 'export']]
);

my @generated_keys;

for my $spec (@key_specs) {
    my ($username, $app, $type, $perms) = @$spec;
    my $key_info = generate_api_key($username, $app, $type, $perms);
    push @generated_keys, $key_info;
    
    printf "%-8s/%-10s (%s): %s\n",
           $username, $app, $type, $key_info->{key};
}

print "\n--- Key Information Extraction ---\n";

for my $key_info (@generated_keys) {
    my $extracted = extract_key_info($key_info->{key});
    
    if ($extracted) {
        printf "Key: %s...\n", substr($key_info->{key}, 0, 20);
        printf "  User prefix: %s | App prefix: %s | Type: %s\n",
               $extracted->{user_prefix}, $extracted->{app_prefix}, $extracted->{key_type};
        printf "  Created: %s\n", scalar localtime($extracted->{created_at});
    }
    print "\n";
}

print "--- Key Type Examples ---\n";

# Demonstrate different key types and their characteristics
my %key_types = (
    'readonly' => {
        desc => 'Read-only access, safe for client-side use',
        perms => ['read', 'list', 'export'],
        length => 'medium'
    },
    'standard' => {
        desc => 'Standard API access for most applications', 
        perms => ['read', 'write', 'update'],
        length => 'medium'
    },
    'admin' => {
        desc => 'Full administrative access',
        perms => ['read', 'write', 'delete', 'admin', 'user_management'],
        length => 'long'
    },
    'webhook' => {
        desc => 'Webhook validation and callbacks',
        perms => ['webhook', 'callback', 'event_receive'],
        length => 'medium'
    }
);

for my $type (sort keys %key_types) {
    my $info = $key_types{$type};
    my $sample_key = generate_api_key('demo', 'example', $type, $info->{perms});
    
    printf "%-10s: %s\n", uc($type), $info->{desc};
    printf "%-10s  Key: %s\n", '', $sample_key->{key};
    printf "%-10s  Permissions: %s\n", '', join(', ', @{$info->{perms}});
    printf "%-10s  Length: %d chars\n", '', length($sample_key->{key});
    print "\n";
}

print "--- Structured Key Benefits ---\n";

print "Key format: {USER}_{APP}_{TIMESTAMP}_{RANDOM}_{TYPE}\n\n";

print "Benefits of structured keys:\n";
print "  ✓ User identification without database lookup\n";
print "  ✓ Application context for logging and analytics\n";
print "  ✓ Timestamp for age-based policies\n";  
print "  ✓ Type suffix for permission quick-checking\n";
print "  ✓ Random component for security\n";
print "  ✓ Consistent format for validation\n";

print "\n--- Alternative Key Formats ---\n";

# Simple keys
print "Simple keys (no structure):\n";
for my $i (1..3) {
    my $simple = $auth->gen_random_token(32, 'alphanumeric');
    printf "  %d: %s\n", $i, $simple;
}

# UUID-based keys  
print "\nUUID-based keys:\n";
for my $i (1..3) {
    my $uuid = $auth->gen_uuid();
    printf "  %d: api_%s\n", $i, $uuid;
}

# Prefixed random keys
print "\nPrefixed random keys:\n";  
for my $i (1..3) {
    my $random = $auth->gen_random_token(28, 'url_safe');
    printf "  %d: ak_%s\n", $i, $random;
}

print "\n--- Key Management Best Practices ---\n";

print "Generation:\n";
print "  ✓ Use cryptographically secure random sources\n";
print "  ✓ Sufficient length for security (24+ characters)\n";
print "  ✓ Clear format for easy identification\n";
print "  ✓ Include metadata in structure when helpful\n";

print "\nStorage:\n"; 
print "  ✓ Hash keys before database storage\n";
print "  ✓ Store key metadata separately\n";
print "  ✓ Implement key rotation policies\n";
print "  ✓ Log key usage for security auditing\n";

print "\nValidation:\n";
print "  ✓ Validate format before database lookup\n";
print "  ✓ Check key type matches endpoint requirements\n";
print "  ✓ Implement rate limiting per key\n";
print "  ✓ Track and limit key usage\n";

print "\n=== API Key Management Complete ===\n";

__END__

=head1 API KEY DESIGN PATTERNS

=head2 Structured Keys

Format: {USER}_{APP}_{TIMESTAMP}_{RANDOM}_{TYPE}

Benefits:
- Immediate identification of key owner
- Application context for analytics  
- Age information for policies
- Permission type for quick validation
- Still cryptographically secure

=head2 Simple Keys

Format: Random string only

Benefits:
- Maximum entropy per character
- No information leakage
- Simpler validation
- Shorter keys possible

=head2 UUID-Based Keys

Format: Standard UUID with prefix

Benefits:
- Guaranteed uniqueness
- Standard format
- Database-friendly
- No collision risk

=head1 KEY MANAGEMENT WORKFLOW

=over 4

=item 1. B<Generation> - Create key with appropriate type and permissions

=item 2. B<Registration> - Store hashed key and metadata in database

=item 3. B<Distribution> - Securely deliver key to user/application

=item 4. B<Validation> - Verify key on each API request

=item 5. B<Auditing> - Log key usage for security monitoring

=item 6. B<Rotation> - Periodically replace keys

=item 7. B<Revocation> - Disable compromised or unused keys

=back

=head1 INTEGRATION EXAMPLE

    use Concierge::Auth;
    
    my $auth = Concierge::Auth->new({no_file => 1});
    
    # API key middleware
    sub validate_api_key {
        my ($request) = @_;
        
        my $api_key = $request->header('Authorization') 
                   || $request->param('api_key');
        
        return unless $api_key;
        
        # Remove 'Bearer ' prefix if present
        $api_key =~ s/^Bearer\s+//i;
        
        # Validate key format
        my $key_info = extract_key_info($api_key);
        return unless $key_info;
        
        # Look up key in database (implementation specific)
        my $key_record = lookup_key_in_database($api_key);
        return unless $key_record && $key_record->{active};
        
        # Check permissions for current endpoint
        my $required_perm = get_endpoint_permission($request->path);
        return unless has_permission($key_record, $required_perm);
        
        # Update last used timestamp
        update_key_usage($api_key);
        
        return $key_record;
    }

=head1 SEE ALSO

L<Concierge::Auth>, 04-session-management.pl, 06-file-management.pl

=cut
#!/usr/bin/env perl

=head1 NAME

03-token-generation.pl - Token generation utilities example

=head1 DESCRIPTION

Demonstrates various token generation methods available in Concierge::Auth
for sessions, API keys, UUIDs, and word phrases.

=cut

use strict;
use warnings;
use Concierge::Auth;

print "=== Token Generation Examples ===\n\n";

# Create auth instance (no file needed for token generation)
my $auth = Concierge::Auth->new({no_file => 1});

print "--- Random Tokens (URL-Safe) ---\n";
print "Default tokens (13 chars, URL-safe):\n";
for my $i (1..5) {
    my $token = $auth->gen_random_token();
    printf "%2d: %s (length: %d)\n", $i, $token, length($token);
}

print "\nCustom length tokens:\n";
my @lengths = (8, 16, 24, 32, 48);
for my $length (@lengths) {
    my $token = $auth->gen_random_token($length);
    printf "%2d chars: %s\n", $length, $token;
}

print "\n--- Character Set Variations ---\n";

print "Alphanumeric only (no symbols):\n";
for my $i (1..3) {
    my $token = $auth->gen_random_token(16, 'alphanumeric');
    printf "%2d: %s\n", $i, $token;
}

print "\nURL-safe (explicit):\n"; 
for my $i (1..3) {
    my $token = $auth->gen_random_token(16, 'url_safe');
    printf "%2d: %s\n", $i, $token;
}

print "\nCustom character sets:\n";
my %custom_sets = (
    'Hex'        => '0123456789ABCDEF',
    'Vowels'     => 'AEIOU',
    'Numbers'    => '0123456789',
    'Letters'    => 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
);

for my $name (sort keys %custom_sets) {
    my $charset = $custom_sets{$name};
    my $token = $auth->gen_random_token(12, $charset);
    printf "%-8s: %s\n", $name, $token;
}

print "\n--- Cryptographic Tokens ---\n";
print "Time-based cryptographic tokens:\n";
for my $i (1..5) {
    my $token = $auth->gen_crypt_token();
    printf "%2d: %s (length: %d)\n", $i, $token, length($token);
}

print "\n--- UUID Generation ---\n";
print "Standard UUIDs:\n";
for my $i (1..5) {
    my $uuid = $auth->gen_uuid();
    printf "%2d: %s\n", $i, $uuid;
}

print "\n--- Random Strings (Full Character Set) ---\n";
print "Using Crypt::PRNG full character set:\n";
for my $i (1..3) {
    my $string = $auth->gen_random_string(16);
    printf "%2d: %s\n", $i, $string;
}

print "\n--- Word Phrase Generation ---\n";

# Check if default word file exists
my $word_file = '/usr/share/dict/web2';
if (-r $word_file) {
    print "Using system word file ($word_file):\n";
    
    print "\nDefault phrases (4 words, no separator):\n";
    for my $i (1..3) {
        my $phrase = $auth->gen_word_phrase();
        printf "%2d: %s\n", $i, $phrase;
    }
    
    print "\nCustom phrases (3 words, hyphen-separated):\n";
    for my $i (1..3) {
        my $phrase = $auth->gen_word_phrase(3, 4, 7, '-');
        printf "%2d: %s\n", $i, $phrase;
    }
    
    print "\nShort phrases (2 words, underscore-separated):\n";
    for my $i (1..3) {
        my $phrase = $auth->gen_word_phrase(2, 3, 5, '_');
        printf "%2d: %s\n", $i, $phrase;
    }
    
} else {
    print "System word file not available, creating demo word file:\n";
    
    # Create temporary word file for demonstration
    use File::Temp qw(tempfile);
    my ($word_fh, $temp_word_file) = tempfile(CLEANUP => 1);
    my @demo_words = qw(
        Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa Lambda Mu
        apple banana cherry grape orange peach plum berry melon lemon
        house garden bridge castle tower forest meadow valley mountain stream
    );
    print $word_fh join("\n", @demo_words) . "\n";
    close $word_fh;
    
    print "Demo phrases from custom word list:\n";
    for my $i (1..3) {
        my $phrase = $auth->gen_word_phrase(3, 4, 7, '-', $temp_word_file);
        printf "%2d: %s\n", $i, $phrase;
    }
}

print "\n--- Practical Token Applications ---\n";

print "Session tokens (24 chars, URL-safe):\n";
for my $i (1..3) {
    my $token = $auth->gen_random_token(24, 'url_safe');
    printf "Session %d: %s\n", $i, $token;
}

print "\nAPI keys (32 chars, alphanumeric):\n";
for my $i (1..3) {
    my $token = $auth->gen_random_token(32, 'alphanumeric');
    printf "API-key-%d: %s\n", $i, $token;
}

print "\nTemporary passwords (12 chars, mixed):\n";
for my $i (1..3) {
    my $temp_pass = $auth->gen_random_token(12, 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789');
    printf "TempPass%d: %s\n", $i, $temp_pass;
}

print "\n=== Token Generation Complete ===\n";

__END__

=head1 TOKEN TYPES AND USE CASES

=head2 URL-Safe Tokens

Best for: Web sessions, API tokens, URL parameters
Characters: A-Z, a-z, 0-9, _, -
Safe for URLs without encoding.

=head2 Alphanumeric Tokens  

Best for: User-facing codes, confirmation tokens
Characters: A-Z, a-z, 0-9
No confusing symbols, easy to type.

=head2 Cryptographic Tokens

Best for: Security-critical applications
Uses time-based seeds and character substitution.
Good entropy but deterministic for testing.

=head2 UUIDs

Best for: Unique identifiers, database keys
Standard UUID format, globally unique.
Compatible with UUID fields in databases.

=head2 Word Phrases

Best for: Memorable passwords, human-friendly tokens
Easier to remember than random character strings.
Customizable length and separator.

=head1 SECURITY CONSIDERATIONS

=over 4

=item * All random functions use cryptographically secure sources

=item * Token length affects security - longer is better

=item * URL-safe tokens prevent encoding issues

=item * Word phrases may have lower entropy per character

=item * UUIDs provide good uniqueness but are predictable in format

=back

=head1 SEE ALSO

L<Concierge::Auth>, 01-basic-authentication.pl, 04-session-management.pl

=cut
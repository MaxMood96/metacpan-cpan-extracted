#!/usr/bin/env perl

use v5.40;
use strict;
use warnings;
use lib '../../';

# Demonstrates the new Concierge::Auth::Generators architecture

use Concierge::Auth;
use Concierge::Auth::Generators qw(gen_uuid gen_random_token gen_random_string gen_word_phrase gen_crypt_token);

say "=" x 70;
say "Concierge::Auth::Generators Architecture Demonstration";
say "=" x 70;
say "";

say "1. DIRECT FUNCTIONAL USAGE (no Auth object needed)";
say "-" x 70;

# Scalar context - direct value
my $uuid = gen_uuid();
say "Scalar context: gen_uuid() = $uuid";

# List context - value + message
my ($uuid2, $msg) = gen_uuid();
say "List context: gen_uuid() = $uuid2";
say "             Message: $msg";
say "";

say "2. VIA Auth.pm OBJECT METHODS";
say "-" x 70;

# Create Auth object in utility-only mode
my $auth = Concierge::Auth->new({no_file => 1});

# Scalar context - direct value
my $token = $auth->gen_random_token(32);
say "Scalar context: \$auth->gen_random_token(32) = $token";

# List context - value + message
my ($token2, $msg2) = $auth->gen_random_token(16);
say "List context: \$auth->gen_random_token(16) = $token2";
say "              Message: $msg2";
say "";

say "3. ALL GENERATOR TYPES";
say "-" x 70;

# gen_uuid
my ($uuid_val, $uuid_msg) = $auth->gen_uuid();
say "UUID: $uuid_val";
say "     ($uuid_msg)";
say "";

# gen_random_token
my ($token_val, $token_msg) = $auth->gen_random_token(24);
say "Random Token (24): $token_val";
say "                  ($token_msg)";
say "";

# gen_random_string with charset
my ($str_val, $str_msg) = $auth->gen_random_string(20, 'abcdef0123456789');
say "Random String (hex): $str_val";
say "                   ($str_msg)";
say "";

# gen_word_phrase
my ($phrase_val, $phrase_msg) = $auth->gen_word_phrase(4, 4, 7, '-');
say "Word Phrase: $phrase_val";
say "             ($phrase_msg)";
say "";

# gen_crypt_token
my ($crypt_val, $crypt_msg) = $auth->gen_crypt_token();
say "Crypt Token: $crypt_val";
say "            ($crypt_msg)";
say "";

say "4. ERROR HANDLING AND FALLBACKS";
say "-" x 70;

# gen_word_phrase works even if word file unavailable
# Falls back to random "words"
my ($fallback_phrase, $fallback_msg) = $auth->gen_word_phrase(3, 4, 7, ' ');
say "Fallback Phrase: $fallback_phrase";
say "                 ($fallback_msg)";
say "";

# gen_uuid falls back if uuidgen unavailable
# (on systems without uuidgen command)
my ($fallback_uuid, $fallback_uuid_msg) = $auth->gen_uuid();
say "UUID (or fallback): $fallback_uuid";
say "                   ($fallback_uuid_msg)";
say "";

say "5. BACKWARDS COMPATIBILITY";
say "-" x 70;

# Old usage patterns still work
my $simple_uuid = $auth->gen_uuid();
say "Direct scalar usage still works: $simple_uuid";

# Boolean context works (value is truthy if defined)
if ($auth->gen_uuid()) {
    my $bool_uuid = $auth->gen_uuid();
    say "Boolean context works: $bool_uuid";
}
say "";

say "6. ARCHITECTURAL BENEFITS";
say "-" x 70;
say "";
say "✓ Separation of concerns: Generators in separate module";
say "✓ Plain subroutines: Can be exported for functional use";
say "✓ OO wrappers: Auth.pm provides response pattern consistency";
say "✓ Inheritance: Auth.pm inherits via 'use parent'";
say "✓ No fatal errors: Generators return undef on failure";
say "✓ Graceful fallbacks: uuidgen → random token, dict → random words";
say "✓ Flexible context: Scalar (value) or list (value + message)";
say "";
say "=" x 70;
say "Architecture successfully separates utilities from authentication logic";
say "=" x 70;

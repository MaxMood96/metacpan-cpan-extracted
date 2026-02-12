package Concierge::Auth::Generators v0.3.2;
use v5.36;

# ABSTRACT: Value generation utilities for Concierge::Auth

use Carp qw/carp/;
use Time::HiRes qw/gettimeofday/;
use Crypt::PRNG qw/rand random_string random_string_from/;
use Exporter 'import';

our @EXPORT_OK = qw(
    gen_uuid
    gen_random_token
    gen_crypt_token
    gen_random_string
    gen_word_phrase
);

our %EXPORT_TAGS	= (
	str 	=> [qw/gen_random_string gen_word_phrase/],
	rand	=> [qw/gen_random_token gen_random_string/],
	tok		=> [qw/gen_random_token gen_crypt_token gen_uuid/],
	all		=> [qw/gen_uuid gen_random_token gen_crypt_token gen_random_string gen_word_phrase/],
);

## Generator response methods
## These provide non-fatal error handling in generator functions
##
## Usage:
##   return g_success($value, $message)  # Success with value
##   return g_error($message)             # Failure with undef

sub g_success {
    my $value   = shift;
    my $message = shift || "Generation successful.";
    wantarray ? ($value, $message) : $value;
}

sub g_error {
    my $message = shift || "Generation failed.";
    wantarray ? (undef, $message) : undef;
}

## gen_uuid: generate a UUID using uuidgen command
## Returns: UUID string or undef on failure
sub gen_uuid {
    my $uuid = qx(uuidgen 2>/dev/null);
    if ($? == 0 and defined $uuid) {
        chomp $uuid;
        return g_success($uuid, "UUID generated.");
    }
    carp "gen_uuid: uuidgen command failed, falling back to random string";
    my $pseudo_uuid	= gen_random_token(36); # Fallback: UUID-like random token
    return g_success($pseudo_uuid, "Random string substituted for UUID.");
}

## gen_token: deprecated alias for gen_random_token
sub gen_token {
    goto &gen_random_token;
}

## gen_random_token: generate random alphanumeric token
## Parameters: length (optional, default 13)
## Returns: random string of specified length
sub gen_random_token {
    my $length = shift || 13;
    $length = $length =~ /^\d+$/ ? $length : 13;

    my $token = random_string($length);
    return g_success($token, "Random token generated ($length chars).");
}

## gen_crypt_token: generate a crypt-based token
## Returns: 11-character token string
sub gen_crypt_token {
    my @chars = ('a'..'z', 'A'..'Z', '0'..'9');
    my $token = crypt(
        substr(gettimeofday(), -8),
         join('', => @chars[rand 62, rand 62])
    );
    $token =~ tr{./:-}{ZAjQ};
    return g_success($token, "Crypt token generated.");
}

## gen_random_string: generate random string from optional charset
## Parameters: length, charset (optional)
## If charset provided and not empty, uses random_string_from
## Otherwise uses alphanumeric charset
## Returns: random string of specified length
sub gen_random_string {
    my ($length, $charset) = @_;
    $length = (defined $length and $length =~ /^\d+$/) ? $length : 13;

    my $string = ($charset && $charset !~ /^\s*$/)
        ? random_string_from($charset, $length)
        : random_string($length);

    return g_success($string, "Random string generated ($length chars).");
}

## gen_word_phrase: generate multi-word passphrase from dictionary
## Parameters:
##   num_words: number of words (default 4)
##   min_chars: minimum word length (default 4)
##   max_chars: maximum word length (default 7)
##   word_sep: separator between words (default '')
## Returns: passphrase string or fallback random phrase
sub gen_word_phrase {
    my $num_words = shift || 4;
    my $min_chars = shift || 4;
    my $max_chars = shift || 7;
    my $word_sep  = shift || '';

    my $word_file = '/usr/share/dict/web2';
    my @wordlist;
    my $used_fallback = 0;

    if (open my $wfh, "<", $word_file) {
        FILE: while (<$wfh>) {
            my $line = $_;
            chomp $line;
            next unless length($line) > $min_chars - 1;
            next if length($line) > $max_chars;
            push @wordlist => $line;
        }
        close $wfh;
    }
    else {
        carp "gen_word_phrase: Cannot open word file ($word_file), using fallback";
        $used_fallback = 1;

        # Fallback: generate random "words"
        for (1..$num_words) {
            my $length = $min_chars + int(rand($max_chars - $min_chars + 1));
            my ($word, $msg) = gen_random_string($length);
#             push @wordlist => ucfirst lc $word;
            push @wordlist => lc $word;
        }
    }

    my $list_size = scalar @wordlist;
    if ($list_size == 0) {
        return g_error("No words available for phrase generation.");
    }

    my @rand;
    my %seen;

    WORD: while (scalar @rand < ($num_words + 1)) {
        my $num = int(rand($list_size));
        next WORD if $seen{$num}++;
        my $wd = $wordlist[$num];
        next WORD if $wd =~ /^[A-Z]/;
        push @rand => ucfirst $wd;
    }

    my @words;
    for (1..$num_words) {
        push @words => shift @rand;
    }

    my $phrase = join $word_sep => @words;

    my $msg = $used_fallback
        ? "Word phrase generated (fallback mode)."
        : "Word phrase generated from dictionary.";

    return g_success($phrase, $msg);
}

1;

__END__

=head1 NAME

Concierge::Auth::Generators - Value generation utilities for Concierge::Auth

=head1 SYNOPSIS

    use Concierge::Auth::Generators qw(gen_uuid gen_random_token);

    # Direct functional usage
    my $uuid = gen_uuid();                      # Scalar: direct value
    my ($uuid, $msg) = gen_uuid();              # List: value + message

    my $token = gen_random_token(32);           # 32-char token
    my $phrase = gen_word_phrase(4, 4, 7, '-'); # "Word1-Word2-Word3-Word4"

=head1 DESCRIPTION

Concierge::Auth::Generators provides utility functions for generating various
types of random values and tokens. These functions are plain subroutines
(not object methods) that can be used functionally or inherited by
Concierge::Auth.

All generator functions return:
- Scalar context: the generated value (or undef on failure)
- List context: (value, message) or (undef, error_message)

=head1 FUNCTIONS

=head2 gen_uuid()

Generates a UUID using the system's uuidgen command.
Falls back to random token generation if uuidgen unavailable.

    my $uuid = gen_uuid();  # e.g., "550e8400-e29b-41d4-a716-446655440000"

=head2 gen_random_token($length)

Generates a random alphanumeric token.
Default length is 13 characters.

    my $token = gen_random_token(32);  # 32-character alphanumeric string

=head2 gen_random_string($length, $charset)

Generates a random string from specified character set.
If charset is omitted or empty, uses alphanumeric characters.

    my $str = gen_random_string(16, 'abcdef0123456789');  # Hex string
    my $str = gen_random_string(20);  # Alphanumeric string

=head2 gen_word_phrase($num_words, $min_chars, $max_chars, $separator)

Generates a passphrase from dictionary words or falls back to random
"words" if dictionary unavailable.

Parameters:
- $num_words: Number of words (default: 4)
- $min_chars: Minimum word length (default: 4)
- $max_chars: Maximum word length (default: 7)
- $separator: Word separator (default: '')

    my $phrase = gen_word_phrase();           # "Word1Word2Word3Word4"
    my $phrase = gen_word_phrase(5, 4, 7, '-'); # "Word1-Word2-Word3-Word4-Word5"

=head2 gen_crypt_token()

Generates an 11-character token using crypt().

    my $token = gen_crypt_token();  # e.g., "ZAjQ3xY2zA9b"

=head2 gen_token()

Deprecated alias for gen_random_token().

=head1 ERROR HANDLING

Generator functions do not throw fatal errors. On failure:
- Scalar context returns undef
- List context returns (undef, error_message)

Functions will carp (warn) and fall back to alternative methods when
possible (e.g., gen_uuid falls back to random token if uuidgen unavailable).

=head1 SEE ALSO

L<Concierge::Auth>

=head1 AUTHOR

Bruce Van Allen <bva@cruzio.com>

=head1 LICENSE

Artistic License 2.0

=cut

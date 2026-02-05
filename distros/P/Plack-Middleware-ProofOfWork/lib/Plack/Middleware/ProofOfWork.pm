package Plack::Middleware::ProofOfWork;

use strict;
use warnings;
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(
    difficulty
    cookie_name
    cookie_duration
    bot_patterns
    bot_verification_level
    bot_dns_timeout
    timestamp_window
    js_file
    html_file
    css
    _js_content
    _html_content
);
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(decode_base64);
use Plack::Request;
use Plack::Response;
use File::ShareDir ();
use File::Spec;
use Socket qw(:addrinfo SOCK_RAW AF_INET AF_INET6 NI_NUMERICHOST inet_pton inet_ntop);
use Time::HiRes qw(alarm);

our $VERSION = '0.21';

sub prepare_app {
    my $self = shift;
    
    # Set default values
    $self->difficulty(4) unless defined $self->difficulty;
    $self->cookie_name('pow') unless defined $self->cookie_name;
    $self->cookie_duration(5) unless defined $self->cookie_duration; # Days
    $self->bot_verification_level(2) unless defined $self->bot_verification_level; # 0-3, default 2
    $self->bot_dns_timeout(0.5) unless defined $self->bot_dns_timeout; # Seconds
    $self->timestamp_window(86400 * $self->cookie_duration) unless defined $self->timestamp_window;
    
    # Default bot patterns with DNS verification patterns
    unless (defined $self->bot_patterns) {
        $self->bot_patterns({
            'googlebot' => qr/crawl.*google\.com$/,
            'applebot'  => qr/applebot.*apple\.com$/,
            'bingbot'   => qr/bingbot.*bing\.com$/,
        });
    }
    
    # Load JavaScript template at startup
    unless (defined $self->js_file) {
        $self->js_file($self->_find_share_file('pow.js'));
    }
    $self->_js_content($self->_load_template_file($self->js_file));
    
    # Load HTML template at startup
    unless (defined $self->html_file) {
        $self->html_file($self->_find_share_file('challenge.html'));
    }
    $self->_html_content($self->_load_template_file($self->html_file));
}

sub call {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);
    
    # Check if PoW is required
    if ($self->_needs_proof_of_work($req)) {
        return $self->_serve_challenge($req);
    }
    
    # PoW successful or not required - pass through
    return $self->app->($env);
}

sub _needs_proof_of_work {
    my ($self, $req) = @_;
    
    # Check PoW cookie FIRST (before bot check)
    my $pow_cookie = $req->cookies->{$self->cookie_name};
    
    # If valid cookie exists, validate it
    if (defined $pow_cookie) {
        # Valid PoW - allow through
        return 0 if $self->_verify_proof_of_work($req, $pow_cookie);
        # Invalid PoW - require new one (even for bots)
        return 1;
    }
    
    # No cookie - check if bot exception applies
    if ($self->_is_bot($req)) {
        return 0;  # Verified bot - allow through
    }
    
    # No valid cookie and not a bot - require PoW
    return 1;
}

sub _is_bot {
    my ($self, $req) = @_;
    
    my $verification_level = $self->bot_verification_level;
    return 0 if $verification_level == 0;
    
    my $user_agent = $req->user_agent || '';
    my $remote_addr = $req->address || $req->env->{REMOTE_ADDR} || '';
    
    # Find matching bot type
    my $bot_type;
    my $bot_patterns = $self->bot_patterns;
    
    foreach my $key (keys %$bot_patterns) {
        if ($user_agent =~ /\Q$key\E/i) {
            $bot_type = $key;
            last;
        }
    }
    
    return 0 unless $bot_type;
    return 1 if $verification_level == 1; # Only User-Agent check
    
    # Level 2+: DNS verification
    return 0 unless $remote_addr;
    
    my $hostname = $self->_get_hostname($remote_addr);
    return 0 unless $hostname;
    return 0 unless $hostname =~ $bot_patterns->{$bot_type};
    return 1 if $verification_level == 2; # Reverse DNS only
    
    # Level 3: Full DNS roundtrip verification
    return $self->_verify_dns_match($remote_addr, $hostname);
}

sub _normalize_ip {
    my ($self, $ip) = @_;
    my $family = $ip =~ /:/ ? AF_INET6 : AF_INET;
    my $packed = inet_pton($family, $ip) or return $ip;
    return inet_ntop($family, $packed);
}

sub _get_hostname {
    my ($self, $ip) = @_;
    
    my $hostname;
    my $timeout = $self->bot_dns_timeout;
    
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm($timeout);
        
        if ($ip =~ /:/) {
            my $packed = inet_pton(AF_INET6, $ip) or die "invalid ip\n";
            $hostname = gethostbyaddr($packed, AF_INET6);
        } else {
            my $packed = inet_pton(AF_INET, $ip) or die "invalid ip\n";
            $hostname = gethostbyaddr($packed, AF_INET);
        }
        
        alarm(0);
    };
    
    alarm(0);
    
    return undef if ($@ && $@ =~ /timeout/);
    return $hostname;
}

sub _verify_dns_match {
    my ($self, $ip, $hostname) = @_;
    
    my @resolved_ips;
    my $success = 0;
    my $timeout = $self->bot_dns_timeout * 2;
    
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm($timeout);
        
        my ($err, @res) = getaddrinfo($hostname, "", {socktype => SOCK_RAW});
        
        if (!$err) {
            @resolved_ips = map {
                my ($err_ni, $resolved_ip) = getnameinfo($_->{addr}, NI_NUMERICHOST);
                $err_ni ? () : $resolved_ip;
            } @res;
            
            $success = 1;
        }
        
        alarm(0);
    };
    
    alarm(0);
    
    return 0 if ($@ && $@ =~ /timeout/);
    return 0 unless $success;
    
    my $normalized_ip = $self->_normalize_ip($ip);
    my $found_match = grep { $self->_normalize_ip($_) eq $normalized_ip } @resolved_ips;
    
    return $found_match;
}

sub _verify_proof_of_work {
    my ($self, $req, $pow_cookie) = @_;
    
    # Decode cookie (can fail)
    my $nonce;
    eval {
        $nonce = decode_base64($pow_cookie);
    };
    return 0 if $@; # Decode failed
    
    # Generate source value
    my $source = $self->_get_source_value($req);
    
    # Calculate hash
    my $input = "$source:$nonce";
    my $hash = sha256_hex($input);
    
    # Check leading zeros with fractional difficulty
    my $difficulty = $self->difficulty;
    my $full = int($difficulty);
    my $fraction = $difficulty - $full;
    
    # Check integer part
    my $required_zeros = '0' x $full;
    return 0 unless $hash =~ /^$required_zeros/;
    
    # Check fractional part (if present)
    if ($fraction > 0) {
        my $next_char = substr($hash, $full, 1);
        my $hex_value = hex($next_char);
        my $div = 16 - (16 * $fraction);
        return 0 unless $hex_value < $div;
    }
    
    # Valid proof-of-work
    return 1;
}

sub _get_source_value {
    my ($self, $req) = @_;
    
    my $user_agent = $req->user_agent || 'Unknown';
    my $accept_language = $req->header('Accept-Language') || 'Empty';
    my $host = $req->header('Host') || 'Unknown';
    
    # Round timestamp to cookie duration
    my $now = time();
    my $timestamp = $now - ($now % $self->timestamp_window);
    
    return "$user_agent|$timestamp|$accept_language|$host";
}

sub _find_share_file {
    my ($self, $filename) = @_;
    
    # Try installed share files (primary method)
    my $dist_file;
    eval {
        $dist_file = File::ShareDir::dist_file('Plack-Middleware-ProofOfWork', $filename);
    };
    
    # Check if we got a valid file from File::ShareDir
    if (!$@ && defined $dist_file && -f $dist_file && -r $dist_file) {
        return $dist_file;
    }
    
    # Development paths (for local development)
    my @dev_paths = (
        "share/$filename",
        "./share/$filename",
    );
    
    for my $path (@dev_paths) {
        return $path if -f $path && -r $path;
    }
    
    # File not found
    die "Template file '$filename' not found. Please ensure Plack::Middleware::ProofOfWork is properly installed.";
}

sub _load_template_file {
    my ($self, $filepath) = @_;
    
    # Check if file exists
    unless (-f $filepath && -r $filepath) {
        die "Template file '$filepath' not found or not readable.";
    }
    
    # Load template file
    open my $fh, '<:encoding(UTF-8)', $filepath
        or die "Cannot open template file '$filepath': $!";
    
    my $content = do { local $/; <$fh> };
    close $fh;
    
    return $content;
}

sub _serve_challenge {
    my ($self, $req) = @_;
    
    my $source_value = $self->_get_source_value($req);
    my $html = $self->_generate_challenge_html($source_value);
    
    my $res = Plack::Response->new(200);
    $res->content_type('text/html; charset=utf-8');
    $res->header('X-Proof-of-Work' => 'required');
    $res->body($html);
    
    return $res->finalize;
}

sub _generate_challenge_html {
    my ($self, $source_value) = @_;
    
    my $difficulty = $self->difficulty;
    my $cookie_name = $self->cookie_name;
    my $cookie_duration = $self->cookie_duration;
    
    # Escape for JavaScript
    $source_value =~ s/\\/\\\\/g;
    $source_value =~ s/"/\\"/g;
    
    # Use preloaded JavaScript content
    my $js_content = $self->_js_content;
    
    # API prefix: Constants and getSourceValue() function
    my $js_api_prefix = <<"JSAPI";
// ============================================================================
// Plack::Middleware::ProofOfWork API
// ============================================================================
// These constants and functions are provided by the middleware
// and must be used by the pow.js script.

// Constants
const DIFFICULTY = $difficulty;
const POW_COOKIE_NAME = '$cookie_name';
const COOKIE_DURATION = $cookie_duration;

// API function: Returns the source value for PoW calculation
function getSourceValue() {
  return "$source_value";
}

// ============================================================================
// End of API - pow.js script begins here
// ============================================================================
$js_content
JSAPI

    # Use preloaded HTML template
    my $html_template = $self->_html_content;
    
    # Replace JavaScript placeholder
    $html_template =~ s/<!--\s*POW_JAVASCRIPT\s*-->/$js_api_prefix/;
    
    # Replace CSS placeholder if custom CSS provided
    if (my $custom_css = $self->css) {
        $html_template =~ s/<!--\s*POW_CSS\s*-->/$custom_css/;
    }
    
    return $html_template;
}

1;

__END__

=encoding utf-8

=head1 NAME

Plack::Middleware::ProofOfWork - Proof-of-Work based bot protection for Plack applications

=head1 SYNOPSIS

  use Plack::Builder;
  
  builder {
      enable "ProofOfWork",
          difficulty => 4,
          cookie_name => 'pow',
          cookie_duration => 5;
      $app;
  };

=head1 DESCRIPTION

Plack::Middleware::ProofOfWork implements a Proof-of-Work mechanism to protect
against automated requests (bots, scrapers, etc.). Legitimate browsers must solve
a computationally intensive task before accessing the application.

The middleware uses SHA-256 hashing and requires clients to find a nonce that
results in a hash with a specified number of leading zeros.

=head1 CONFIGURATION

=over 4

=item difficulty

The number of leading zeros in the hash (default: 4).
Now supports fractional values for finer granularity (e.g. 4.5).
Each additional zero increases difficulty by a factor of 16.

  difficulty => 4    # ~65,000 attempts on average
  difficulty => 4.5  # ~185,000 attempts on average
  difficulty => 5    # ~1,000,000 attempts on average

Fractional difficulty enables finer gradations between the exponential
steps of integer difficulties.

=item cookie_name

Name of the cookie for the Proof-of-Work token (default: 'pow').

=item cookie_duration

Cookie validity duration in days (default: 5).

=item bot_patterns

Hash-ref of bot types with DNS verification patterns (default: Googlebot, Applebot, Bingbot).

  bot_patterns => {
      'googlebot' => qr/crawl.*google\.com$/,
      'mybot'     => qr/mybot.*example\.com$/,
  }

The hash keys are used for User-Agent matching (case-insensitive).
The regex values are used for reverse DNS hostname verification.

=item bot_verification_level

Level of bot verification (default: 2):

  0 = No bots allowed (all bots blocked, regardless of verification)
  1 = User-Agent only (simple string matching)
  2 = Reverse DNS (hostname must match pattern) - DEFAULT
  3 = Full DNS roundtrip (reverse + forward DNS must match)

  bot_verification_level => 3

Set to 0 to block all bots (including search engines).
Level 2 (default) provides good security with reasonable performance.
Level 3 provides the most security but may slow down first requests
from bots due to additional DNS lookups.

=item bot_dns_timeout

Timeout in seconds for DNS lookups during bot verification (default: 0.5).

  bot_dns_timeout => 1.0

Forward DNS lookup uses 2x this timeout.

=item timestamp_window

Time window in seconds for timestamp rounding (default: cookie_duration * 86400).

=item js_file

Path to the JavaScript file for Proof-of-Work calculation.
If not specified, the bundled default file is used.

  js_file => '/path/to/my/pow.js'

The JavaScript file is automatically loaded from the installation
(via File::ShareDir). In v0.05 there is no inline fallback -
the file must exist.

=item html_file

Path to the HTML template file for the challenge page.
If not specified, the bundled default file is used.

  html_file => '/path/to/my/challenge.html'

The HTML template must contain the placeholder C<E<lt>!-- POW_JAVASCRIPT --E<gt>>
where the JavaScript API and pow.js content will be inserted.

This allows complete customization of the challenge page UI.

=item css

Custom CSS to inject into the challenge page template.
The CSS is inserted at the C<E<lt>!-- POW_CSS --E<gt>> placeholder
in the HTML template's style section.

  css => '.spinner { border-color: red; }'

This allows easy styling customization without replacing the entire HTML template.

=back

=head1 LOGIC FLOW

The middleware checks Proof-of-Work in the following order:

=over 4

=item 1.

Check if a PoW cookie exists

=item 2.

If cookie exists: Validate it
  - Valid → Allow request through
  - Invalid → Require new PoW (even for bots)

=item 3.

If no cookie: Check if request is from a known bot
  - Is bot and allow_bots=1 → Allow through
  - Not a bot or allow_bots=0 → Require PoW

=back

This ensures that even bots with invalid cookies must solve the PoW again.

=head1 JAVASCRIPT API

The pow.js script receives the following constants and functions from the middleware:

=head2 Provided Constants

  const DIFFICULTY        // Number: difficulty (e.g. 4 or 4.5)
  const POW_COOKIE_NAME   // String: cookie name
  const COOKIE_DURATION   // Number: cookie validity in days

=head2 Provided Functions

  function getSourceValue()  // Returns: String with the source value
                             // Format: "UserAgent|Timestamp|Language|Host"

This API is inserted as a prefix before the actual pow.js script.

=head2 Required Functions in pow.js

The pow.js script MUST implement the following functions:

  async function sha256(message)              // SHA-256 hash calculation
  function hasLeadingZeros(hash, full, div)   // Validation with fractional difficulty
  function setCookie(name, value, days)       // Set cookie
  async function computeProofOfWork()         // Main PoW function

See C<share/pow.js> for the reference implementation.

=head1 HOW IT WORKS

=over 4

=item 1.

A client without a valid PoW cookie receives an HTML page with JavaScript.

=item 2.

The JavaScript calculates a Proof-of-Work based on User-Agent, language, host, and timestamp.

=item 3.

After successful calculation, a cookie is set and the page reloads.

=item 4.

The middleware validates the cookie and passes the request through.

=back

=head1 SECURITY CONSIDERATIONS

=over 4

=item *

Difficulty should be high enough to slow down automated requests, but low enough
not to frustrate legitimate users.

=item *

The middleware uses User-Agent, Accept-Language, and Host as part of the challenge
to prevent token reuse across different contexts.

=item *

Timestamps are rounded to the cookie window to ensure stable challenges.

=back

=head1 AUTHOR

Your Name E<lt>your@email.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Plack::Middleware>, L<Digest::SHA>, L<File::ShareDir>

=cut

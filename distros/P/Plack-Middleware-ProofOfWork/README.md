# NAME

Plack::Middleware::ProofOfWork - Proof-of-Work based bot protection for Plack applications

# SYNOPSIS

```perl
use Plack::Builder;

builder {
    enable "ProofOfWork",
        difficulty => 4,
        cookie_name => 'pow',
        cookie_duration => 5;
    $app;
};
```

# DESCRIPTION

Plack::Middleware::ProofOfWork implements a Proof-of-Work mechanism to protect
against automated requests (bots, scrapers, etc.). Legitimate browsers must solve
a computationally intensive task before accessing the application.

The middleware uses SHA-256 hashing and requires clients to find a nonce that
results in a hash with a specified number of leading zeros.

## Features

- **Bot Protection**: Effective protection against automated requests and scraping
- **Search Engine Friendly**: Allows known search engine bots by default
- **Browser-Based**: Uses Web Crypto API for SHA-256 calculation in the browser
- **Configurable**: Adjustable difficulty and cookie settings
- **User-Friendly**: Modern UI with progress updates during calculation
- **Fractional Difficulty**: Fine-grained control with fractional values (e.g. 4.5)
- **Customizable UI**: External HTML template for complete control over challenge page
- **Secure Logic**: Validates PoW before bot check to prevent bypass attempts

# CONFIGURATION

## difficulty

The number of leading zeros in the hash (default: 4).
Supports fractional values for finer granularity.
Each additional zero increases difficulty by a factor of 16.

```perl
difficulty => 4    # ~65,000 attempts on average (~1-2 seconds)
difficulty => 4.5  # ~185,000 attempts (~3-5 seconds)
difficulty => 5    # ~1,000,000 attempts on average (~15-30 seconds)
```

Fractional difficulty enables finer gradations between the exponential
steps of integer difficulties.

## cookie_name

Name of the cookie for the Proof-of-Work token (default: 'pow').

## cookie_duration

Cookie validity duration in days (default: 5).

## bot_patterns

Hash-ref of bot types with DNS verification patterns.

```perl
bot_patterns => {
    'googlebot' => qr/crawl.*google\.com$/,
    'mybot'     => qr/mybot.*example\.com$/,
}
```

Default includes:
- `googlebot` → `crawl.*google.com$`
- `applebot` → `applebot.*apple.com$`
- `bingbot` → `bingbot.*bing.com$`

The hash keys are used for case-insensitive User-Agent matching.
The regex values verify the reverse DNS hostname.

## bot_verification_level

Level of bot verification (default: 2):

- **0**: Block all bots (no bots allowed, including search engines)
- **1**: User-Agent only - simple string matching (fast but spoofable)
- **2**: Reverse DNS - hostname must match pattern (good balance) - **DEFAULT**
- **3**: Full DNS roundtrip - reverse + forward DNS must match (most secure)

```perl
bot_verification_level => 0  # Block all bots
bot_verification_level => 3  # Maximum security
```

**Level 0** blocks all bots completely (useful for private/internal sites).
**Level 2 (default)** provides good security with reasonable performance.
**Level 3** provides the strongest security against bot spoofing
but adds forward DNS lookup latency.

## bot_dns_timeout

Timeout in seconds for DNS lookups (default: 0.5).

```perl
bot_dns_timeout => 1.0  # Slower networks
```

Forward DNS lookup uses 2x this timeout.
Increase for slower networks, decrease for faster response.

## timestamp_window

Time window in seconds for timestamp rounding (default: cookie_duration * 86400).

## js_file

Path to the JavaScript file for Proof-of-Work calculation.

```perl
js_file => '/path/to/my/pow.js'
```

If not specified, the bundled default file (`share/pow.js`) is used.
The file is loaded automatically from the installation via File::ShareDir.

This allows customization of the JavaScript for:
- Custom styling/branding
- Additional logging functionality
- Integration with monitoring tools
- Custom progress indicators

## html_file

Path to the HTML template file for the challenge page.

```perl
html_file => '/path/to/my/challenge.html'
```

If not specified, the bundled default file (`share/challenge.html`) is used.

The HTML template must contain the placeholder `<!-- POW_JAVASCRIPT -->`
where the JavaScript API and pow.js content will be inserted.

This allows complete customization of:
- Page layout and design
- Branding and styling
- UI elements
- Status messages

## css

Custom CSS to inject into the challenge page template.

```perl
css => '.spinner { border-color: #ff0000; }'
```

The CSS is inserted at the `<!-- POW_CSS -->` placeholder in the 
HTML template's style section. This allows easy styling customization 
without replacing the entire HTML template.

Example with branding colors:

```perl
enable "ProofOfWork",
    css => q{
        body {
            background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%);
        }
        .spinner {
            border-top-color: #60a5fa;
        }
    };
```

# LOGIC FLOW

The middleware checks Proof-of-Work in the following order:

1. **Check if PoW cookie exists**
2. **If cookie exists**: Validate it
   - Valid → Allow request through
   - Invalid → Require new PoW (even for bots)
3. **If no cookie**: Check if request is from a verified bot
   - Is verified bot (level 1-3) → Allow through
   - Not a bot or level 0 → Require PoW

This ensures that even bots with invalid cookies must solve the PoW again.

# BOT VERIFICATION

Version 0.13+ includes reliable bot verification using DNS checks to prevent
User-Agent spoofing.

## Verification Levels

### Level 0: Block All Bots
```perl
enable "ProofOfWork",
    bot_verification_level => 0;  # All bots blocked (including search engines)
```

Blocks all bots completely. Useful for private or internal sites.

### Level 1: User-Agent Only (Default pre-0.13)
```perl
enable "ProofOfWork",
    bot_verification_level => 1;  # Fast but spoofable
```

Checks if User-Agent contains bot name. Easy to spoof.

### Level 2: Reverse DNS (Default)
```perl
enable "ProofOfWork",
    bot_verification_level => 2;  # Good balance (default)
```

1. Check User-Agent contains bot name
2. Reverse DNS lookup: IP → hostname
3. Verify hostname matches pattern (e.g., `*.google.com`)

Prevents simple spoofing. Good balance of security and performance.

### Level 3: Full DNS Roundtrip
```perl
enable "ProofOfWork",
    bot_verification_level => 3;  # Most secure
```

1. Check User-Agent contains bot name
2. Reverse DNS: IP → hostname
3. Verify hostname matches pattern
4. Forward DNS: hostname → IP addresses
5. Verify original IP is in resolved addresses

**Most secure** - prevents both User-Agent spoofing and DNS cache poisoning.

## Custom Bot Patterns

```perl
enable "ProofOfWork",
    bot_patterns => {
        'googlebot' => qr/crawl.*google\.com$/,
        'mybot'     => qr/mybot.*mycompany\.com$/,
    },
    bot_verification_level => 3;
```

Pattern must match the reverse DNS hostname.

# HOW IT WORKS

1. **Initial Request**: A client without a valid PoW cookie receives an HTML page with JavaScript.

2. **Challenge**: The JavaScript calculates a Proof-of-Work based on:
   - User-Agent
   - Accept-Language header
   - Host
   - Current timestamp (rounded to cookie window)

3. **Solution**: The client finds a nonce that, together with the above values, produces a hash with the desired number of leading zeros.

4. **Cookie**: After successful calculation, a cookie is set and the page reloads.

5. **Access**: The middleware validates the cookie and passes subsequent requests through.

# EXAMPLES

## Simple Usage

```perl
use Plack::Builder;

my $app = sub {
    return [200, ['Content-Type' => 'text/plain'], ['Hello World']];
};

builder {
    enable "ProofOfWork";
    $app;
};
```

## With Custom Configuration

```perl
builder {
    enable "ProofOfWork",
        difficulty => 5,              # Higher difficulty
        cookie_name => 'bot_check',
        cookie_duration => 7,         # One week
        bot_verification_level => 2,  # Reverse DNS (default)
        bot_patterns => {             # Custom bot list
            'googlebot'   => qr/crawl.*google\.com$/,
            'mylegitbot'  => qr/mybot.*example\.com$/,
        };
    $app;
};
```

## With Custom JavaScript File

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        js_file => '/var/www/myapp/custom-pow.js';  # Custom JS file
    $app;
};
```

The JavaScript file must provide:
- `sha256(message)` - SHA-256 hash calculation
- `computeProofOfWork()` - Main PoW function
- `setCookie(name, value, days)` - Cookie setter

And use these constants:
- `DIFFICULTY` - Difficulty (set by Perl)
- `POW_COOKIE_NAME` - Cookie name (set by Perl)
- `COOKIE_DURATION` - Cookie duration (set by Perl)
- `getSourceValue()` - Function providing source value (set by Perl)

## With Custom HTML Template

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        html_file => '/var/www/myapp/challenge.html';  # Custom HTML
    $app;
};
```

The HTML template must include the placeholder:
```html
<!-- POW_JAVASCRIPT -->
```

This will be replaced with the JavaScript API and pow.js content.

Example custom template:
```html
<!DOCTYPE html>
<html>
<head>
  <title>Please Wait...</title>
  <style>/* Your custom styles */</style>
</head>
<body>
  <div class="your-custom-ui">
    <img src="/logo.png" alt="Logo">
    <h1>Verifying your browser...</h1>
    <div id="status"></div>
  </div>
  <script>
  <!-- POW_JAVASCRIPT -->
  </script>
</body>
</html>
```

## With Custom CSS

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        css => q{
            body {
                background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%);
            }
            .spinner {
                border-color: rgba(255, 255, 255, 0.2);
                border-top-color: #60a5fa;
            }
            h1 {
                color: #dbeafe;
            }
        };
    $app;
};
```

The custom CSS is injected at the `<!-- POW_CSS -->` placeholder in the template.

## Only Protect Specific Paths

```perl
builder {
    mount "/api" => builder {
        enable "ProofOfWork", difficulty => 5;
        $api_app;
    };
    mount "/" => $public_app;
};
```

## Combine With Other Middleware

```perl
builder {
    enable "AccessLog", format => "combined";
    enable "ProofOfWork", difficulty => 4;
    enable "Session", store => "File";
    $app;
};
```

# CHOOSING DIFFICULTY

The right difficulty depends on your requirements:

| Difficulty | Attempts (Avg) | Time (Avg)  | Use Case                        |
|------------|----------------|-------------|---------------------------------|
| 2          | ~256           | <0.1s       | Testing only                    |
| 3          | ~4,000         | ~0.2s       | Very light protection           |
| 4          | ~65,000        | ~1-2s       | **Recommended for most cases**  |
| 4.5        | ~185,000       | ~3-5s       | Stronger protection, acceptable |
| 5          | ~1,000,000     | ~15-30s     | High protection, may frustrate  |
| 5.5        | ~2,800,000     | ~45-90s     | Very high protection            |
| 6          | ~16,000,000    | ~4-8 min    | Extreme protection, special cases only |

**Recommendation**: Start with difficulty 4 and adjust as needed.

# SECURITY CONSIDERATIONS

- **Difficulty**: Should be high enough to slow down automated requests, but low enough not to frustrate legitimate users. Difficulty 4-5 is appropriate for most applications.

- **Token Reuse**: The middleware uses User-Agent, Accept-Language, and Host as part of the challenge to prevent token reuse across different contexts.

- **Timestamp Rounding**: Timestamps are rounded to the cookie window to ensure stable challenges and cache-friendliness.

- **Not a Silver Bullet**: Proof-of-Work is not a perfect solution against all bots. Motivated attackers can solve the challenge, but it significantly increases costs.

# PERFORMANCE

Server-side performance impact is minimal:

- **Without valid cookie**: One SHA-256 hash calculation for validation
- **With valid cookie**: One SHA-256 hash calculation for validation
- **Computational effort**: Completely on the client (browser)

Typical client-side calculation times:

| Difficulty | Average Time | Attempts           |
|------------|--------------|---------------------|
| 3          | ~0.1s        | ~4,000              |
| 4          | ~1-2s        | ~65,000             |
| 4.5        | ~3-5s        | ~185,000            |
| 5          | ~15-30s      | ~1,000,000          |
| 5.5        | ~45-90s      | ~2,800,000          |
| 6          | ~4-8 min     | ~16,000,000         |

# DEPENDENCIES

- Plack >= 1.0000
- Digest::SHA
- MIME::Base64
- File::ShareDir
- Modern browser with Web Crypto API support

# SEE ALSO

- [Plack::Middleware](https://metacpan.org/pod/Plack::Middleware)
- [Digest::SHA](https://metacpan.org/pod/Digest::SHA)
- [File::ShareDir](https://metacpan.org/pod/File::ShareDir)
- [Proof-of-Work Concept](https://en.wikipedia.org/wiki/Proof_of_work)

# AUTHOR

Oliver Paukstadt <cpan at sourcentral dot org>

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# COPYRIGHT

Copyright (C) 2026 Oliver Paukstadt

# Plack::Middleware::ProofOfWork - Quick Start

## Installation

```bash
# From local directory
cd Plack-Middleware-ProofOfWork
perl Makefile.PL
make
make test
make install
```

## Minimal Usage

```perl
# app.psgi
use Plack::Builder;

builder {
    enable "ProofOfWork";
    $app;
};
```

Start:
```bash
plackup app.psgi
```

## Recommended Configuration

```perl
use Plack::Builder;

builder {
    enable "ProofOfWork",
        difficulty => 4,        # 1-2 seconds calculation
        cookie_name => 'pow',   # Cookie name
        cookie_duration => 5,   # 5 days valid
        allow_bots => 1;        # Allow search engines
    $app;
};
```

## Important Parameters

| Parameter | Default | Description | Recommendation |
|-----------|---------|-------------|----------------|
| difficulty | 4 | Leading zeros (3-6, also 4.5 etc.) | 4 for web, 3 for mobile, 4.5 for more protection |
| cookie_name | 'pow' | Cookie name | Default OK |
| cookie_duration | 5 | Days | 5-7 days |
| allow_bots | 1 | Search engines | 1 (enabled) |
| js_file | auto | Path to JS file | Default OK, custom for logic changes |
| html_file | auto | Path to HTML template | Default OK, custom for UI branding |
| css | none | Custom CSS string | Easy styling without full template |

## Difficulty Table

| Difficulty | Time (Avg) | Attempts | Application |
|------------|------------|----------|-------------|
| 3 | ~0.2s | 4,000 | Mobile, Fast |
| **4** | **~1-2s** | **65,000** | **Standard recommendation** |
| 4.5 | ~3-5s | 185,000 | Stronger protection |
| 5 | ~15-30s | 1,000,000 | High protection |
| 5.5 | ~45-90s | 2,800,000 | Very high protection |
| 6 | ~4-8min | 16,000,000 | Very high protection |

Fractional difficulties (e.g. 4.5) for finer gradations since v0.04!  
New in v0.05: PoW validation happens before bot check for better security!

## Examples

### Only protect API

```perl
builder {
    mount "/api" => builder {
        enable "ProofOfWork", difficulty => 5;
        $api_app;
    };
    mount "/" => $public_app;
};
```

### With custom JavaScript file

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        js_file => '/var/www/myapp/custom-pow.js';  # Custom JS file
    $app;
};
```

See `CUSTOM_JAVASCRIPT.md` for details on creating custom JS files.

### With custom HTML template

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        html_file => '/var/www/myapp/challenge.html';  # Custom UI
    $app;
};
```

The HTML must include `<!-- POW_JAVASCRIPT -->` placeholder.
See `share/challenge.html` for template structure.

### With custom CSS

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        css => q{
            body { background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); }
            .spinner { border-top-color: #60a5fa; }
        };
    $app;
};
```

Easy branding without replacing entire template!

### With other middleware

```perl
builder {
    enable "AccessLog";
    enable "ProofOfWork", difficulty => 4;
    enable "Session";
    $app;
};
```

### Block bots

```perl
builder {
    enable "ProofOfWork",
        difficulty => 4,
        allow_bots => 0;  # Also blocks search engines!
    $app;
};
```

## Testing

```bash
# All tests
prove -lv t/

# Example app
plackup example.psgi

# With curl (shows challenge)
curl -v http://localhost:5000/

# With bot UA (allowed)
curl -A "Googlebot" http://localhost:5000/
```

## Troubleshooting

### "Proof of Work" page always shown

**Possible causes:**

1. **Cookies disabled**: Ensure cookies are enabled
2. **JavaScript disabled**: JavaScript must be enabled
3. **Browser compatibility**: Web Crypto API required (modern browsers)
4. **Timestamp issue**: Check system time (should be correct)

**Debug:**

```perl
# Enable logging
enable "ProofOfWork",
    difficulty => 4;

# Start server with verbose logging
plackup -E development app.psgi
```

### PoW calculation takes too long

**Solution:**

```perl
# Reduce difficulty
enable "ProofOfWork",
    difficulty => 3;  # Instead of 4 or 5
```

### Bots not recognized

**Check User-Agent pattern:**

```perl
enable "ProofOfWork",
    allow_bots => 1,
    bot_patterns => [
        qr/Googlebot/i,
        qr/Bingbot/i,
        # Add more
    ];
```

## Security Notes

1. **Not 100% protection**: PoW slows down bots but doesn't stop them completely
2. **Resource-intensive**: High difficulty can affect older devices
3. **Mobile devices**: Consider slower mobile CPUs when setting difficulty
4. **Combine with other methods**: Rate-limiting, WAF, CAPTCHAs for critical areas

## Best Practices

1. **Combine with rate limiting**:
   ```perl
   enable "Throttle::Lite",
       limits => '100 req/hour';
   enable "ProofOfWork";
   ```

2. **Monitoring**: Monitor PoW challenge rate
3. **A/B Testing**: Test different difficulties
4. **Cookie duration**: Not too short (annoys users), not too long (security)
5. **Feedback**: Show progress during calculation

## See Also

- **README.md** - Full documentation
- **JAVASCRIPT_API.md** - JavaScript API reference
- **CUSTOM_JAVASCRIPT.md** - Custom JavaScript guide

---

**Version:** 0.22  
**New in 0.22:** Extended bot list with 14 different bots  
**Author:** Oliver Paukstadt  
**License:** Perl (Artistic/GPL)

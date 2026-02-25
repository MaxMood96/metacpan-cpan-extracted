# Net::IPData

Perl client for the [ipdata.co](https://ipdata.co/) IP geolocation and threat intelligence API.

## Features

- **Full API coverage** -- single IP lookup, bulk lookup (up to 100 IPs), field filtering, single-field queries
- **Threat intelligence** -- TOR, proxy, datacenter, VPN, and botnet detection
- **Rich data** -- geolocation, ASN, company, carrier, currency, timezone, and language info
- **EU endpoint** -- route requests through EU-only servers for GDPR compliance
- **Zero non-core dependencies** -- uses only `HTTP::Tiny` and `JSON::PP` (core since Perl 5.14)
- **Production ready** -- input validation, structured error handling, configurable timeouts

## Installation

From CPAN:

```sh
cpanm Net::IPData
```

Or manually:

```sh
perl Makefile.PL
make
make test
make install
```

## Quick Start

```perl
use Net::IPData;

my $ipdata = Net::IPData->new(api_key => 'YOUR_API_KEY');

my $result = $ipdata->lookup('8.8.8.8');
printf "%s is in %s, %s\n",
    $result->{ip},
    $result->{city},
    $result->{country_name};
```

Get a free API key (1,500 requests/day) at [ipdata.co](https://ipdata.co/).

## Usage

### Single IP Lookup

```perl
my $result = $ipdata->lookup('8.8.8.8');

printf "IP:        %s\n", $result->{ip};
printf "City:      %s\n", $result->{city};
printf "Region:    %s\n", $result->{region};
printf "Country:   %s (%s)\n", $result->{country_name}, $result->{country_code};
printf "Continent: %s\n", $result->{continent_name};
printf "Coords:    %.4f, %.4f\n", $result->{latitude}, $result->{longitude};
printf "ASN:       %s (%s)\n", $result->{asn}{asn}, $result->{asn}{name};
printf "Timezone:  %s\n", $result->{time_zone}{name};
printf "Currency:  %s (%s)\n", $result->{currency}{name}, $result->{currency}{code};
printf "EU:        %s\n", $result->{is_eu} ? 'Yes' : 'No';
printf "Threat:    %s\n", $result->{threat}{is_threat} ? 'Yes' : 'No';
```

### Look Up Your Own IP

```perl
my $me = $ipdata->lookup_mine();
printf "My IP: %s\n", $me->{ip};
```

### Field Filtering

Request only the fields you need to reduce response size and improve performance:

```perl
my $partial = $ipdata->lookup('8.8.8.8', fields => [qw(ip country_name asn)]);
printf "Country: %s, ASN: %s\n",
    $partial->{country_name},
    $partial->{asn}{name};
```

Fields can also be passed as a comma-separated string:

```perl
my $partial = $ipdata->lookup('8.8.8.8', fields => 'ip,country_name,asn');
```

### Bulk Lookup

Look up to 100 IP addresses in a single request:

```perl
my $results = $ipdata->bulk(['8.8.8.8', '1.1.1.1', '9.9.9.9']);

for my $r (@$results) {
    printf "%s -> %s, %s\n", $r->{ip}, $r->{city}, $r->{country_name};
}

# With field filtering
my $results = $ipdata->bulk(
    ['8.8.8.8', '1.1.1.1'],
    fields => [qw(ip country_name threat)],
);
```

### Single-Field Shortcuts

Retrieve individual fields directly without downloading the full response:

```perl
my $asn     = $ipdata->asn('8.8.8.8');          # hashref
my $threat  = $ipdata->threat('8.8.8.8');        # hashref
my $carrier = $ipdata->carrier('8.8.8.8');       # hashref
my $tz      = $ipdata->time_zone('8.8.8.8');     # hashref
my $curr    = $ipdata->currency('8.8.8.8');      # hashref
my $langs   = $ipdata->languages('8.8.8.8');     # arrayref

my $country = $ipdata->country_name('8.8.8.8');  # string
my $code    = $ipdata->country_code('8.8.8.8');  # string
my $eu      = $ipdata->is_eu('8.8.8.8');         # boolean

# Or use the generic method for any path-accessible field
my $city = $ipdata->lookup_field('8.8.8.8', 'city');
```

### EU Endpoint

Route all requests through EU-only servers (Paris, Ireland, Frankfurt) for GDPR compliance:

```perl
my $ipdata = Net::IPData->new(
    api_key => 'YOUR_API_KEY',
    eu      => 1,
);
```

### Custom Base URL

```perl
my $ipdata = Net::IPData->new(
    api_key  => 'YOUR_API_KEY',
    base_url => 'https://custom-proxy.example.com',
);
```

### Error Handling

All methods `croak` on errors. Use `eval` or [Try::Tiny](https://metacpan.org/pod/Try::Tiny) to catch them:

```perl
use Try::Tiny;

try {
    my $result = $ipdata->lookup('invalid');
} catch {
    warn "API error: $_";
};
```

Error messages include the HTTP status code and the API's error message:

| Status | Meaning |
|--------|---------|
| 401 | Invalid or missing API key |
| 403 | Access forbidden |
| 429 | Rate limit exceeded |
| 599 | Network/connection failure |

## Constructor Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `api_key` | string | *required* | Your ipdata.co API key |
| `eu` | bool | `0` | Use the EU endpoint (`eu-api.ipdata.co`) |
| `base_url` | string | `https://api.ipdata.co` | Custom base URL (overrides `eu`) |
| `timeout` | int | `30` | HTTP timeout in seconds |

## Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `lookup($ip, %opts)` | hashref | Full lookup for an IP (omit `$ip` for caller's IP) |
| `lookup_mine(%opts)` | hashref | Full lookup for the caller's own IP |
| `lookup_field($ip, $field)` | varies | Single field via path API |
| `bulk(\@ips, %opts)` | arrayref | Bulk lookup for up to 100 IPs |
| `asn($ip)` | hashref | ASN data (`asn`, `name`, `domain`, `route`, `type`) |
| `threat($ip)` | hashref | Threat flags (`is_tor`, `is_proxy`, `is_threat`, ...) |
| `carrier($ip)` | hashref | Mobile carrier (`name`, `mcc`, `mnc`) |
| `currency($ip)` | hashref | Currency (`name`, `code`, `symbol`, `native`, `plural`) |
| `time_zone($ip)` | hashref | Timezone (`name`, `abbr`, `offset`, `is_dst`, `current_time`) |
| `languages($ip)` | arrayref | Languages (`name`, `native`, `code`) |
| `country_name($ip)` | string | Country name |
| `country_code($ip)` | string | ISO 3166-1 alpha-2 country code |
| `is_eu($ip)` | boolean | EU member state |

## API Response Structure

A full lookup returns a hashref with this shape:

```
{
    ip             => "8.8.8.8",
    is_eu          => false,
    city           => "Mountain View",
    region         => "California",
    region_code    => "CA",
    country_name   => "United States",
    country_code   => "US",
    continent_name => "North America",
    continent_code => "NA",
    latitude       => 37.386,
    longitude      => -122.0838,
    postal         => "94035",
    calling_code   => "1",
    flag           => "https://ipdata.co/flags/us.png",
    emoji_flag     => "\x{1f1fa}\x{1f1f8}",
    emoji_unicode  => "U+1F1FA U+1F1F8",

    asn       => { asn, name, domain, route, type },
    company   => { name, domain, network, type },
    carrier   => { name, mcc, mnc },
    languages => [{ name, native, code }],
    currency  => { name, code, symbol, native, plural },
    time_zone => { name, abbr, offset, is_dst, current_time },
    threat    => { is_tor, is_icloud_relay, is_proxy, is_datacenter,
                   is_anonymous, is_known_attacker, is_known_abuser,
                   is_threat, is_bogon },
}
```

## Requirements

- Perl 5.10.1 or later
- Core modules only: [HTTP::Tiny](https://metacpan.org/pod/HTTP::Tiny), [JSON::PP](https://metacpan.org/pod/JSON::PP), [Carp](https://metacpan.org/pod/Carp), [Scalar::Util](https://metacpan.org/pod/Scalar::Util)
- Recommended: [IO::Socket::SSL](https://metacpan.org/pod/IO::Socket::SSL) and [Net::SSLeay](https://metacpan.org/pod/Net::SSLeay) for HTTPS support

## Testing

Run the unit tests (no API key needed):

```sh
make test
```

Run the full suite including live API tests:

```sh
IPDATA_API_KEY=your_key_here make test
```

## License

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

## Links

- [ipdata.co API documentation](https://docs.ipdata.co/)
- [ipdata.co website](https://ipdata.co/)

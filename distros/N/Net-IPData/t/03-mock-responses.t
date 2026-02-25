#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 27;
use JSON::PP qw(encode_json decode_json);

use_ok('Net::IPData');

# --- Mock HTTP::Tiny to avoid real network calls ---

my @mock_responses;

{
    no warnings 'redefine';

    my $orig_get  = \&HTTP::Tiny::get;
    my $orig_post = \&HTTP::Tiny::post;

    *HTTP::Tiny::get = sub {
        my ($self, $url) = @_;
        return _next_mock_response($url);
    };

    *HTTP::Tiny::post = sub {
        my ($self, $url, $opts) = @_;
        return _next_mock_response($url, $opts);
    };
}

sub _next_mock_response {
    my ($url, $opts) = @_;
    die "No mock response queued for: $url" unless @mock_responses;
    my $mock = shift @mock_responses;
    if (ref $mock eq 'CODE') {
        return $mock->($url, $opts);
    }
    return $mock;
}

sub mock_json_response {
    my ($status, $data) = @_;
    push @mock_responses, {
        status  => $status,
        content => encode_json($data),
        headers => { 'content-type' => 'application/json' },
        success => ($status >= 200 && $status < 300) ? 1 : 0,
    };
}

sub mock_text_response {
    my ($status, $text) = @_;
    push @mock_responses, {
        status  => $status,
        content => $text,
        headers => { 'content-type' => 'text/plain' },
        success => ($status >= 200 && $status < 300) ? 1 : 0,
    };
}

my $ipd = Net::IPData->new(api_key => 'test_key_123');

# --- Test: successful IP lookup ---
{
    my $mock_data = {
        ip           => '8.8.8.8',
        is_eu        => JSON::PP::false,
        city         => 'Mountain View',
        region       => 'California',
        region_code  => 'CA',
        country_name => 'United States',
        country_code => 'US',
        continent_name => 'North America',
        continent_code => 'NA',
        latitude     => 37.386,
        longitude    => -122.0838,
        postal       => '94035',
        calling_code => '1',
        flag         => 'https://ipdata.co/flags/us.png',
        emoji_flag   => "\x{1F1FA}\x{1F1F8}",
        emoji_unicode => 'U+1F1FA U+1F1F8',
        asn          => {
            asn    => 'AS15169',
            name   => 'Google LLC',
            domain => 'google.com',
            route  => '8.8.8.0/24',
            type   => 'business',
        },
        company => {
            name    => 'Google LLC',
            domain  => 'google.com',
            network => '8.8.8.0/24',
            type    => 'business',
        },
        carrier  => { name => '', mcc => '', mnc => '' },
        languages => [
            { name => 'English', native => 'English', code => 'en' },
        ],
        currency => {
            name   => 'US Dollar',
            code   => 'USD',
            symbol => '$',
            native => '$',
            plural => 'US dollars',
        },
        time_zone => {
            name         => 'America/Los_Angeles',
            abbr         => 'PST',
            offset       => '-0800',
            is_dst       => JSON::PP::false,
            current_time => '2025-01-15T10:30:00-08:00',
        },
        threat => {
            is_tor            => JSON::PP::false,
            is_icloud_relay   => JSON::PP::false,
            is_proxy          => JSON::PP::false,
            is_datacenter     => JSON::PP::false,
            is_anonymous      => JSON::PP::false,
            is_known_attacker => JSON::PP::false,
            is_known_abuser   => JSON::PP::false,
            is_threat         => JSON::PP::false,
            is_bogon          => JSON::PP::false,
        },
        count => 0,
    };

    mock_json_response(200, $mock_data);
    my $result = $ipd->lookup('8.8.8.8');
    is($result->{ip}, '8.8.8.8', 'lookup returns correct IP');
    is($result->{country_name}, 'United States', 'lookup returns country_name');
    is($result->{city}, 'Mountain View', 'lookup returns city');
    is($result->{asn}{name}, 'Google LLC', 'lookup returns nested ASN name');
    is($result->{currency}{code}, 'USD', 'lookup returns currency code');
    is($result->{time_zone}{name}, 'America/Los_Angeles', 'lookup returns timezone');
    ok(!$result->{threat}{is_tor}, 'threat is_tor is false');
}

# --- Test: lookup_mine (no IP) ---
{
    mock_json_response(200, { ip => '203.0.113.1', country_name => 'Australia' });
    my $result = $ipd->lookup_mine();
    is($result->{ip}, '203.0.113.1', 'lookup_mine returns IP');
    is($result->{country_name}, 'Australia', 'lookup_mine returns country');
}

# --- Test: lookup with field filtering ---
{
    mock_json_response(200, { ip => '8.8.8.8', country_name => 'United States' });
    my $result = $ipd->lookup('8.8.8.8', fields => [qw(ip country_name)]);
    is($result->{ip}, '8.8.8.8', 'filtered lookup returns IP');
    is($result->{country_name}, 'United States', 'filtered lookup returns country_name');
}

# --- Test: lookup_field returns a single text value ---
{
    mock_text_response(200, '"United States"');
    my $result = $ipd->lookup_field('8.8.8.8', 'country_name');
    is($result, 'United States', 'lookup_field returns plain text');
}

# --- Test: lookup_field returns JSON for nested fields ---
{
    mock_json_response(200, { asn => 'AS15169', name => 'Google LLC', domain => 'google.com', route => '8.8.8.0/24', type => 'business' });
    my $result = $ipd->lookup_field('8.8.8.8', 'asn');
    is($result->{name}, 'Google LLC', 'lookup_field returns parsed JSON for asn');
}

# --- Test: bulk lookup ---
{
    my $bulk_data = [
        { ip => '8.8.8.8', country_name => 'United States' },
        { ip => '1.1.1.1', country_name => 'Australia' },
    ];
    mock_json_response(200, $bulk_data);

    my $results = $ipd->bulk(['8.8.8.8', '1.1.1.1']);
    is(ref $results, 'ARRAY', 'bulk returns array ref');
    is(scalar @$results, 2, 'bulk returns 2 results');
    is($results->[0]{ip}, '8.8.8.8', 'bulk result 0 IP');
    is($results->[1]{country_name}, 'Australia', 'bulk result 1 country');
}

# --- Test: convenience methods ---
{
    mock_json_response(200, { is_tor => JSON::PP::false, is_proxy => JSON::PP::true, is_threat => JSON::PP::true });
    my $threat = $ipd->threat('8.8.8.8');
    ok($threat->{is_proxy}, 'threat convenience method works');
}

{
    mock_json_response(200, { name => 'USD', code => 'USD', symbol => '$' });
    my $curr = $ipd->currency('8.8.8.8');
    is($curr->{code}, 'USD', 'currency convenience method works');
}

# --- Test: API error responses ---
{
    mock_json_response(401, { message => 'You have not provided a valid API Key.' });
    eval { $ipd->lookup('8.8.8.8') };
    like($@, qr/401/, 'error includes status code');
    like($@, qr/valid API Key/i, 'error includes API message');
}

{
    mock_json_response(403, { message => 'Access forbidden.' });
    eval { $ipd->lookup('8.8.8.8') };
    like($@, qr/403/, '403 error propagated');
}

{
    mock_json_response(429, { message => 'You have exceeded your rate limit.' });
    eval { $ipd->lookup('8.8.8.8') };
    like($@, qr/429/, '429 rate limit error propagated');
    like($@, qr/rate limit/i, '429 message preserved');
}

# --- Test: network failure (HTTP::Tiny status 599) ---
{
    push @mock_responses, {
        status  => 599,
        content => 'Connection timed out',
        headers => {},
        success => 0,
    };
    eval { $ipd->lookup('8.8.8.8') };
    like($@, qr/Network error/i, 'network failure raises error');
    like($@, qr/timed out/i, 'network error includes reason');
}

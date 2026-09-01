#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Tomba::Client;
use Tomba::Finder;

# Credentials from env vars
my $key    = $ENV{TOMBA_API_KEY} || "ta_placeholder_key_for_unit_testing_only_x";
my $secret = $ENV{TOMBA_SECRET_KEY} || "ts_placeholder-0000-0000-0000-0000000000";

# Test Tomba::Client constructor
ok(Tomba::Client->can('new'), 'Tomba::Client constructor exists');

my $client = Tomba::Client->new($key, $secret);
isa_ok($client, 'Tomba::Client', 'new returns a Tomba::Client object');
is($client->{apiKey}, $key, 'Client: API key is stored');
is($client->{apiSecret}, $secret, 'Client: API secret is stored');
is($client->{baseUrl}, 'https://api.tomba.io/v1', 'Client: default base URL is set');

# Test custom base URL
my $custom_client = Tomba::Client->new($key, $secret, 'https://custom.api.tomba.io/v1');
is($custom_client->{baseUrl}, 'https://custom.api.tomba.io/v1', 'Client: custom base URL is set');

# Test Tomba::Finder constructor (backward compatibility)
ok(Tomba::Finder->can('new'), 'Tomba::Finder constructor exists');

my $tomba = Tomba::Finder->new($key, $secret);
isa_ok($tomba, 'Tomba::Finder', 'new returns a Tomba::Finder object');
isa_ok($tomba, 'Tomba::Client', 'Tomba::Finder isa Tomba::Client');

is($tomba->{apiKey}, $key, 'Finder: API key is stored');
is($tomba->{apiSecret}, $secret, 'Finder: API secret is stored');
is($tomba->{baseUrl}, 'https://api.tomba.io/v1', 'Finder: default base URL is set');

# Test custom base URL via Finder
my $custom = Tomba::Finder->new($key, $secret, 'https://custom.api.tomba.io/v1');
is($custom->{baseUrl}, 'https://custom.api.tomba.io/v1', 'Finder: custom base URL is set');

# Test invalid key
eval { Tomba::Client->new("ta_short", $secret) };
like($@, qr/Invalid Tomba api key/, 'Client: dies on invalid API key');

eval { Tomba::Finder->new("ta_short", $secret) };
like($@, qr/Invalid Tomba api key/, 'Finder: dies on invalid API key');

# Test invalid secret
eval { Tomba::Client->new($key, "ts_short") };
like($@, qr/Invalid Tomba api secret/, 'Client: dies on invalid API secret');

eval { Tomba::Finder->new($key, "ts_short") };
like($@, qr/Invalid Tomba api secret/, 'Finder: dies on invalid API secret');

done_testing();

#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 14;

use_ok('Net::IPData');

# --- api_key is required ---
eval { Net::IPData->new() };
like($@, qr/api_key/, 'dies without api_key');

eval { Net::IPData->new(api_key => '') };
like($@, qr/api_key/, 'dies with empty api_key');

# --- default construction ---
my $ipd = Net::IPData->new(api_key => 'test_key');
isa_ok($ipd, 'Net::IPData');
is($ipd->api_key,  'test_key',                      'api_key accessor');
is($ipd->base_url, 'https://api.ipdata.co',         'default base_url');
is($ipd->timeout,  30,                               'default timeout');

# --- EU endpoint ---
my $eu = Net::IPData->new(api_key => 'test_key', eu => 1);
is($eu->base_url, 'https://eu-api.ipdata.co', 'EU base_url');

# --- custom base_url overrides eu ---
my $custom = Net::IPData->new(
    api_key  => 'test_key',
    base_url => 'https://custom.example.com/v1',
    eu       => 1,
);
is($custom->base_url, 'https://custom.example.com/v1', 'custom base_url overrides eu');

# --- custom timeout ---
my $slow = Net::IPData->new(api_key => 'test_key', timeout => 60);
is($slow->timeout, 60, 'custom timeout');

# --- trailing slash stripped ---
my $slash = Net::IPData->new(api_key => 'test_key', base_url => 'https://api.ipdata.co///');
is($slash->base_url, 'https://api.ipdata.co', 'trailing slashes stripped');

# --- URL building (internal, but verify via lookup_field argument validation) ---
eval { $ipd->lookup_field('8.8.8.8', 'invalid_field_xyz') };
like($@, qr/Invalid field/, 'rejects invalid field name');

eval { $ipd->lookup_field('', 'ip') };
like($@, qr/ip.*missing/i, 'lookup_field requires ip');

eval { $ipd->lookup_field('8.8.8.8', '') };
like($@, qr/field.*missing/i, 'lookup_field requires field');

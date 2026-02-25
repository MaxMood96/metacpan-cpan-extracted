#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 11;

use_ok('Net::IPData');

my $ipd = Net::IPData->new(api_key => 'test');

# --- bulk validation ---
eval { $ipd->bulk('not_an_array') };
like($@, qr/array reference/i, 'bulk rejects non-arrayref');

eval { $ipd->bulk([]) };
like($@, qr/at least one/i, 'bulk rejects empty array');

eval { $ipd->bulk([('1.2.3.4') x 101]) };
like($@, qr/maximum/i, 'bulk rejects more than 100 IPs');

# --- field validation in lookup ---
eval { $ipd->lookup('8.8.8.8', fields => ['ip', 'bogus_field']) };
like($@, qr/Invalid field.*bogus_field/i, 'lookup rejects invalid fields');

# --- field validation in bulk ---
eval { $ipd->bulk(['8.8.8.8'], fields => ['not_real']) };
like($@, qr/Invalid field/i, 'bulk rejects invalid fields');

# --- valid fields accepted (these will fail at network level, not validation) ---
eval { $ipd->lookup('8.8.8.8', fields => [qw(ip country_name asn)]) };
# Should die from network error, not field validation
like($@, qr/(?:Network|error|connect)/i, 'valid fields pass validation');

# --- fields as comma-separated string ---
eval { $ipd->lookup('8.8.8.8', fields => 'ip,country_name') };
like($@, qr/(?:Network|error|connect)/i, 'comma-separated fields pass validation');

# --- lookup_field rejects fields not available via path ---
eval { $ipd->lookup_field('8.8.8.8', 'company') };
like($@, qr/Invalid field/, 'lookup_field rejects non-path field: company');

eval { $ipd->lookup_field('8.8.8.8', 'count') };
like($@, qr/Invalid field/, 'lookup_field rejects non-path field: count');

# --- lookup_field accepts valid path fields ---
eval { $ipd->lookup_field('8.8.8.8', 'country_name') };
like($@, qr/(?:Network|error|connect)/i, 'valid path field passes validation');

#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Live integration tests - only run when IPDATA_API_KEY is set
unless ($ENV{IPDATA_API_KEY}) {
    plan skip_all => 'Set IPDATA_API_KEY to run live API tests';
}

plan tests => 22;

use_ok('Net::IPData');

my $ipd = Net::IPData->new(api_key => $ENV{IPDATA_API_KEY});

# --- lookup a known IP ---
my $result = $ipd->lookup('8.8.8.8');
is($result->{ip}, '8.8.8.8', 'live: lookup returns correct IP');
is($result->{country_code}, 'US', 'live: lookup returns US');
ok(exists $result->{asn}, 'live: response contains asn');
ok(exists $result->{threat}, 'live: response contains threat');
ok(exists $result->{currency}, 'live: response contains currency');
ok(exists $result->{time_zone}, 'live: response contains time_zone');
ok(exists $result->{languages}, 'live: response contains languages');

# --- lookup own IP ---
my $me = $ipd->lookup_mine();
ok($me->{ip}, 'live: lookup_mine returns an IP');

# --- field filtering ---
my $filtered = $ipd->lookup('8.8.8.8', fields => [qw(ip country_name)]);
is($filtered->{ip}, '8.8.8.8', 'live: filtered lookup returns IP');
ok(exists $filtered->{country_name}, 'live: filtered lookup returns country_name');

# --- single field lookup ---
my $country = $ipd->country_name('8.8.8.8');
ok(defined $country && length $country, 'live: country_name returns a value');

my $asn = $ipd->asn('8.8.8.8');
is(ref $asn, 'HASH', 'live: asn returns a hashref');
ok($asn->{asn}, 'live: asn contains asn field');

my $threat = $ipd->threat('8.8.8.8');
is(ref $threat, 'HASH', 'live: threat returns a hashref');
ok(exists $threat->{is_tor}, 'live: threat contains is_tor');

my $tz = $ipd->time_zone('8.8.8.8');
is(ref $tz, 'HASH', 'live: time_zone returns a hashref');
ok($tz->{name}, 'live: time_zone contains name');

# --- bulk lookup ---
my $bulk = $ipd->bulk(['8.8.8.8', '1.1.1.1']);
is(ref $bulk, 'ARRAY', 'live: bulk returns arrayref');
is(scalar @$bulk, 2, 'live: bulk returns 2 results');
is($bulk->[0]{ip}, '8.8.8.8', 'live: bulk first result');
is($bulk->[1]{ip}, '1.1.1.1', 'live: bulk second result');

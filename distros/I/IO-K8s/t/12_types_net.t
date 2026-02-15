#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;

use IO::K8s::Types::Net qw( parse_ip cidr_contains is_rfc1918 );
use IO::K8s::Types::Net qw( IPv4 IPv6 IPAddress CIDR NetIP );

# --- IPv4 type ---

subtest 'IPv4 type' => sub {
    ok(IPv4->check('10.0.0.1'), 'valid IPv4');
    ok(IPv4->check('192.168.1.1'), 'valid IPv4 private');
    ok(IPv4->check('0.0.0.0'), 'valid IPv4 zero');
    ok(IPv4->check('255.255.255.255'), 'valid IPv4 broadcast');
    ok(!IPv4->check('::1'), 'rejects IPv6');
    ok(!IPv4->check('10.0.0.0/8'), 'rejects CIDR');
    ok(!IPv4->check('not-an-ip'), 'rejects garbage');
    ok(!IPv4->check(''), 'rejects empty');
};

# --- IPv6 type ---

subtest 'IPv6 type' => sub {
    ok(IPv6->check('::1'), 'valid IPv6 loopback');
    ok(IPv6->check('fe80::1'), 'valid IPv6 link-local');
    ok(IPv6->check('2001:db8::1'), 'valid IPv6 documentation');
    ok(!IPv6->check('10.0.0.1'), 'rejects IPv4');
    ok(!IPv6->check('::1/128'), 'rejects CIDR');
    ok(!IPv6->check('not-an-ip'), 'rejects garbage');
};

# --- IPAddress type ---

subtest 'IPAddress type' => sub {
    ok(IPAddress->check('10.0.0.1'), 'accepts IPv4');
    ok(IPAddress->check('::1'), 'accepts IPv6');
    ok(!IPAddress->check('10.0.0.0/8'), 'rejects CIDR');
    ok(!IPAddress->check('garbage'), 'rejects garbage');
};

# --- CIDR type ---

subtest 'CIDR type' => sub {
    ok(CIDR->check('10.0.0.0/8'), 'valid IPv4 CIDR');
    ok(CIDR->check('192.168.1.0/24'), 'valid IPv4 /24');
    ok(CIDR->check('::1/128'), 'valid IPv6 CIDR');
    ok(CIDR->check('2001:db8::/32'), 'valid IPv6 /32');
    ok(!CIDR->check('10.0.0.1'), 'rejects plain IP');
    ok(!CIDR->check('garbage/24'), 'rejects garbage CIDR');
};

# --- NetIP type ---

subtest 'NetIP type' => sub {
    my $ip = Net::IP->new('10.0.0.1');
    ok(NetIP->check($ip), 'accepts Net::IP object');
    ok(!NetIP->check('10.0.0.1'), 'rejects plain string');

    # Coercion
    ok(NetIP->has_coercion, 'NetIP has coercion');
    my $coerced = NetIP->coerce('10.0.0.1');
    isa_ok($coerced, 'Net::IP');
    is($coerced->ip, '10.0.0.1', 'coerced IP value');
};

# --- Utility: parse_ip ---

subtest 'parse_ip' => sub {
    my $ip = parse_ip('10.0.0.1');
    isa_ok($ip, 'Net::IP');
    is($ip->version, 4, 'parsed as IPv4');

    my $ip6 = parse_ip('::1');
    isa_ok($ip6, 'Net::IP');
    is($ip6->version, 6, 'parsed as IPv6');

    my $bad = parse_ip('not-an-ip');
    ok(!defined $bad, 'returns undef for bad input');
};

# --- Utility: cidr_contains ---

subtest 'cidr_contains' => sub {
    ok(cidr_contains('10.0.0.0/8', '10.1.2.3'), '10/8 contains 10.1.2.3');
    ok(cidr_contains('192.168.1.0/24', '192.168.1.100'), '/24 contains host');
    ok(!cidr_contains('192.168.1.0/24', '192.168.2.1'), '/24 does not contain .2.1');
    ok(!cidr_contains('10.0.0.0/8', '172.16.0.1'), '10/8 does not contain 172.16');
    ok(!cidr_contains('garbage', '10.0.0.1'), 'bad CIDR returns false');
    ok(!cidr_contains('10.0.0.0/8', 'garbage'), 'bad IP returns false');
};

# --- Utility: is_rfc1918 ---

subtest 'is_rfc1918' => sub {
    ok(is_rfc1918('10.0.0.1'), '10/8 is private');
    ok(is_rfc1918('10.255.255.255'), '10.255.255.255 is private');
    ok(is_rfc1918('172.16.0.1'), '172.16/12 is private');
    ok(is_rfc1918('172.31.255.255'), '172.31.255.255 is private');
    ok(is_rfc1918('192.168.0.1'), '192.168/16 is private');
    ok(is_rfc1918('192.168.255.255'), '192.168.255.255 is private');
    ok(!is_rfc1918('8.8.8.8'), '8.8.8.8 is not private');
    ok(!is_rfc1918('172.32.0.1'), '172.32.0.1 is not private');
    ok(!is_rfc1918('192.169.0.1'), '192.169.0.1 is not private');
};

done_testing;

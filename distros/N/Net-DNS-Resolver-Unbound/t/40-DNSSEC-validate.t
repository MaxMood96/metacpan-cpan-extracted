#!/usr/bin/perl
#

use strict;
use warnings;
use Test::More;

use Net::DNS::Resolver::Unbound;

my $resolver = Net::DNS::Resolver::Unbound->new(
	debug_level => 0,
	nameserver  => '1.1.1.1',
	nameserver  => '8.8.8.8',
	);

my $root_key = '/var/lib/unbound/root.key';
$root_key = 't/trust_anchor' unless -r $root_key;

plan skip_all => 'resolver not loaded' unless $resolver;
plan skip_all => 'unreadable root key' unless -r $root_key;
plan tests    => 3;

$resolver->add_ta_file($root_key);	## specify trust anchor

my @query = qw(www.example.com AAAA);
my $reply = $resolver->send(@query);
ok( $reply, "resolver->send(@query)" );

is( $reply->header->do, 1, 'reply header DO bit set' );
is( $reply->header->ad, 1, 'reply header AD bit set' );

exit;


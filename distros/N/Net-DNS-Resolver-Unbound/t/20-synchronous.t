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

plan skip_all => 'resolver not loaded' unless $resolver;
plan tests    => 4;

my ( $name, $domain ) = qw(www example.com);

ok( $resolver->send("$name.$domain"), "resolver->send('$name.$domain')" );

$resolver->domain($domain);
ok( $resolver->query($name), "resolver->query('$name')" );


$resolver->searchlist( "nxd.$domain", $domain );
ok( $resolver->search($name), "resolver->search('$name')" );


$resolver->debug(1);

my $packet = $resolver->_make_query_packet("$name.$domain");
my $reply  = $resolver->send($packet);
ok( $reply, 'resolver->send( $packet )' );


exit;


#!perl -T
use 5.10.0;
use strict;
use warnings;
use Test::More;

BEGIN { use_ok('Net::IPAM::IP') || print "Bail out!\n"; }

can_ok( 'Net::IPAM::IP', 'new' );
can_ok( 'Net::IPAM::IP', 'new_from_bytes' );

eval { Net::IPAM::IP->new };
like( $@, qr/missing/i, 'new: missing arg' );

eval { Net::IPAM::IP->new_from_bytes };
like( $@, qr/missing/i, 'new_from_bytes: missing arg' );

my $ip    = Net::IPAM::IP->new('1.2.3.4');
my $bytes = substr( $ip->bytes, 1 );
eval { Net::IPAM::IP->new_from_bytes($bytes) };
like( $@, qr/illegal input/i, 'new_from_bytes: wrong number of bytes' );

$ip    = Net::IPAM::IP->new('fe80::1');
$bytes = substr( $ip->bytes, 1 );
eval { Net::IPAM::IP->new_from_bytes($bytes) };
like( $@, qr/illegal input/i, 'new_from_bytes: wrong number of bytes' );

{
  local $SIG{__WARN__} = sub { die @_ };
  eval { Net::IPAM::IP->getaddrs() };
  like( $@, qr/missing/i, 'getaddrs: missing arg' );
}

done_testing();

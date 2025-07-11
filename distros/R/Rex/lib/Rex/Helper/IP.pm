#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Helper::IP;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Data::Validate::IP 'is_ipv4', 'is_ipv6';

sub is_ip {
  my ($ip) = @_;

  if ( is_ipv4($ip) || is_ipv6($ip) ) {
    return 1;
  }
  return 0;
}

sub get_server_and_port {
  my ( $server, $default_port ) = @_;

  my ( $rs, $rp );

  if ( $server =~ m/:(\d+)$/ && !is_ipv6($server) ) {
    return split( /:/, $server );
  }

  if ( $server =~ m/\/(\d+)$/ ) {
    return split( /\/(\d+)$/, $server );
  }

  if ( is_ip($server) ) {
    if ( is_ipv6($server) ) {
      ( $rs, $rp ) = split( /\//, $server );
    }
    else {
      ( $rs, $rp ) = split( /[:\/]/, $server );
    }
  }
  else {
    ( $rs, $rp ) = split( /[:\/]/, $server );
  }

  $rp ||= $default_port;

  return ( $rs, $rp );
}

1;

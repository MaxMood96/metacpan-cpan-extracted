#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Hardware::Network;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Data::Dumper;

use Rex::Commands::Gather;
use Rex::Logger;

require Rex::Hardware;

sub get {

  my $cache          = Rex::get_cache();
  my $cache_key_name = $cache->gen_key_name("hardware.network");

  if ( $cache->valid($cache_key_name) ) {
    return $cache->get($cache_key_name);
  }

  my $hw_class = _get_class();
  unless ($hw_class) {
    return {};
  }

  my $data = {

    networkdevices       => $hw_class->get_network_devices(),
    networkconfiguration => $hw_class->get_network_configuration(),

  };

  $cache->set( $cache_key_name, $data );

  return $data;

}

sub route {
  return _get_class()->route();
}

sub default_gateway {
  return _get_class()->default_gateway(@_);
}

sub netstat {
  return _get_class()->netstat();
}

sub _get_class {
  my $os_type = Rex::Commands::Gather::get_operating_system();

  $os_type = "Linux"   if Rex::Commands::Gather::is_linux();
  $os_type = "Solaris" if Rex::Commands::Gather::is_solaris();

  my $hw_class = "Rex::Hardware::Network::$os_type";
  eval "use $hw_class;";

  if ($@) {
    Rex::Logger::debug("No network information on $os_type");
    return;
  }

  return $hw_class;
}

1;

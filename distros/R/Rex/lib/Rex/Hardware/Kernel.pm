#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Hardware::Kernel;

use v5.12.5;
use warnings;

our $VERSION = '1.16.0'; # VERSION

use Rex::Helper::Run;

require Rex::Hardware;

sub get {

  my $cache          = Rex::get_cache();
  my $cache_key_name = $cache->gen_key_name("hardware.kernel");

  if ( $cache->valid($cache_key_name) ) {
    return $cache->get($cache_key_name);
  }

  my $data = {
    architecture  => i_run("uname -m"),
    kernel        => i_run("uname -s"),
    kernelrelease => i_run("uname -r"),
    kernelversion => i_run("uname -v"),
  };

  $cache->set( $cache_key_name, $data );

  return $data;

}

1;

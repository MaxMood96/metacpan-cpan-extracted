#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::Cache;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

sub create {
  my ( $class, $type ) = @_;

  unless ($type) {
    $type = Rex::Config->get_cache_type;
  }

  my $class_name = "Rex::Interface::Cache::$type";
  eval "use $class_name;";
  if ($@) { die("Error loading connection interface $type.\n$@"); }

  return $class_name->new;
}

1;

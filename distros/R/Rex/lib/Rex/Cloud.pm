#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Cloud;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;

@EXPORT = qw(get_cloud_service);

my %CLOUD_SERVICE;

sub register_cloud_service {
  my ( $class, $service_name, $service_class ) = @_;
  $CLOUD_SERVICE{"\L$service_name"} = $service_class;
  return 1;
}

sub register_cloud_provider {
  my $class = shift;
  $class->register_cloud_service(@_);
}

sub get_cloud_service {

  my ($service) = @_;

  if ( exists $CLOUD_SERVICE{"\L$service"} ) {
    eval "use " . $CLOUD_SERVICE{"\L$service"};

    my $mod = $CLOUD_SERVICE{"\L$service"};
    return $mod->new;
  }
  else {
    eval "use Rex::Cloud::$service";

    if ($@) {
      Rex::Logger::info("Cloud Service $service not supported.");
      Rex::Logger::info($@);
      return 0;
    }

    my $mod = "Rex::Cloud::$service";
    return $mod->new;
  }

}

1;

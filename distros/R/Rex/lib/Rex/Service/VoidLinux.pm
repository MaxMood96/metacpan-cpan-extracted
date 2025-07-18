#
# (c) 2019 Leah Neukirchen <leah@vuxu.org>
# based on Rex::Service::Gentoo
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Service::VoidLinux;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Helper::Run;

use base qw(Rex::Service::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    start          => 'ln -sf /etc/sv/%s /var/service',
    restart        => 'sv restart %s',
    stop           => 'rm /var/service/%s',
    reload         => 'sv reload %s',
    status         => 'sv status %s | grep -q ^run:',
    ensure_stop    => 'rm /var/service/%s',
    ensure_start   => 'ln -sf /etc/sv/%s /var/service',
    service_exists => 'test -d /etc/sv/%s',
  };

  return $self;
}

sub action {
  my ( $self, $service, $action ) = @_;

  my $ret_val;
  eval {
    i_run "sv $action $service >/dev/null", nohup => 1;
    $ret_val = 1;
  } or do {
    $ret_val = 0;
  };

  return $ret_val;
}

1;

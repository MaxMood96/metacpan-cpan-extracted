#
# This file is part of DNS-NIOS
#
# This software is Copyright (c) 2021 by Christian Segundo.
#
# This is free software, licensed under:
#
#   The Artistic License 2.0 (GPL Compatible)
#
package # Hide from PAUSE
  Test::SpawnNIOS;

use strictures 2;

use base qw( Exporter );

use File::Basename;
use Cwd 'abs_path';
use Net::EmptyPort qw(empty_port);
use LWP::UserAgent;
use Test::More;
use Data::Dumper;

sub nios {
  my ( $class, %args ) = @_;
  my $self = bless {}, $class;

  $self->{nios_path} = abs_path( dirname(__FILE__) ) . "/NIOS.pl";
  $self->{port}      = empty_port();
  $self->{addr}      = "127.0.0.1:" . $self->{port};

  diag( "Spawn NIOS at " . $self->{addr} . " from " . $self->{nios_path} )
    if $ENV{NIOS_DEBUG};

  my $pid = fork();
  if ($pid) {
    diag("NIOS pid: $pid") if $ENV{NIOS_DEBUG};
    $self->{pid} = $pid;
    my $max = 20;
    while ($max) {
      my $ua       = LWP::UserAgent->new( timeout => 10 );
      my $response = $ua->get( 'http://' . $self->addr );
      return $self if $response->{_rc} eq 404;
      sleep(5);
      $max--;
    }
    $self->shitdown and die;
  }
  elsif ( defined $pid ) {
    exec("$^X $self->{nios_path} daemon -l http://$self->{addr}");
    warn "## '@_': $!";
    exit(1);
  }
  die "Could not fork(): $!";
}

sub addr {
  return shift->{addr};
}

sub shitdown {
  kill 9, shift->{pid};
}

1;

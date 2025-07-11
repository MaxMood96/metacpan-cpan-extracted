#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Virtualization::LibVirt::hypervisor;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Logger;
use Rex::Helper::Run;

use XML::Simple;

use Data::Dumper;

sub execute {
  my ( $class, $arg1, %opt ) = @_;
  my $virt_settings = Rex::Config->get("virtualization");
  chomp( my $uri =
      ref($virt_settings) ? $virt_settings->{connect} : i_run "virsh uri" );

  unless ($arg1) {
    die("You have to define the vm name!");
  }
  my ( $xml, @dominfo );
  if ( $arg1 eq 'capabilities' ) {
    @dominfo = i_run "virsh -c $uri capabilities", fail_ok => 1;
    if ( $? != 0 ) {
      die("Error running virsh capabilities");
    }

    my $xs = XML::Simple->new();
    $xml = $xs->XMLin(
      join( "", @dominfo ),
      KeepRoot     => 1,
      KeyAttr      => 1,
      ForceContent => 1
    );
  }
  else {
    Rex::Logger::debug("Unknown action $arg1");
    die("Unknown action $arg1");
  }

  my %ret = ();
  my ( $k, $v );

  if ( ref( $xml->{'capabilities'}->{'guest'} ) ne "ARRAY" ) {
    $xml->{'capabilities'}->{'guest'} = [ $xml->{'capabilities'}->{'guest'} ];
  }

  for my $line ( @{ $xml->{'capabilities'}->{'guest'} } ) {

    next if ( $line->{'arch'}->{'name'} ne "x86_64" );

    $ret{ $line->{'arch'}->{'name'} } = 'true'
      if defined( $line->{'arch'}->{'name'} );

    $ret{'emulator'} = $line->{'arch'}->{'emulator'}->{'content'}
      if defined( $line->{'arch'}->{'emulator'}->{'content'} );

    $ret{'loader'} = $line->{'arch'}->{'loader'}->{'content'}
      if defined( $line->{'arch'}->{'loader'}->{'content'} );

    $ret{ $line->{'os_type'}->{'content'} } = 'true'
      if defined( $line->{'os_type'}->{'content'} );

    if ( defined( $line->{'arch'}->{'domain'} )
      && ref( $line->{'arch'}->{'domain'} ) eq 'ARRAY' )
    {
      for ( @{ $line->{'arch'}->{'domain'} } ) {
        $ret{ $_->{'type'} } = 'true';
      }
    }
    else {
      $ret{ $line->{'arch'}->{'domain'}->{'type'} } = 'true'
        if defined( $line->{'arch'}->{'domain'}->{'type'} );
    }
  }

  return \%ret;

}

1;

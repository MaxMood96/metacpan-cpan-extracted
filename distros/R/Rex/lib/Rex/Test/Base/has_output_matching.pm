#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Test::Base::has_output_matching;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex -minimal;
use Rex::Helper::Run;
use base qw(Rex::Test::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  my ( $pkg, $file ) = caller(0);

  return $self;
}

sub run_test {
  my ( $self, $exec, $wanted_output ) = @_;
  my $output = i_exec $exec;
  $self->like( $output, $wanted_output, "Output of $exec is as expected." );
}

1;

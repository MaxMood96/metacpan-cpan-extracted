#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Output;

use v5.14.4;
use warnings;

my $handle;
use vars qw($output_object);

BEGIN { IPC::Shareable->use; }
END   { IPC::Shareable->clean_up_all; }

use base 'Rex::Output::Base';

our $VERSION = '1.16.1'; # VERSION

sub get {
  my ( $class, $output_module ) = @_;

  return $output_object if ($output_object);

  return unless ($output_module);

  $handle = tie $output_object, 'IPC::Shareable', undef, { destroy => 1 }
    unless $handle;

  eval "use Rex::Output::$output_module;";
  if ($@) {
    die("Output Module ,,$output_module'' not found.");
  }

  my $output_class = "Rex::Output::$output_module";
  $output_object = $output_class->new;

  return $class;
}

sub _action {
  my ( $class, $action, @args ) = @_;

  return unless ( defined $output_object );
  $handle->shlock();
  $output_object->$action(@args);
  $handle->shunlock();
}

sub add {
  my $class = shift;

  return $class->_action( 'add', @_ );
}

sub error {
  my $class = shift;

  return $class->_action( 'error', @_ );
}

sub write {
  my $class = shift;

  return $class->_action( 'write', @_ );
}

1;

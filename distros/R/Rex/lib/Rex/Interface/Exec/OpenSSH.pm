#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Interface::Exec::OpenSSH;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

use Rex::Helper::SSH2;
require Rex::Commands;
use Rex::Interface::Exec::SSH;
use Rex::Interface::Exec::IOReader;

use IO::Select;

use base qw(Rex::Interface::Exec::SSH Rex::Interface::Exec::IOReader);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub _exec {
  my ( $self, $exec, $option ) = @_;
  my ( $out, $err, $pid, $out_fh, $err_fh );
  my $ssh = Rex::is_ssh();

  my $tty = !Rex::Config->get_no_tty;

  ( undef, $out_fh, $err_fh, $pid ) = $ssh->open3( { tty => $tty }, $exec );

  ( $out, $err ) = $self->io_read( $out_fh, $err_fh, $pid, $option );

  waitpid( $pid, 0 ) or die($!);
  if ( $ssh->error || $? ) {

    # we need to bitshift $? so that $? contains the right (and for all
    # connection methods the same) exit code after a run()/i_run() call.
    # this is for the user, so that he can query $? in his task.
    $? >>= 8;
  }
  return ( $out, $err );
}

1;

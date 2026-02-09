#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2026 -- leonerd@leonerd.org.uk

package IO::Async::Loop::FutureIO 0.01;

use v5.14;
use warnings;

use constant API_VERSION => '0.76';

# We cannot support ->watch_process( 0 => ... ) because Future::IO does not
# give us a hook
use constant _CAN_WATCH_ALL_PIDS => 0;

use base qw( IO::Async::Loop );
IO::Async::Loop->VERSION( '0.49' );

use Carp;

use Future::IO 0.19;
use Future::IO 0.19 qw( POLLIN POLLOUT );

=head1 NAME

C<IO::Async::Loop::FutureIO> - use C<IO::Async> with C<Future::IO>

=head1 SYNOPSIS

=for highlighter language=perl

   use IO::Async::Loop::FutureIO;

   use Future::IO:
   Future::IO->load_best_impl;

=head1 DESCRIPTION

This subclass of L<IO::Async::Loop> uses L<Future::IO> to perform its work.

Currently there are a few features that don't yet work, due to missing support
from C<Future::IO> itself. Hopefully a later version of C<Future::IO> will be
able to provide these missing pieces, and then this module will be shipped by
default in the main C<IO-Async> distribution.

=head2 Missing Features

Currently the following things do not work with this module:

=over 4

=item Signals

The C<watch_signal> and C<unwatch_signal> methods are not currently
implemented, because C<Future::IO> does not support a general purpose signal
wait ability. Once this is available, these methods can be added.

=item Watching PID 0

Likewise, as C<Future::IO> only supports watching specific PIDs and not a
repeating wait for any process, this is not permitted here.

=item C<is_running>

The C<is_running> method cannot reliably answer whether C<Future::IO> itself
is currently blocked awaiting IO, so it is also not provided.

=item Metrics

This module would not be able to provide metrics on the overall operation of
C<Future::IO>, so it is not provided.

=back

=cut

sub new
{
   my $class = shift;
   my $self = $class->SUPER::__new( @_ );

   $Future::IO::IMPL eq "Future::IO::Impl::IOAsync" and
      croak "Cannot mutually build Future::IO and IO::Async on each other";

   return $self;
}

sub _more_f
{
   my $self = shift;
   my ( $f ) = @_;

   my $loop_f = ( $self->{next_loop_f} //= $f->new );

   $f->on_ready( sub {
      $loop_f->done unless $loop_f->is_ready;
   });

   return $f;
}

sub loop_once
{
   my $self = shift;
   my ( $timeout ) = @_;

   my $timeout_f;
   if( defined $timeout ) {
      $timeout_f = $self->_more_f( Future::IO->sleep( $timeout ) );
   }

   if( my $f = $self->{next_loop_f} ) {
      undef $self->{next_loop_f};

      $f->await;
   }
   else {
      die "TODO: loop_once without next_loop_f";
   }

   $timeout_f->cancel if $timeout_f;
}

sub _poll_for_io
{
   my ( $watch, $handle, $mask, $cb ) = @_;

   my $key = "${mask}_f";

   $watch->{$key} = Future::IO->poll( $handle, $mask )
      ->on_done( sub {
         $cb->();

         _poll_for_io( $watch, $handle, $mask, $cb )
            if exists $watch->{$key};
      } );
}

sub watch_io
{
   my $self = shift;
   my %params = @_;

   my $handle = $params{handle} or die "Need a handle";
   my $watch = $self->{watch_io}{$handle} //= {};

   if( my $cb = $params{on_read_ready} ) {
      _poll_for_io( $watch, $handle, POLLIN, $cb );
   }
   if( my $cb = $params{on_write_ready} ) {
      _poll_for_io( $watch, $handle, POLLOUT, $cb );
   }
}

sub unwatch_io
{
   my $self = shift;
   my %params = @_;

   my $handle = $params{handle} or die "Need a handle";
   my $watch = $self->{watch_io}{$handle} or return;

   if( $params{on_read_ready} ) {
      my $mask = POLLIN;
      ( delete $watch->{"${mask}_f"} )->cancel;
   }
   if( $params{on_write_ready} ) {
      my $mask = POLLOUT;
      ( delete $watch->{"${mask}_f"} )->cancel;
   }

   keys %$watch or
      delete $self->{watch_io}{$handle};
}

sub watch_time
{
   my $self = shift;
   my %params = @_;

   my $code = $params{code} or croak "Expected 'code' as CODE ref";
   my $now = $params{now} // $self->time;
   my $delay = $params{after} // ( $params{at} - $now );

   $delay = 0 if $delay < 0;

   return $self->_more_f(
      Future::IO->sleep( $delay )
         ->on_done( sub { $code->() } )
   );
}

sub unwatch_time
{
   my $self = shift;
   my ( $timer ) = @_;

   $timer->cancel;
}

sub watch_idle
{
   my $self = shift;
   my %params = @_;

   my $when = delete $params{when} or croak "Expected 'when'";

   my $code = delete $params{code} or croak "Expected 'code' as a CODE ref";

   $when eq "later" or croak "Expected 'when' to be 'later'";

   # Just treat it as a zero timer
   return $self->_more_f(
      Future::IO->sleep( 0 )
         ->on_done( sub { $code->() } )
   );
}

sub unwatch_idle
{
   my $self = shift;
   my ( $idle ) = @_;

   $idle->cancel;
}

sub watch_signal
{
   croak "Future::IO does not currently support signal watches";
}

sub unwatch_signal
{
   croak "Future::IO does not currently support signal watches";
}

sub watch_process
{
   my $self = shift;
   my ( $pid, $code ) = @_;

   defined $pid or croak "Require a PID for ->watch_process";
   $pid or croak "Require a PID for ->watch_process (cannot watch for all processes by PID=0)";

   my $waitpids = $self->{waitpids} //= {};

   $waitpids->{$pid} = $self->_more_f(
      Future::IO->waitpid( $pid )
         ->on_done( sub {
            delete $waitpids->{$pid};
            $code->( $pid, $_[0] );
         })
   );
}

sub unwatch_process
{
   my $self = shift;
   my ( $pid ) = @_;

   my $f = delete $self->{waitpids}{$pid};
   $f->cancel if $f;
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;

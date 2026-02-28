#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2020-2026 -- leonerd@leonerd.org.uk

package Future::IO::Impl::Glib 0.05;

use v5.14;
use warnings;
use base qw( Future::IO::ImplBase );

use Future::IO 0.20 qw( POLLIN POLLOUT POLLPRI POLLHUP POLLERR );
use Struct::Dumb qw( readonly_struct );

use Glib;

__PACKAGE__->APPLY;

=head1 NAME

C<Future::IO::Impl::Glib> - implement C<Future::IO> using C<Glib>

=head1 DESCRIPTION

=for highlighter language=perl

This module provides an implementation for L<Future::IO> which uses L<Glib>.
This is likely the preferred method of providing the API from Glib or Gtk
programs.

There are no additional methods to use in this module; it simply has to be
loaded, and will provide the C<Future::IO> implementation methods:

   use Future::IO;
   use Future::IO::Impl::Glib;

   my $f = Future::IO->sleep(5);
   ...

=cut

sub sleep
{
   shift;
   my ( $secs ) = @_;

   my $f = Future::IO::Impl::Glib::_Future->new;

   my $id = Glib::Timeout->add( $secs * 1000, sub {
      $f->done;
      return 0;
   } );
   $f->on_cancel( sub { Glib::Source->remove( $id ) } );

   return $f;
}

readonly_struct Poller => [qw( events f )];
my %pollers_by_fileno;

my %revents_map = (
   in  => POLLIN,
   out => POLLOUT,
   pri => POLLPRI,
   hup => POLLHUP,
   err => POLLERR,
);

sub poll
{
   shift;
   my ( $fh, $events ) = @_;

   my $f = Future::IO::Impl::Glib::_Future->new;

   push $pollers_by_fileno{$fh->fileno}->@*, Poller( $events, $f );

   _update_io( $fh->fileno );

   return $f;
}

my %sources_by_fileno; # {$fileno} => [ $sourceid, $got_mask ]

sub _update_io
{
   my ( $fileno ) = @_;

   my $want_mask = 0;
   $want_mask |= $_->events for ( my $pollers = $pollers_by_fileno{$fileno} )->@*;

   return if $sources_by_fileno{$fileno} and $sources_by_fileno{$fileno}[1] == $want_mask;

   if( my $id = $sources_by_fileno{$fileno}[0] ) {
      Glib::Source->remove( $id );
   }

   my @want_events;
   $want_mask & $revents_map{$_} and push @want_events, $_
      for sort keys %revents_map;

   unless( $want_mask ) {
      delete $sources_by_fileno{$fileno};
      return;
   }

   my $id = Glib::IO->add_watch( $fileno,
      [ @want_events, 'hup', 'err' ],
      sub {
         my ( undef, $ev ) = @_;

         my $revents = 0;
         $revents |= $revents_map{$_} for @$ev;

         # Find the next poller which cares about at least one of these events
         foreach my $idx ( 0 .. $#$pollers ) {
            my $want_revents = $revents & ( $pollers->[$idx]->events | POLLHUP|POLLERR )
               or next;

            my ( $poller ) = splice @$pollers, $idx, 1, ();

            $poller and $poller->f and $poller->f->done( $want_revents );
            last;
         }

         if( !@$pollers ) {
            delete $sources_by_fileno{$fileno};
            return 0;
         }

         _update_io( $fileno );
         return 1;
      }
   );

   $sources_by_fileno{$fileno} = [ $id, $want_mask ];
}

sub waitpid
{
   shift;
   my ( $pid ) = @_;

   my $f = Future::IO::Impl::Glib::_Future->new;

   my $id = Glib::Child->watch_add( $pid, sub {
      $f->done( $_[1] );
      return 0;
   } );
   $f->on_cancel( sub { Glib::Source->remove( $id ) } );

   return $f;
}

package Future::IO::Impl::Glib::_Future;
use base qw( Future );

sub await
{
   my $self = shift;
   Glib::MainContext->default->iteration( 1 ) until $self->is_ready;
   return $self;
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;

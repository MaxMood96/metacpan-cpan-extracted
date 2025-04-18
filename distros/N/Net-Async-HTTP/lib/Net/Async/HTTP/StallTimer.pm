#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2014-2023 -- leonerd@leonerd.org.uk

package Net::Async::HTTP::StallTimer 0.50;

use v5.14;
use warnings;
use base qw( IO::Async::Timer::Countdown );

sub _init
{
   my $self = shift;
   my ( $params ) = @_;
   $self->SUPER::_init( $params );

   $self->{future} = delete $params->{future};
}

sub reason :lvalue { shift->{stall_reason} }

sub on_expire
{
   my $self = shift;

   my $conn = $self->parent;

   $self->{future}->fail( "Stalled while ${\$self->reason}", stall_timeout => );

   $conn->close_now;
}

0x55AA;

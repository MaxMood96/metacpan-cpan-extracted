#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2023-2026 -- leonerd@leonerd.org.uk

use v5.26;
use warnings;
use Object::Pad 0.822 ':experimental(adjust_params inherit_field)';
use Sublike::Extended 0.29 qw( method );

package Device::Serial::SLuRM::Protocol 0.11;
class Device::Serial::SLuRM::Protocol
   :lexical_new;

use Carp;

use Future::AsyncAwait;
use Future::Buffer 0.03;
use Future::IO;

use Digest::CRC qw( crc8 );

use constant DEBUG => $ENV{SLURM_DEBUG} // 0;

# builtin::false only turned up at 5.36, grrrr
use constant false => !!0;

=encoding UTF-8

=head1 NAME

C<Device::Serial::SLuRM::Protocol> - implements the lower-level packet format of the SLµRM protocol

=head1 DESCRIPTION

This class provides the inner logic used by L<Device::Serial::SLuRM> and
L<Device::Serial::MSLuRM>.

=cut

use constant {
   SLURM_PKTCTRL_META   => 0x00,
      SLURM_PKTCTRL_META_RESET    => 0x01,
      SLURM_PKTCTRL_META_RESETACK => 0x02,

   SLURM_PKTCTRL_NOTIFY => 0x10,

   SLURM_PKTCTRL_REQUEST => 0x30,

   SLURM_PKTCTRL_RESPONSE => 0xB0,
   SLURM_PKTCTRL_ACK      => 0xC0,
   SLURM_PKTCTRL_ERR      => 0xE0,
};

# Metrics support is entirely optional
our $METRICS;
eval {
   require Metrics::Any and Metrics::Any->VERSION( '0.05' ) and
      Metrics::Any->import( '$METRICS', name_prefix => [ 'slurm' ] );
};

my %PKTTYPE_NAME;

if( defined $METRICS ) {
   $METRICS->make_counter( discards =>
      description => "Number of received packets discarded due to CRC check",
   );

   $METRICS->make_counter( packets =>
      description => "Number of packets sent and received, by type",
      labels => [qw( dir type )],
   );

   $METRICS->make_distribution( request_success_attempts =>
      description => "How many requests eventually succeeded after a given number of transmissions",
      units => "",
      buckets => [ 1 .. 3 ],
   );

   $METRICS->make_timer( request_duration =>
      description => "How long it took to get a response to each request",
      buckets => [ 0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5 ],
   );

   $METRICS->make_counter( retransmits =>
      description => "Number of retransmits of packets",
   );

   $METRICS->make_counter( serial_bytes =>
      description => "Total number of bytes sent and received on the serial link",
      labels => [qw( dir )],
   );

   $METRICS->make_counter( timeouts =>
      description => "Number of transactions that were abandoned due to eventual timeout",
   );

   %PKTTYPE_NAME = map { __PACKAGE__->can( "SLURM_PKTCTRL_$_" )->() => $_ }
      qw( META NOTIFY REQUEST RESPONSE ERR ACK );

   # Keep prometheus increase() happy by initialising all the counters to zero
   $METRICS->inc_counter_by( discards => 0 );
   foreach my $dir (qw( rx tx )) {
      $METRICS->inc_counter_by( packets => 0, [ dir => $dir, type => $_ ] ) for values %PKTTYPE_NAME;
      $METRICS->inc_counter_by( serial_bytes => 0, [ dir => $dir ] );
   }
   $METRICS->inc_counter_by( retransmits => 0 );
   $METRICS->inc_counter_by( timeouts => 0 );
}

field $_multidrop :param :inheritable = 0;

# To calculate baud-independent timeout values we need a rough estimate of the
# time to send each byte
field $_bps :reader :inheritable;

method new :common ( %params )
{
   my $transport = $params{transport} //
      ( defined $params{dev} ? "serial" :
        defined $params{host} ? "udp" : 
        defined $params{fh} ? "serial" :
      croak "Require either a 'dev', 'host', or 'fh'  parameter" );

   if( $transport eq "serial" ) {
      return Device::Serial::SLuRM::Protocol::_Serial->new(
         %params{qw( fh dev baud multidrop )}
      );
   }
   elsif( $transport eq "udp" ) {
      return Device::Serial::SLuRM::Protocol::_Udp->new(
         %params{qw( fh host port multidrop )}
      );
   }
   else {
      croak "Unrecognised 'transport' type $transport";
   }
}

async method recv
{
   my ( $pktctrl, $addr, $payload ) = await $self->recv_packet();

   printf STDERR "SLuRM <-RX%s {%02X/%v02X}\n",
      ( $_multidrop ? sprintf "(%d)", $addr : "" ), $pktctrl, $payload
         if DEBUG > 1;

   $METRICS and
      $METRICS->inc_counter( packets => [ dir => "rx", type => $PKTTYPE_NAME{ $pktctrl & 0xF0 } // "UNKNOWN" ] );

   return $pktctrl, $addr, $payload;
}

async method send ( $pktctrl, $addr, $payload, :$linestuff = false )
{
   printf STDERR "SLuRM TX%s-> {%02X/%v02X}\n",
      ( $_multidrop ? sprintf "(%d)", $addr & 0x7F : "" ), $pktctrl, $payload
         if DEBUG > 1;

   $METRICS and
      $METRICS->inc_counter( packets => [ dir => "tx", type => $PKTTYPE_NAME{ $pktctrl & 0xF0 } // "UNKNOWN" ] );

   return await $self->send_packet( $pktctrl, $addr, $payload, linestuff => $linestuff );
}

async method interpacket_delay ()
{
   # wait 20-ish byte times as a gap between packets
   await Future::IO->sleep( 20 / $_bps );
}

async method send_twice ( $pktctrl, $node_id, $payload )
{
   await $self->send( $pktctrl, $node_id, $payload );

   await $self->interpacket_delay;

   await $self->send( $pktctrl, $node_id, $payload );
}

class Device::Serial::SLuRM::Protocol::_Serial
{
   inherit Device::Serial::SLuRM::Protocol qw( $_bps $_multidrop );

   use constant DEBUG => Device::Serial::SLuRM::Protocol::DEBUG;
   use constant false => !!0;

   use Carp;
   use Digest::CRC qw( crc8 );

   field $_fh;

   ADJUST :params (
      :$fh = undef,
      :$dev = undef,
      :$baud //= 115200,
   ) {
      if( defined $fh ) {
         $_bps = $baud / 10;
      }
      elsif( defined $dev ) {
         require IO::Termios;

         $fh = IO::Termios->open( $dev, "$baud,8,n,1" ) or
            croak "Cannot open device $dev - $!";

         $fh->cfmakeraw;

         $_bps = $fh->getobaud / 10;
      }
      else {
         croak "Serial transport protocol requires fh or dev";
      }

      $_fh = $fh;
   }

   field $_recv_buffer;
   field @_linestuff_queue;

   async method _drain1_linestuff ()
   {
      my $bytes = shift @_linestuff_queue;

      my ( $pktctrl ) = unpack "C", $bytes;

      $METRICS and
         $METRICS->inc_counter_by( serial_bytes => 1 + length $bytes, [ dir => "tx" ] );

      printf STDERR "SLuRM DEV WRITE: %v02X\n", "\x55" . $bytes
         if DEBUG > 2;

      await Future::IO->syswrite_exactly( $_fh, "\x55" . $bytes );
   }

   async method recv_packet ()
   {
      $_recv_buffer //= Future::Buffer->new(
         fill => sub {
            my $f = Future::IO->sysread( $_fh, 8192 );
            $f->on_done( sub { $METRICS->inc_counter_by( serial_bytes => length $_[0], [ dir => "rx" ] ) } )
               if $METRICS;
            $f->on_done( sub { printf STDERR "SLuRM SERIAL READ: %v02X\n", $_[0] } )
               if DEBUG > 2;
            $f;
         },
      );

      my $headerlen = 3 + !!$_multidrop;

      PACKET: {
         # await start-of-frame while line-stuffing
         while(1) {
            my $f = $_recv_buffer->read_until( qr/\x55/ );
            if( @_linestuff_queue ) {
               $f = Future->wait_any( $f,
                  $self->interpacket_delay->then_done( "" ),
               );
            }

            last if length await $f;

            await $self->_drain1_linestuff;
         }

         defined( my $pkt = await $_recv_buffer->read_exactly( $headerlen ) )
            or return; # EOF

         my ( $pktctrl, $addr, $len );
         $_multidrop ? ( ( $pktctrl, $addr, $len ) = unpack "C C C", $pkt )
                     : ( ( $addr, $pktctrl, $len ) = ( 0, unpack "C C", $pkt ) );

         if( crc8( $pkt ) != 0 ) {
            # Header checksum failed
            $METRICS and
               $METRICS->inc_counter( discards => );

            $pkt =~ m/\x55/ and
               $_recv_buffer->unread( substr $pkt, $-[0] );
            redo PACKET;
         }

         $pkt .= await $_recv_buffer->read_exactly( $len + 1 );

         if( crc8( $pkt ) != 0 ) {
            # Body checksum failed
            $METRICS and
               $METRICS->inc_counter( discards => );

            $pkt =~ m/\x55/ and
               $_recv_buffer->unread( substr $pkt, $-[0] );
            redo PACKET;
         }

         my $body = substr( $pkt, $headerlen, $len );

         return ( $pktctrl, $addr, $body );
      }
   }

   async method send_packet ( $pktctrl, $addr, $body, :$linestuff = false )
   {
      my $bytes = $_multidrop
         ? pack( "C C C", $pktctrl, $addr // die( "ADDR must be defined for multidrop" ), length $body )
         : pack( "C C", $pktctrl, length $body );
      $bytes .= pack( "C", crc8( $bytes ) );

      $bytes .= $body;
      $bytes .= pack( "C", crc8( $bytes ) );

      if( $linestuff ) {
         push @_linestuff_queue, $bytes;
         return;
      }

      $METRICS and
         $METRICS->inc_counter_by( serial_bytes => 1 + length $bytes, [ dir => "tx" ] );

      printf STDERR "SLuRM SERIAL WRITE: %v02X\n", "\x55" . $bytes
         if DEBUG > 2;

      return await Future::IO->syswrite_exactly( $_fh, "\x55" . $bytes );
   }
}

class Device::Serial::SLuRM::Protocol::_Udp
{
   inherit Device::Serial::SLuRM::Protocol qw( $_bps $_multidrop );

   use constant DEBUG => Device::Serial::SLuRM::Protocol::DEBUG;
   use constant false => !!0;

   use Carp;
   use Digest::CRC qw( crc8 );

   use IO::Socket::IP;

   field $_sock;
   ADJUST :params ( :$fh = undef, :$host, :$port )
   {
      $_multidrop or croak "Cannot use UDP transport if not in multidrop mode";

      # UDP doesn't really define this; lets make it a really low generous
      # value to account for network delays
      $_bps = 2400;

      $_sock = $fh // IO::Socket::IP->new(
         Type     => Socket::SOCK_DGRAM,
         #Proto    => 'udp',
         PeerHost => $host,
         PeerPort => $port,
      ) or die "Cannot create UDP socket - $@";
   }

   async method recv_packet ()
   {
      PACKET: {
         my $pkt = await Future::IO->recv( $_sock, 512 );

         printf STDERR "SLuRM UDP RECV: %v02X\n", $pkt
            if DEBUG > 2;

         length $pkt >= 12 or redo PACKET;

         my ( $signature, $ver_maj, $ver_min, $op ) = unpack( "a8 C C S>",
            substr( $pkt, 0, 12, "" ) );

         if( $signature ne "udpSLuRM" or $ver_maj != 0 or $ver_min != 0 ) {
            warn "Bad signature or version number\n";
            redo PACKET;
         }

         if( $op == 0x0001 ) {
            # Because of how the CRCs work, the first 4 bytes and also the
            # entire packet body should come to zero
            if( crc8( substr( $pkt, 0, 4 ) ) != 0 ) {
               $METRICS and
                  $METRICS->inc_counter( discards => );
               redo PACKET;
            }

            my ( $pktctrl, $addr, $len ) = unpack( "C C C", $pkt );
            if( crc8( substr( $pkt, 0, 4 + $len + 1 ) ) != 0 ) {
               $METRICS and
                  $METRICS->inc_counter( discards => );
               redo PACKET;
            }

            my $body = substr $pkt, 4, $len;

            return ( $pktctrl, $addr, $body );
         }
         else {
            warn "Bad opcode\n";
            redo PACKET;
         }
      }
   }

   async method send_packet ( $pktctrl, $addr, $body, :$linestuff = false )
   {
      # We currently ignore linestuffing, but maybe it will be a UDP flag?

      # SLuRM header
      my $pkt = pack( "C C C", $pktctrl, $addr, length $body );
      $pkt .= pack( "C", crc8( $pkt ) );

      $pkt .= $body;
      $pkt .= pack( "C", crc8( $pkt ) );

      # udpSLuRM packet header
      my $bytes = pack( "a8 C C S> a*",
         'udpSLuRM', 0, 0, 0x0001,
         $pkt );

      printf STDERR "SLuRM UDP SEND: %v02X\n", $bytes
         if DEBUG > 2;

      return await Future::IO->send( $_sock, $bytes );
   }
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;

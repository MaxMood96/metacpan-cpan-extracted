package AnyEvent::Pcap;
use strict;
use warnings;
use Carp;
use AnyEvent;
use AnyEvent::Pcap::Utils;
use Net::Pcap;
use base qw(Class::Accessor::Fast);

our $VERSION = '0.00005';

__PACKAGE__->mk_accessors($_) for qw(utils device filter packet_handler fd timeout);

# be compatible with old versions of Net::Pcap
if ($Net::Pcap::VERSION < 0.15) {
    *Net::Pcap::pcap_lookupdev      = \&Net::Pcap::lookupdev;
    *Net::Pcap::pcap_open_live      = \&Net::Pcap::open_live;
    *Net::Pcap::pcap_open_offline   = \&Net::Pcap::open_offline;
    *Net::Pcap::pcap_file           = \&Net::Pcap::file;
}

sub new {
    my $class = shift;
    my $self = bless {@_}, $class;
    $self->utils( AnyEvent::Pcap::Utils->new );
    return $self;
}

sub _setup_pcap {
    my $self = shift;

    my $err;
    my $device = $self->device || sub {
        $self->device( Net::Pcap::pcap_lookupdev( \$err ) );
      }
      ->();
    croak $err if $err;

    my $pcap;
    my $timeout = $self->timeout || 0;
    my $netmask = 0;

    if ($device =~ s/^file://) {
        # open the file
        $pcap = Net::Pcap::pcap_open_offline( $device, \$err );
        croak $err if $err;

        # get its file descriptor
        my $fd = Net::Pcap::pcap_file($pcap);
        $self->fd($fd);
    } else {
        # open the device
        $pcap = Net::Pcap::pcap_open_live( $device, 1024, 1, $timeout, \$err );
        croak $err if $err;

        # get its file descriptor
        my $fd = Net::Pcap::fileno($pcap);
        $self->fd($fd);

        # get the associated network mask
        Net::Pcap::lookupnet( $device, \my $address, \$netmask, \$err );
        croak $err if $err;
    }

    my $filter;
    my $filter_string = $self->filter || sub {
        $self->filter("");
      }
      ->();

    Net::Pcap::compile( $pcap, \$filter, $filter_string, 0, $netmask );
    Net::Pcap::setfilter( $pcap, $filter );

    return $pcap;
}

sub run {
    my $self = shift;

    my $pcap = $self->_setup_pcap();

    my $packet_handler = $self->packet_handler || sub {
        $self->packet_handler( sub { } );
      }
      ->();

    my $io;
    $io = AnyEvent->io(
        fh   => $self->fd,
        poll => 'r',
        cb   => sub {
            my @pending;
            Net::Pcap::dispatch(
                $pcap, -1,
                sub {
                    my $header = $_[1];
                    my $packet = $_[2];
                    push @{ $_[0] }, ( $header, $packet );
                },
                \@pending
            );
            $packet_handler->( @pending, $io );
        }
    );
}

1;
__END__

=encoding utf-8

=head1 NAME

AnyEvent::Pcap - Net::Pcap wrapper with AnyEvent

=head1 SYNOPSIS

  use AnyEvent::Pcap;

  my $a_pcap;
  $a_pcap = AnyEvent::Pcap->new(
      device         => "eth0",
      filter         => "tcp port 80",
      timeout        => 1000,
      packet_handler => sub {
          my $io     = pop;
          while (@_) {
              my $header = shift;
              my $packet = shift;
  
              # you can use utils to get an NetPacket::TCP object.
              my $tcp = $a_pcap->utils->extract_tcp_packet($packet);

              # or ...
              $tcp = AnyEvent::Pcap::Utils->extract_tcp_packet($packet); 

              # do something....
          }
      }
  );
  
  $a_pcap->run();
  
  AnyEvent->condvar->recv;

=head1 DESCRIPTION

AnyEvent::Pcap is a Net::Pcap wrapper on top of AnyEvent.

Also you can use its utils to get NetPacket::IP or NetPacket::TCP object.

=head1 METHODS

=over 4

=item new(I<[%args]>);

  my %args = (
  
      # Default device is selected with Net::Pcap::pcap_lookupdev()
      device => "eth0",

      # It also could be "file:/path/to/file" to load a saved dump
      device => "file:samples/ping-ietf-20pk-le.dmp",
  
      # Default filter is NULL
      filter => "tcp port 80",
  
      # How much milliseconds to wait before flushing pcap buffer
      # Default is 0 (unlimited)
      timeout => 1000,
  
      # Reference to your callback
      packet_handler => sub {
          # The last item is AE::io handler
          my $io     = pop;

          # Other items are pairs of ($header, $packet)
          while (@_) {
              my $header = shift;
              my $packet = shift;
              ...
          }
      }
  );
  
  my $a_pcap = AnyEvent::Pcap->new(%args);

Create and return new AnyEvent::Pcap object.

=item utils()

  my $a_pcap = AnyEvent::Pcap->new;
  my $utils  = $a_pcap->utils;
    
You can get a utilty for packet handling. See L<AnyEvent::Pcap::Utils>.

=item run()

  my $a_pcap = AnyEvent::Pcap->new(%args);
  $a_pcap->run;

  AnyEvent->condvar->recv;

Running AnyEvent loop.

=back

=head2 accessor methods

=over 4

=item device(I<[STRING]>)

=item fiilter(I<[STRING]>)

=item packet_handler(I<[CODEREF]>)

=item timeout(I<[INTEGER]>)

=back

=head1 AUTHOR

Takeshi Miki E<lt>miki@cpan.orgE<gt>

=head1 CONTRIBUTORS

Sébastien Aperghis-Tramoni C<< <sebastien at aperghis.net> >>

Sergei Zhmylev E<lt>zhmylove@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent> L<Net::Pcap>

=cut

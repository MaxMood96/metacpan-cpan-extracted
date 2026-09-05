package Linux::Event::IO::Sock::Dgram;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

use parent 'Linux::Event::_Socket::Dgram';

1;

__END__

=head1 NAME

Linux::Event::IO::Sock::Dgram - asynchronous Linux C<SOCK_DGRAM> I/O

=head1 SYNOPSIS

  package EchoDgram;
  use parent 'Linux::Event::IO::Sock::Dgram';

  sub on_datagram ($socket, $payload, $peer) {
      $socket->send($payload, to => $peer);
  }

  package main;
  my $server = $loop->add(EchoDgram->new(
      host => '127.0.0.1',
      port => 9999,
  ));

=head1 DESCRIPTION

C<Linux::Event::IO::Sock::Dgram> is the public class for Linux C<SOCK_DGRAM>
sockets. It preserves kernel packet boundaries and peer addresses rather than
forcing datagrams through the ordered-byte framing engine.

UDP over IPv4 or IPv6 and Unix-domain datagram sockets use the same class;
address family is constructor policy rather than a public type hierarchy.

=head1 BOUND AND CONNECTED FORMS

C<new> creates or adopts an unconnected packet socket. For UDP:

  my $server = EchoDgram->new(
      host => '0.0.0.0',
      port => 9999,
  );

C<connect> installs a default peer:

  my $client = EchoDgram->connect(
      host => 'collector.example.com',
      port => 9000,
  );

Hostnames for connected UDP are resolved asynchronously. Numeric Internet
addresses and Unix paths bypass resolution. Unix-domain sockets use C<unix> for
the bound or peer path and may use C<local_unix> for a connected client's local
reply path.

An adopted C<fh> must be an IPv4, IPv6, or Unix datagram socket. Created handles
are owned by the object; adopted handles remain caller-owned unless
C<owns_socket> is true.

C<loop =E<gt> $loop> attaches immediately. Detached objects may be added later
with C<< $loop->add($socket) >>.

=head1 CALLBACKS

A concrete subclass defines:

  sub on_datagram ($socket, $payload, $peer) { ... }

Each callback represents exactly one kernel datagram. C<$peer> is a lazy
L<Linux::Event::Address>. Zero-length datagrams are valid.

Optional C<on_ready>, C<on_drain>, C<on_error>, and C<on_close> callbacks cover
lifecycle and output flow control. Datagram I/O errors and queue-limit errors do
not automatically invent byte-stream EOF semantics.

=head1 SENDING

For a connected socket:

  $socket->send($payload);

For an unconnected socket:

  $socket->send($payload, to => $peer);

One C<send> call is one packet. If output would block, the complete datagram is
queued and retried atomically. High/low byte watermarks provide cooperative
backpressure. C<max_pending_bytes> and C<max_pending_datagrams> provide hard
queue bounds without splitting an accepted packet.

=head1 INPUT LIMITS AND FAIRNESS

C<max_datagram_size> bounds accepted packet size. Native C<recvmsg> uses
C<MSG_TRUNC> so an oversized packet can be rejected whole instead of delivering
a misleading prefix. C<max_datagrams_per_tick> bounds level-triggered receive
work for fairness; zero drains to C<EAGAIN> and is required for edge-triggered
operation.

=head1 SOCKET POLICY

C<datagram_options> caches packet limits, watermarks, fairness, and common socket
policy per subclass. Internet sockets support options such as C<reuseaddr>,
C<reuseport>, C<broadcast>, optional C<v6only>, C<bind_device>, and socket
buffers where applicable. Unix sockets support path ownership and permissions.
Constructor values override class policy for one object.

=head1 METHODS AND LIFECYCLE

C<local> and C<peer> expose lazy address values where meaningful.
C<is_connected>, C<state>, C<pending_bytes>, and related queue accessors expose
current state.

C<close> terminates the object and releases owned socket/path resources.
C<detach> returns the still-open handle, suppresses Unix path removal, and is a
terminal ownership transfer.

=head1 SEE ALSO

L<Linux::Event::IO::Sock::Stream>, L<Linux::Event::Address>,
F<docs/DGRAM-DESIGN.md>, F<docs/SOCKET-CONFIGURATION.md>.

=cut

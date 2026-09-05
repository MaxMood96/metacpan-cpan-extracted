package Linux::Event::IO::Sock::Stream;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

use parent 'Linux::Event::_Socket::Stream';

1;

__END__

=head1 NAME

Linux::Event::IO::Sock::Stream - asynchronous Linux C<SOCK_STREAM> connections

=head1 SYNOPSIS

  package EchoConnection;
  use parent 'Linux::Event::IO::Sock::Stream';
  use Linux::Event::Framer 'Delimiter', "\n";

  sub on_ready ($stream) {
      $stream->send('hello');
  }

  sub on_message ($stream, $message) {
      say $message;
      $stream->close;
  }

  package main;
  my $connection = $loop->add(EchoConnection->connect(
      host => '127.0.0.1',
      port => 9999,
  ));

=head1 DESCRIPTION

C<Linux::Event::IO::Sock::Stream> is the public class for connected Linux
C<SOCK_STREAM> sockets. TCP over IPv4 or IPv6 and Unix-domain stream sockets
use the same class; address family is connection configuration rather than a
separate type hierarchy.

The class combines the common ordered-byte engine with socket acquisition,
addresses, socket policy, kernel half-close semantics, and optional TLS. A
concrete protocol subclass supplies named callbacks and, when appropriate, a
native framer.

=head1 OUTBOUND CONNECTIONS

C<connect> constructs one connection object whose identity is retained through
resolution, connection, optional TLS handshake, established I/O, and close:

  my $stream = Client->connect(
      loop    => $loop,          # optional immediate attachment
      host    => 'example.com',  # TCP remote host
      port    => 443,            # TCP remote port
      timeout => 10,             # connection deadline; default 10
      data    => $state,         # optional application state
  );

Use C<unix =E<gt> $path> for a filesystem Unix-domain stream socket. Advanced
callers may supply a packed C<sockaddr> with its numeric C<family>.

C<loop> is optional. Without it, C<connect> returns a detached object that may
later be passed to C<< $loop->add($stream) >>. Writes submitted before readiness
use the normal bounded output queue and are delivered in order after the
transport becomes usable.

Optional source-side controls include numeric C<local_host>, C<local_port>, and
C<bind_device>. Hostname resolution is asynchronous and uses the Loop's private
native resolver service.

=head1 ADOPTED CONNECTED SOCKETS

C<new(fh =E<gt> $socket)> adopts an already connected C<SOCK_STREAM> handle.
The handle is validated, made nonblocking and close-on-exec, and uses the same
established I/O path as an accepted or outbound connection. A TLS-declared
class must also specify C<tls_role> for an adopted handle because acquisition
cannot infer client versus server role.

=head1 CALLBACKS

C<on_ready($stream)> runs once when the connection is application-ready. For
TLS that means after handshake and verification, not merely after TCP connect.

A raw subclass defines C<on_data($stream, $bytes)>. A framed subclass uses
L<Linux::Event::Framer> and defines C<on_message> or, with explicit batching,
C<on_messages>.

Optional lifecycle callbacks include C<on_drain>, C<on_eof>, C<on_error>,
C<on_close>, and C<on_transport_ready> for transport-specific observation.
Callback methods and class policy are resolved into an immutable descriptor so
steady-state I/O does not perform method lookup.

=head1 FRAMING AND OUTPUT

C<write($bytes)> sends raw ordered bytes. C<send($payload)> applies the
subclass's native framer. The native write engine attempts immediate output,
queues only unsent bytes, enables writable readiness only while necessary, and
uses high/low watermarks plus optional C<max_pending_bytes> protection.

C<pause_read> and C<resume_read> control application reads. C<transition_to>
changes protocol callback/framing descriptors in place while retaining the live
socket, transport, output queue, and unread native input according to the
transition rules in F<docs/FRAMING.md>.

=head1 SOCKET POLICY

A subclass may define C<socket_options> for acquisition-time socket policy:

  sub socket_options ($class) {
      return (
          tcp_nodelay      => 1,
          keepalive        => 1,
          tcp_user_timeout => 15,
      );
  }

Supported policy includes TCP_NODELAY, keepalive tuning, TCP_USER_TIMEOUT,
send/receive buffers, and interface binding where applicable. Constructor
values override class policy for one connection. C<configure_socket> is an
optional cached cold-path hook for Linux options not covered by the built-ins.
See F<docs/SOCKET-CONFIGURATION.md>.

=head1 ORDERED-BYTE POLICY AND DEADLINES

C<stream_options> configures read size and fairness, batching, input/output
limits, watermarks, and established C<idle_timeout>, C<read_timeout>, and
C<write_timeout>. One explicit operation C<deadline> may also be set or changed
at runtime. These policies begin when the application transport is usable; DNS,
connect, TLS handshake, and TLS shutdown retain their own lifecycle deadlines.

=head1 TLS

A stream-socket subclass opts into TLS declaratively:

  package SecureClient;
  use parent 'Linux::Event::IO::Sock::Stream';
  use Linux::Event::TLS
      verify => 1,
      alpn   => ['http/1.1'];

Outbound C<connect> selects client mode and derives the default server name from
C<host>. A listener that accepts a TLS-declared class selects server mode; that
class must declare C<cert_file> and C<key_file>. Framing and callbacks receive
plaintext. See L<Linux::Event::TLS>.

=head1 ADDRESSES AND LIFECYCLE

C<local> and C<peer> return lazy L<Linux::Event::Address> values when available.
C<fd>, C<fh>, C<state>, C<pending_bytes>, and C<last_error> expose connection
state without changing ownership.

C<end> drains accepted output then performs the transport's writable half-close.
C<close> is immediate and terminal. C<detach> transfers a plain connected socket
only when no output is pending; encrypted transports cannot be detached safely.

=head1 SEE ALSO

L<Linux::Event::IO::Sock::Listener>, L<Linux::Event::IO::Sock::Dgram>,
L<Linux::Event::Framer>, L<Linux::Event::TLS>,
F<docs/SOCKET-CONNECTIONS.md>, F<docs/ORDERED-BYTE-IO-DESIGN.md>.

=cut

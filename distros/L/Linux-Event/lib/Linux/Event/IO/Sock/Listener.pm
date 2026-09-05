package Linux::Event::IO::Sock::Listener;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

use parent 'Linux::Event::_Socket::Listener';
use Carp qw(croak);

sub new ($class, %option) {
    if (exists $option{stream_class}) {
        my $stream_class = $option{stream_class};
        croak 'new(): stream_class must name a Linux::Event::IO::Sock::Stream subclass'
            if ref($stream_class)
            || !$stream_class->isa('Linux::Event::IO::Sock::Stream');
    }
    return $class->SUPER::new(%option);
}

1;

__END__

=head1 NAME

Linux::Event::IO::Sock::Listener - asynchronous listening C<SOCK_STREAM> socket

=head1 SYNOPSIS

  package ServerConnection;
  use parent 'Linux::Event::IO::Sock::Stream';

  sub on_data ($stream, $bytes) {
      $stream->write($bytes);
  }

  package ServerListener;
  use parent 'Linux::Event::IO::Sock::Listener';

  sub on_accept ($listener, $stream) {
      $listener->data->{connections}{ $stream->fd } = $stream;
  }

  package main;
  my $listener = $loop->add(ServerListener->new(
      stream_class => 'ServerConnection',
      host         => '0.0.0.0',
      port         => 9999,
      data         => { connections => {} },
  ));

=head1 DESCRIPTION

C<Linux::Event::IO::Sock::Listener> owns a listening Linux C<SOCK_STREAM>
socket and constructs the configured L<Linux::Event::IO::Sock::Stream>
subclass for every accepted connection. It is a separate public object because
bind/listen/accept lifecycle is different from connected byte-stream I/O.

TCP and Unix-domain listeners share this class. Socket family is selected by
constructor options, not by subclass hierarchy.

=head1 CONSTRUCTION

C<stream_class> is required and names the stream-socket subclass created for
each accepted connection. Exactly one listener source is selected:

  Listener->new(
      stream_class => 'ServerConnection',
      host         => '0.0.0.0',
      port         => 9999,
  );

  Listener->new(
      stream_class => 'ServerConnection',
      unix         => '/run/example.sock',
  );

  Listener->new(
      stream_class => 'ServerConnection',
      fh           => $existing_listener,
  );

C<loop =E<gt> $loop> attaches immediately; otherwise add the detached object
with C<< $loop->add($listener) >>. Listener C<data> is supplied to each accepted
connection as its initial C<data> value.

TCP listener policy includes C<backlog>, C<reuseaddr>, C<reuseport>, optional
C<v6only>, and C<bind_device>. Unix listeners support path ownership controls
including C<unlink>, C<unlink_on_close>, and C<permissions>. Adopted handles
default to caller ownership unless C<owns_socket> is true.

=head1 ACCEPTANCE

Native code drains C<accept4> with nonblocking and close-on-exec flags.
C<max_accept_per_tick> bounds level-triggered acceptance for fairness; zero
drains until C<EAGAIN> and is required with edge-triggered operation.

For each accepted socket Linux::Event constructs C<stream_class>, attaches it to
the same Loop, then invokes optional C<on_accept($listener, $stream)>.
A plain stream's C<on_ready> follows. For TLS, C<on_accept> still observes the
new connection immediately after attachment while C<on_ready> waits for the TLS
handshake and verification to complete.

An C<on_accept> exception closes only that accepted connection and is reported
as a callback error; it does not silently kill the listener.

=head1 TLS

TLS policy belongs to the accepted stream-socket class, not the listener. A
server class declares L<Linux::Event::TLS> with C<cert_file> and C<key_file>.
Listener validates that server policy during construction and creates fresh TLS
state for every accepted connection.

=head1 METHODS AND LIFECYCLE

C<port> reports the bound TCP port, including the kernel-selected value after
C<port =E<gt> 0>. C<family>, C<family_number>, C<is_tcp>, and C<is_unix>
identify the listening socket family.

C<pause> and C<resume> control acceptance while retaining the listening socket.
C<close> ends ownership. C<detach> returns the still-open listening handle and
is terminal. C<state> reports listener lifecycle such as C<unattached>,
C<listening>, C<paused>, C<closed>, C<failed>, or C<detached>.

Runtime errors are L<Linux::Event::Error> values. Resource exhaustion pauses
acceptance before error delivery to prevent a readable-backlog error spin. A
subclass may define C<on_error($listener, $error)> to implement application
policy.

=head1 SEE ALSO

L<Linux::Event::IO::Sock::Stream>, L<Linux::Event::TLS>,
F<docs/LISTENER-DESIGN.md>, F<docs/SOCKET-CONFIGURATION.md>.

=cut

package Linux::Event::Listener;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.102';

use Carp qw(croak);
use Scalar::Util qw(blessed);
use Linux::Event::Error;
use parent 'Linux::Event::Listener::_Engine';

sub new ($class, %opt) {
    my $loop = delete $opt{loop};
    croak 'new(): loop must be an object implementing add() and watch()'
        if defined($loop) && (!ref($loop) || !$loop->can('add')
            || !$loop->can('watch'));
    my $stream_class = delete $opt{stream_class}
        // croak 'new(): missing stream_class';
    croak 'new(): stream_class must name a Linux::Event::Stream subclass'
        if ref($stream_class) || !$stream_class->isa('Linux::Event::Stream');
    $stream_class->_validate_accepted_configuration;

    my $self = $class->SUPER::new(%opt);
    $self->{stream_class} = $stream_class;
    $self->_attach_to_loop($loop) if $loop;
    return $self;
}

sub stream_class ($self) { $self->{stream_class} }

sub _accept_client ($self, $fh, $peer) {
    my $class = $self->{stream_class};
    my $stream;
    my $prepared = eval {
        $stream = $class->new(
            fh        => $fh,
            peer      => $peer,
            data      => $self->data,
            _accepted => 1,
        );
        $stream->_attach_to_loop($self->loop);
        1;
    };
    if (!$prepared) {
        my $failure = $@;
        eval { $stream->close; 1 } if $stream;
        my $error = blessed($failure)
            && $failure->isa('Linux::Event::Error')
            ? $failure
            : Linux::Event::Error->new(
                type      => 'setup',
                operation => 'accepted_stream',
                message   => "$failure" || 'accepted Stream setup failed',
                fatal     => 0,
                host      => $self->host,
                port      => $self->port,
                family    => $self->family,
            );
        $self->{last_error} = $error;
        $self->{descriptor}{on_error}->($self, $error);
        return;
    }
    if (my $callback = $self->{descriptor}{on_accept}) {
        my $ok = eval { $callback->($self, $stream); 1 };
        if (!$ok) {
            my $message = "$@";
            $message =~ s/\s+\z//;
            $message = 'on_accept callback failed' if $message eq '';
            eval { $stream->close; 1 };
            my $error = Linux::Event::Error->new(
                type      => 'callback',
                operation => 'on_accept',
                message   => $message,
                fatal     => 0,
                host      => $self->host,
                port      => $self->port,
                path      => $self->path,
                family    => $self->family,
            );
            $self->{last_error} = $error;
            $self->{descriptor}{on_error}->($self, $error);
            return;
        }
    }
    $stream->_fire_ready if !$stream->transport;
    return;
}

sub on_error ($self, $error) {
    die "listener failed: $error\n";
}

sub CLONE_SKIP ($class) { 1 }

1;

__END__

=head1 NAME

Linux::Event::Listener - accepting socket that constructs Stream instances

=head1 SYNOPSIS

  use Linux::Event::Listener;
  use Linux::Event::Loop;

  package EchoStream;
  use parent 'Linux::Event::Stream';

  sub on_data ($stream, $bytes) {
      $stream->write($bytes);
  }

  package EchoListener;
  use parent 'Linux::Event::Listener';

  sub on_accept ($listener, $stream) {
      say "accepted " . $stream->peer->host;
  }

  package main;
  my $loop = Linux::Event::Loop->new;
  my $listener = EchoListener->new(
      loop                => $loop,         # optional: attach immediately
      stream_class        => 'EchoStream',  # required
      host                => '0.0.0.0',     # required for TCP
      port                => 7000,          # required for TCP
      backlog             => 4096,          # default
      max_accept_per_tick => 256,           # default
      edge_triggered      => 0,             # default
  );
  $loop->run;

=head1 DESCRIPTION

Listener creates or adopts a listening TCP or Unix stream socket, drains
accepted connections with native C<accept4>, constructs the configured Stream
subclass for every accepted connection, and attaches each Stream to the same
Loop. Application code never handles accepted descriptors directly.

Every accepted Stream receives the Listener's C<data> value. Stream-level
buffer, deadline, framing, and TLS policy comes from the Stream subclass's
cached declarations.

=head1 CONSTRUCTION

Construct Listener directly and name the Stream subclass that it should create
for accepted connections.

Every Listener can be attached in either form:

  my $listener = Linux::Event::Listener->new(
      loop         => $loop,          # optional: attach immediately
      stream_class => 'ServerStream', # required
      host         => '127.0.0.1',    # required for TCP
      port         => 9000,           # required for TCP
      reuseaddr    => 1,              # default
  );

  my $listener = Linux::Event::Listener->new(
      stream_class => 'ServerStream',  # required
      unix         => '/run/app.sock', # required for Unix
      unlink       => 1,               # optional; default 0
      permissions  => 0660,            # optional
  );
  $loop->add($listener);

C<< $loop->add >> sets C<loop>, starts accepting, and returns the same Listener.
A Listener may be attached only once and to only one Loop.

=head1 SOCKET SOURCES

Exactly one of these sources is required:

=over 4

=item * C<host =E<gt> $host, port =E<gt> $port>

Creates a TCP listener. C<$host> may be an address, hostname, or C<*> for a
passive wildcard bind. C<port =E<gt> 0> asks the kernel to choose a port;
C<port()> then returns the assigned value.

=item * C<unix =E<gt> $path>

Creates a filesystem Unix stream listener.

=item * C<fh =E<gt> $listening_socket>

Adopts an existing listening socket. Listener sets nonblocking and
close-on-exec flags. It does not close the handle by default; pass
C<owns_socket =E<gt> 1> to transfer ownership.

=back

=head1 OPTIONS

Common options, shown with their actual defaults, are:

  my $listener = Linux::Event::Listener->new(
      stream_class        => 'ServerStream', # required
      host                => '0.0.0.0',      # required for TCP
      port                => 9000,           # required for TCP
      loop                => $loop,          # optional
      data                => $server_state,  # optional
      backlog             => 4096,           # default
      max_accept_per_tick => 256,            # default
      edge_triggered      => 0,              # default
  );

C<max_accept_per_tick> bounds accepts per level-triggered dispatch. Zero drains
until C<EAGAIN>. C<edge_triggered =E<gt> 1> requires that zero/unbounded
setting.

TCP socket options are:

  my $listener = Linux::Event::Listener->new(
      stream_class => 'ServerStream', # required
      host         => '::',           # required for TCP
      port         => 9000,           # required for TCP
      reuseaddr    => 1,              # default
      reuseport    => 0,              # default
      v6only       => 1,              # optional; kernel default if omitted
      bind_device  => 'eth0',         # optional
  );

Unix socket options are:

  my $listener = Linux::Event::Listener->new(
      stream_class    => 'ServerStream',  # required
      unix            => '/run/app.sock', # required for Unix
      unlink          => 0,               # default
      unlink_on_close => 1,               # default
      permissions     => 0660,            # optional
  );

Adopted-socket options are:

  my $listener = Linux::Event::Listener->new(
      stream_class => 'ServerStream', # required
      fh           => $socket,        # required for adoption
      owns_socket  => 0,              # default
  );

Source-specific options are rejected for other source types.
C<bind_device> applies Linux C<SO_BINDTODEVICE> before a created TCP socket is
bound. It is also accepted for an adopted Internet listener. The process must
have the privilege required by the kernel; failure throws a structured
C<socket_configuration> Error naming C<bind_device>.

=head1 ACCEPTED STREAMS

Listener uses native C<accept4> with C<SOCK_NONBLOCK> and C<SOCK_CLOEXEC>.
For every success it constructs C<stream_class> with C<fh> and a lazy
L<Linux::Event::Address> C<peer>, passes it this Listener's C<data>, attaches
the Stream to this Listener's Loop, calls the optional Listener C<on_accept>,
and then fires C<on_ready> for a plain Stream. C<on_accept> may replace the
Stream's C<data> when connection-specific state is needed.

A Stream subclass declares TLS directly:

  package SecureStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::TLS
      cert_file         => '/etc/linux-event/server-cert.pem', # required
      key_file          => '/etc/linux-event/server-key.pem',  # required
      alpn              => ['echo/1'],                         # optional
      handshake_timeout => 10,                                 # default
      shutdown_timeout  => 5;                                  # default

  sub on_data ($stream, $bytes) {
      $stream->write($bytes);
  }

Naming C<SecureStream> as C<stream_class> makes every accepted connection use
server TLS automatically. Listener loads and validates the declared server
identity during construction. The TLS handshake begins after attachment and
C<on_ready> does not fire until it succeeds.

=head1 CALLBACKS

=head2 on_accept

A Listener subclass may define this optional callback:

  sub on_accept ($listener, $stream) {
      $listener->data->{connections}{ $stream->fd } = $stream;
  }

It receives the fully constructed Stream after attachment to the Listener's
Loop. It runs before a plain Stream's C<on_ready> and before a TLS Stream has
completed its handshake. Use it for connection accounting, association with
server state, initial policy, or immediate rejection with C<< $stream->close >>.

An exception closes that accepted Stream, suppresses its pending C<on_ready>,
and delivers a nonfatal C<callback> Error with operation C<on_accept> to the
Listener's C<on_error>. The listening socket remains active when C<on_error>
handles the error.

=head2 on_error

Listener subclasses may override C<on_error($listener, $error)> to implement
runtime error policy. The base implementation dies. Resource-exhaustion errors
pause acceptance before C<on_error> runs; call C<resume> after the application
has restored descriptor or memory capacity.

=head1 ERROR POLICY

Runtime failures are L<Linux::Event::Error> objects. Resource exhaustion pauses
acceptance before notification to prevent an error spin. The base Listener
dies after such a failure. Applications that need another policy may subclass
Listener and override C<on_error>:

  package MyListener;
  use parent 'Linux::Event::Listener';

  sub on_error ($listener, $error) {
      warn "$error\n";
  }

Constructor validation errors throw immediately, and socket-setup failures
throw a structured Error.

=head1 METHODS

=head2 pause / resume

Disable or re-enable acceptance without closing the listening socket. Both
return the Listener.

=head2 close

Stop accepting, remove native registration, close an owned handle, and remove
an owned Unix path when configured. A terminal Listener releases its Loop.

=head2 detach

Stop accepting and return the still-open listener handle, transferring
ownership to the caller. Returns undef after a terminal state.

=head2 loop / fh / fd / host / port / path

Return attachment and bound-socket information. C<loop> is undef before
attachment and after terminal cleanup. Fields that do not apply to the socket
family are undefined.

=head2 family / family_number / is_tcp / is_unix

C<family> returns C<inet>, C<inet6>, C<unix>, or C<unknown>.
C<family_number> returns the native numeric address-family constant.
C<is_tcp> is true for IPv4 and IPv6 listeners; C<is_unix> is true for Unix
listeners.

=head2 stream_class

Return the configured Stream subclass name.

=head2 state

Returns C<unattached>, C<listening>, C<paused>, C<closed>, C<failed>, or
C<detached>.

=head2 accepted / last_error / data

Return the cumulative accepted connection count, most recent runtime error,
and optional application value. C<data($new_value)> replaces the value.

=head2 is_paused / is_running / is_terminal

Convenience predicates for the current lifecycle state.

=head1 PERFORMANCE

The Listener class caches its resolved native callbacks. XS drains accept4 in
batches, while Perl is entered only for Stream construction and application
policy. Accepted sockets never receive a temporary public registration before
Stream attachment.

=cut

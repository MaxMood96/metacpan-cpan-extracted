package Linux::Event::TLS;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.111';

use Carp qw(croak);
use POSIX qw(isfinite);
use utf8 ();

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub CLONE_SKIP ($class) { 1 }

sub import ($class, @arg) {
    my $target = caller;
    require Linux::Event::IO::Sock::Stream;
    require Linux::Event::_Socket::Descriptor;

    my $base = $target->isa('Linux::Event::IO::Sock::Stream')
        ? 'Linux::Event::IO::Sock::Stream' : undef;

    return if $target eq 'main' && !defined($base) && !@arg;
    croak "$target must be a Linux::Event IO stream-socket subclass before declaring TLS"
        if !defined $base;
    croak 'TLS declaration options must be key/value pairs' if @arg % 2;

    Linux::Event::_Socket::Descriptor::declare_tls(
        $base,
        $target,
        $class->_build_declaration($target, @arg),
    );
    return;
}

sub _alpn_wire ($protocols) {
    return '' if !defined $protocols;
    croak 'alpn must be an array reference' if ref($protocols) ne 'ARRAY';
    my $wire = '';
    for my $protocol (@$protocols) {
        my $bytes = defined($protocol) && !ref($protocol)
            ? "$protocol" : undef;
        my $is_bytes = defined($bytes) && utf8::downgrade($bytes, 1);
        croak 'each ALPN protocol must be a byte string of 1..255 bytes'
            if !$is_bytes || length($bytes) < 1 || length($bytes) > 255;
        $wire .= pack('C', length($bytes)) . $bytes;
        croak 'the encoded ALPN protocol list must not exceed 65535 bytes'
            if length($wire) > 65_535;
    }
    return $wire;
}

sub _timeout ($method, $name, $value, $default) {
    $value = $default if !defined $value;
    my $where = $method =~ /\s/ ? $method : "$method()";
    croak "$where: $name must be a non-negative number of seconds"
        if ref($value)
        || $value !~ /\A(?:\d+(?:\.\d*)?|\.\d+)\z/
        || $value < 0;
    $value = 0 + $value;
    croak "$where: $name must be a finite number of seconds"
        if !isfinite($value);
    croak "$where: $name exceeds the supported timer range"
        if $value > 2_147_483_647;
    return $value;
}

sub _optional_string ($target, $name, $value) {
    return undef if !defined $value;
    croak "$target TLS $name must be a non-empty string without NUL bytes"
        if ref($value) || $value eq '' || $value =~ /\0/;
    return "$value";
}

sub _server_name ($target, $value) {
    my $server_name = _optional_string($target, 'server_name', $value);
    return undef if !defined $server_name;
    $server_name = substr($server_name, 1, length($server_name) - 2)
        if length($server_name) >= 2
        && substr($server_name, 0, 1) eq '['
        && substr($server_name, -1, 1) eq ']';
    croak "$target TLS server_name must not be empty after removing brackets"
        if $server_name eq '';
    return $server_name;
}

sub _build_declaration ($class, $target, @arg) {
    my %opt = @arg;
    my @known = qw(
        cert_file key_file server_name verify ca_file ca_path alpn
        handshake_timeout shutdown_timeout
    );
    my %known = map { $_ => 1 } @known;
    my @unknown = grep { !$known{$_} } keys %opt;
    croak "$target TLS declaration has unknown options: "
        . join(', ', sort @unknown) if @unknown;

    my $cert_file = _optional_string(
        $target, 'cert_file', delete $opt{cert_file},
    );
    my $key_file = _optional_string(
        $target, 'key_file', delete $opt{key_file},
    );
    croak "$target TLS declaration requires cert_file and key_file together"
        if defined($cert_file) != defined($key_file);
    my $server_name = _server_name($target, delete $opt{server_name});
    my $ca_file = _optional_string(
        $target, 'ca_file', delete $opt{ca_file},
    );
    my $ca_path = _optional_string(
        $target, 'ca_path', delete $opt{ca_path},
    );
    my $verify = exists($opt{verify}) ? delete($opt{verify}) : 1;
    croak "$target TLS verify must be 0 or 1"
        if ref($verify) || $verify !~ /\A[01]\z/;

    return {
        target            => $target,
        cert_file         => $cert_file,
        key_file          => $key_file,
        server_name       => $server_name,
        verify            => $verify ? 1 : 0,
        ca_file           => $ca_file,
        ca_path           => $ca_path,
        alpn_wire         => _alpn_wire(delete $opt{alpn}),
        handshake_timeout => _timeout(
            "$target TLS declaration", 'handshake_timeout',
            delete($opt{handshake_timeout}), 10,
        ),
        shutdown_timeout => _timeout(
            "$target TLS declaration", 'shutdown_timeout',
            delete($opt{shutdown_timeout}), 5,
        ),
    };
}

sub _validate_server_declaration ($class, $definition) {
    my $target = $definition->{target};
    croak "$target is used for accepted TLS stream sockets but does not declare "
        . 'cert_file and key_file'
        if !defined($definition->{cert_file});
    return;
}

sub _client_from_declaration ($class, $definition, $connect_host = undef) {
    my $target = $definition->{target};
    my $server_name = $definition->{server_name} // $connect_host;
    croak "$target TLS client requires server_name when connect() has no host"
        if !defined($server_name) || ref($server_name) || $server_name eq '';
    $server_name = _server_name($target, $server_name);
    return $class->_new_client(
        $server_name,
        $definition->{verify},
        $definition->{ca_file},
        $definition->{ca_path},
        $definition->{alpn_wire},
        $definition->{handshake_timeout},
        $definition->{shutdown_timeout},
    );
}

sub _server_from_declaration ($class, $definition) {
    $class->_validate_server_declaration($definition);
    return $class->_new_server(
        $definition->{cert_file},
        $definition->{key_file},
        $definition->{alpn_wire},
        $definition->{handshake_timeout},
        $definition->{shutdown_timeout},
    );
}

sub client ($class, %opt) {
    croak 'client(): must be called as a class method' if ref $class;
    my $server_name = delete $opt{server_name}
        // croak 'client(): missing server_name';
    my $verify = exists $opt{verify} ? delete($opt{verify}) : 1;
    croak 'client(): verify must be 0 or 1'
        if !defined($verify) || ref($verify) || $verify !~ /\A[01]\z/;
    $server_name = _server_name('client()', $server_name);
    my $ca_file = _optional_string(
        'client()', 'ca_file', delete $opt{ca_file},
    );
    my $ca_path = _optional_string(
        'client()', 'ca_path', delete $opt{ca_path},
    );
    my $alpn = _alpn_wire(delete $opt{alpn});
    my $handshake_timeout = _timeout(
        'client', 'handshake_timeout', delete($opt{handshake_timeout}), 10,
    );
    my $shutdown_timeout = _timeout(
        'client', 'shutdown_timeout', delete($opt{shutdown_timeout}), 5,
    );
    croak 'client(): unknown options: ' . join(', ', sort keys %opt) if %opt;
    return $class->_new_client(
        $server_name, $verify ? 1 : 0, $ca_file, $ca_path, $alpn,
        $handshake_timeout, $shutdown_timeout,
    );
}

sub server ($class, %opt) {
    croak 'server(): must be called as a class method' if ref $class;
    my $cert_file = delete $opt{cert_file}
        // croak 'server(): missing cert_file';
    my $key_file = delete $opt{key_file}
        // croak 'server(): missing key_file';
    $cert_file = _optional_string('server()', 'cert_file', $cert_file);
    $key_file = _optional_string('server()', 'key_file', $key_file);
    my $alpn = _alpn_wire(delete $opt{alpn});
    my $handshake_timeout = _timeout(
        'server', 'handshake_timeout', delete($opt{handshake_timeout}), 10,
    );
    my $shutdown_timeout = _timeout(
        'server', 'shutdown_timeout', delete($opt{shutdown_timeout}), 5,
    );
    croak 'server(): unknown options: ' . join(', ', sort keys %opt) if %opt;
    return $class->_new_server(
        $cert_file, $key_file, $alpn,
        $handshake_timeout, $shutdown_timeout,
    );
}

sub _stream_transport_bind ($self, $fd) {
    return $self->_bind_fd($fd);
}

sub _install_deadline ($self, $stream, $operation) {
    my $fd = $self->_arm_deadline($operation);
    return if !defined $fd;
    return if $stream->_has_transport_deadline_watcher;
    my $watcher = $stream->loop->watch(
        fd   => $fd,
        _internal => 1,
        data => {
            provider  => $self,
            stream    => $stream,
        },
        read => \&_deadline_ready,
    );
    $stream->_set_transport_deadline_watcher($watcher);
    return;
}

sub _deadline_ready ($watcher) {
    my $state = $watcher->data;
    my $stream = $state->{stream};
    my $operation = $state->{provider}->_deadline_operation;
    my $message = $state->{provider}->_consume_deadline(
        $operation,
    );
    $stream->_transport_deadline_expired(
        $operation, $message,
    );
    return;
}

sub _stream_transport_start ($self, $stream) {
    $self->_install_deadline($stream, 'handshake');
}

sub _stream_transport_ready ($self, $stream) {
    $stream->_clear_transport_deadline;
}

sub _stream_transport_begin_shutdown ($self, $stream) {
    $self->_install_deadline($stream, 'shutdown');
}

sub _stream_transport_cancel_deadline ($self) {
    $self->_cancel_deadline;
}

sub _stream_transport_close_deadline ($self) {
    $self->_close_deadline;
}

1;

__END__

=head1 NAME

Linux::Event::TLS - declare OpenSSL TLS policy for stream-socket subclasses

=head1 SYNOPSIS

  package SecureServerConnection;
  use parent 'Linux::Event::IO::Sock::Stream';
  use Linux::Event::TLS
      cert_file         => '/etc/linux-event/server-cert.pem',
      key_file          => '/etc/linux-event/server-key.pem',
      alpn              => ['echo/1'],
      handshake_timeout => 10,
      shutdown_timeout  => 5;

  sub on_data ($self, $bytes) {
      $self->write($bytes);
  }

  package SecureClientConnection;
  use parent 'Linux::Event::IO::Sock::Stream';
  use Linux::Event::TLS
      ca_file           => '/etc/ssl/certs/ca-certificates.crt',
      verify            => 1,
      alpn              => ['echo/1'],
      handshake_timeout => 10,
      shutdown_timeout  => 5;

  sub on_data ($self, $bytes) {
      say $bytes;
  }

=head1 DESCRIPTION

C<use Linux::Event::TLS> marks the calling
L<Linux::Event::IO::Sock::Stream> subclass as a TLS connection type. TLS is
transport policy on a connected C<SOCK_STREAM>; it is not a second public
socket hierarchy and it is not a framer.

The acquisition path determines the TLS role. An outbound
C<< SecureClientConnection->connect(...) >> uses client semantics. A
L<Linux::Event::IO::Sock::Listener> that names C<SecureServerConnection> as its
C<stream_class> creates a fresh server-side TLS transport for every accepted
connection.

The declaration is resolved once with the concrete subclass descriptor. It
installs no per-I/O Perl callback layer. Buffering, framing, backpressure,
protocol transitions, and established deadlines continue to use the ordinary
ordered-byte engine around plaintext application data.

The declaration must follow
C<use parent 'Linux::Event::IO::Sock::Stream'> or another subclass that already
inherits that public leaf.

=head1 ROLE SELECTION

=head2 Outbound connections

  my $connection = SecureClientConnection->connect(
      loop    => $loop,
      host    => 'example.com',
      port    => 443,
      timeout => 10,
  );

Client certificate-chain and hostname verification are enabled by default.
C<server_name> defaults to the C<host> passed to C<connect>. Declare an explicit
C<server_name> only when verification must use a different identity.
C<ca_file> and C<ca_path> optionally override OpenSSL trust-source selection.

C<verify =E<gt> 0> disables peer verification and should be used only when an
application intentionally accepts that security model.

=head2 Accepted connections

  my $listener = Linux::Event::IO::Sock::Listener->new(
      loop         => $loop,
      stream_class => 'SecureServerConnection',
      host         => '0.0.0.0',
      port         => 8443,
  );

An accepted TLS stream-socket class requires C<cert_file> and C<key_file> in
its declaration. The listener validates server identity before accepting
traffic and each accepted connection receives independent OpenSSL state.

=head2 Adopted connected handles

When an application supplies an already connected C<SOCK_STREAM> handle, the
TLS acquisition role is ambiguous. A TLS-declared adopted handle therefore
requires C<tls_role>:

  my $connection = SecureServerConnection->new(
      loop     => $loop,
      fh       => $socket,
      tls_role => 'server',
  );

C<tls_role> accepts C<client> or C<server>. A client-role adopted handle also
needs a declared C<server_name> because there is no outbound C<connect> host
from which to derive one.

=head1 DECLARATION OPTIONS

C<cert_file> and C<key_file> form the server credential pair.
C<server_name>, C<verify>, C<ca_file>, and C<ca_path> configure client
verification. C<alpn> is an optional array reference used in either role.
C<handshake_timeout> and C<shutdown_timeout> are non-negative seconds, default
to 10 and 5, and are disabled by zero.

One stream-socket subclass may contain both client and server settings when the
same application protocol is acquired in both roles. Only the settings relevant
to the selected role are used for a particular connection.

=head1 READINESS AND DATA

The ordered-byte engine owns descriptor readiness, buffering, framing,
backpressure, and established deadlines. OpenSSL owns handshake state,
cryptography, certificate verification, ALPN, retry direction, and TLS close
notification.

C<on_data>, C<on_message>, and C<on_messages> receive plaintext. C<on_ready>
runs only after the handshake and required verification complete.

C<< $connection->end >> drains accepted plaintext output and performs TLS
shutdown. C<< $connection->close >> is immediate. A TLS connection cannot be
detached because its descriptor is coupled to live encrypted transport state.

A clean peer C<close_notify> becomes the ordinary readable EOF lifecycle.
Underlying socket EOF without required TLS close semantics is reported as a
typed TLS read failure. TLS writes use Linux C<MSG_NOSIGNAL> and do not modify
the process-wide C<SIGPIPE> disposition.

=head1 TLS INFORMATION

C<< $connection->selected_alpn >>, C<< $connection->tls_protocol >>,
C<< $connection->tls_cipher >>, and C<< $connection->tls_stats >> expose
negotiated state and native counters without exposing the private provider
object.

=head1 PERFORMANCE

TLS is integrated through the private native byte-transport boundary. The
ordinary plain socket path retains its specialized direct syscall behavior;
adding TLS support to the distribution does not add a Perl dispatch layer to
plain stream-socket I/O.

Framing remains above the transport and therefore sees plaintext. Protocol
C<transition_to> changes framing/callback policy without recreating the socket
or TLS provider.

=head1 REQUIREMENTS

Linux and OpenSSL 1.1.1 or newer, including development headers at build time.

=cut
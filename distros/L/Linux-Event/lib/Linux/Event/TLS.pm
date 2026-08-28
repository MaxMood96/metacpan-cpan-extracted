package Linux::Event::TLS;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.103';

use Carp qw(croak);
use POSIX qw(isfinite);
use utf8 ();

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

sub CLONE_SKIP ($class) { 1 }

sub import ($class, @arg) {
    my $target = caller;
    my $is_stream = $target->isa('Linux::Event::Stream');
    return if $target eq 'main' && !$is_stream && !@arg;
    croak "$target must inherit from Linux::Event::Stream before declaring TLS"
        if !$is_stream;
    croak 'TLS declaration options must be key/value pairs' if @arg % 2;
    Linux::Event::Stream->_declare_tls(
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
    croak "$target is used for accepted TLS Streams but does not declare "
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

Linux::Event::TLS - declare OpenSSL TLS policy for a Stream subclass

=head1 SYNOPSIS

  package SecureServerStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::TLS
      cert_file         => '/etc/linux-event/server-cert.pem', # required inbound
      key_file          => '/etc/linux-event/server-key.pem',  # required inbound
      alpn              => ['echo/1'],                         # optional
      handshake_timeout => 10,                                 # default
      shutdown_timeout  => 5;                                  # default

  sub on_data ($stream, $bytes) {
      $stream->write($bytes);
  }

  package SecureClientStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::TLS
      ca_file           => '/etc/ssl/certs/ca-certificates.crt', # optional
      verify            => 1,                                   # default
      alpn              => ['echo/1'],                          # optional
      handshake_timeout => 10,                                  # default
      shutdown_timeout  => 5;                                   # default

  sub on_data ($stream, $bytes) {
      say $bytes;
  }

=head1 DESCRIPTION

C<use Linux::Event::TLS> marks the calling L<Linux::Event::Stream> subclass as
a TLS connection type. The acquisition path selects the handshake role:
C<< SecureClientStream->connect(host =E<gt> 'example.com', port =E<gt> 443) >>
uses client TLS, while a
L<Linux::Event::Listener> that names C<SecureServerStream> as its
C<stream_class> uses server TLS for every accepted connection.

There is no TLS Stream base class and no public client object. TLS remains an
internal byte transport so protocol inheritance, framing, and
C<transition_to> remain independent of encryption. The declaration is
validated once and stored with the subclass's cached descriptor. Every Stream
instance receives fresh native OpenSSL connection state automatically.

The declaration must follow C<use parent 'Linux::Event::Stream'>. It installs
no methods and adds no per-I/O Perl dispatch.

=head1 ROLE SELECTION

=head2 Outbound connections

  my $stream = SecureClientStream->connect(
      loop    => $loop,          # optional: start immediately
      host    => 'example.com',  # required for TCP
      port    => 443,            # required for TCP
      timeout => 10,             # default
  );

Client certificate-chain and hostname verification are enabled by default.
C<server_name> defaults to the C<host> passed to C<connect>. Declare an
explicit C<server_name> only when verification must use a different identity.
C<ca_file> and C<ca_path> optionally override OpenSSL's trust-source selection.
C<verify =E<gt> 0> disables verification and is intended only for explicitly
controlled test or private environments.

=head2 Accepted connections

  my $listener = Linux::Event::Listener->new(
      loop         => $loop,                 # optional: start immediately
      stream_class => 'SecureServerStream',  # required
      host         => '0.0.0.0',             # required for TCP
      port         => 8443,                  # required for TCP
  );

An accepted TLS Stream requires C<cert_file> and C<key_file> in its class
declaration. Listener preflights that server identity during construction and
creates fresh server-side connection state for every accepted socket.

=head2 Adopted connected handles

The acquisition role is ambiguous when an application supplies an already
connected C<fh>. This advanced form therefore requires C<tls_role>:

  my $stream = SecureServerStream->new(
      loop     => $loop,    # optional
      fh       => $socket,  # required
      tls_role => 'server', # required for a TLS-declared adopted handle
  );

C<tls_role> accepts C<client> or C<server>. A client-role adopted handle also
needs a declared C<server_name>, because there is no C<connect> host from which
to derive it.

=head1 DECLARATION OPTIONS

C<cert_file> and C<key_file> form the required server credential pair.
C<server_name>, C<verify>, C<ca_file>, and C<ca_path> configure client
verification. C<alpn> is an optional array reference used in either role.
C<handshake_timeout> and C<shutdown_timeout> are non-negative seconds, default
to 10 and 5, and are disabled by zero.

A declaration may contain both client and server settings when one Stream
subclass is acquired in both roles. Role-specific values are selected only
when that role is instantiated.

=head1 READINESS AND DATA

Stream continues to own buffering, framing, backpressure, established
deadlines, and descriptor readiness. OpenSSL owns TLS protocol state,
cryptography, verification, ALPN, and close notification. C<on_data> and
C<on_message> receive plaintext. C<on_ready> runs only after handshake and
verification succeed.

C<< $stream->end >> drains plaintext output and sends C<close_notify>.
C<< $stream->close >> is immediate. A TLS Stream cannot be detached because
its descriptor contains encrypted provider state. Clean peer C<close_notify>
uses ordinary Stream EOF handling; socket EOF without it is a typed C<tls>
read error. TLS socket writes use Linux C<MSG_NOSIGNAL> and do not modify the
process-wide C<SIGPIPE> disposition.

=head1 STREAM TLS INFORMATION

C<< $stream->selected_alpn >>, C<< $stream->tls_protocol >>,
C<< $stream->tls_cipher >>, and C<< $stream->tls_stats >> expose negotiated
state and native counters without revealing the internal provider object.

=head1 REQUIREMENTS

Linux and OpenSSL 1.1.1 or newer, including development headers at build time.

=cut

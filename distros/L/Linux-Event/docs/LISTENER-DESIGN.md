# Stream socket listener design

`Linux::Event::IO::Sock::Listener` owns a listening Linux `SOCK_STREAM`
socket and constructs one configured `Linux::Event::IO::Sock::Stream`
subclass for every accepted connection.

The listener remains a distinct public leaf because its API is accept-oriented.
A listening `SOCK_STREAM` socket is not exposed as though it were an established
ordered-byte connection.

## Public API

```perl
my $server_state = { connections => {} };

my $listener = Linux::Event::IO::Sock::Listener->new(
    loop                => $loop,
    stream_class        => 'ServerConnection',
    host                => '0.0.0.0',
    port                => 9999,
    backlog             => 4096,
    max_accept_per_tick => 256,
    edge_triggered      => 0,
    data                => $server_state,
);
```

Detached construction is equivalent:

```perl
my $listener = Linux::Event::IO::Sock::Listener->new(
    stream_class => 'ServerConnection',
    unix         => '/run/app.sock',
    unlink       => 1,
    permissions  => 0660,
);
$loop->add($listener);
```

`stream_class` names the completed stream-socket subclass constructed for each
accepted descriptor. The listener's `data` value is passed to each accepted
object initially; `on_accept` can replace that connection's data if desired.

## Socket type and address family

The listener always represents `SOCK_STREAM` in listening state. Its address
family is selected independently.

Exactly one source form is required:

- `host => $host, port => $port` creates an IPv4/IPv6 listener;
- `unix => $path` creates a filesystem Unix-domain stream listener;
- `fh => $listening_socket` adopts an existing listening `SOCK_STREAM` handle.

A Unix listener is therefore not a separate public `Socket::Unix` class. Both
Internet and Unix-domain listeners use `IO::Sock::Listener` because socket type
and role are the same.

Created listener sockets are nonblocking and close-on-exec and are owned by the
listener. An adopted handle defaults to caller ownership; `owns_socket => 1`
transfers ownership.

`host => '*'` selects passive wildcard resolution. When `port => 0` is used,
`port()` reports the kernel-assigned port after construction.

## Source-specific configuration

Internet listener options include:

- `backlog`
- `reuseaddr`
- `reuseport`
- `v6only`
- `bind_device`

Unix-domain options include:

- `backlog`
- `unlink`
- `unlink_on_close`
- `permissions`

Options that have no meaning for the selected source are rejected rather than
silently ignored.

Examples:

```perl
my $tcp = Linux::Event::IO::Sock::Listener->new(
    stream_class => 'ServerConnection',
    host         => '::',
    port         => 9999,
    reuseaddr    => 1,
    reuseport    => 0,
    v6only       => 1,
    bind_device  => 'eth0',
);
```

```perl
my $unix = Linux::Event::IO::Sock::Listener->new(
    stream_class    => 'ServerConnection',
    unix            => '/run/app.sock',
    unlink          => 0,
    unlink_on_close => 1,
    permissions     => 0660,
);
```

```perl
my $adopted = Linux::Event::IO::Sock::Listener->new(
    stream_class => 'ServerConnection',
    fh           => $socket,
    owns_socket  => 0,
);
```

## Accept behavior

Native code drains `accept4()` with atomic
`SOCK_NONBLOCK | SOCK_CLOEXEC` flags.

`max_accept_per_tick` defaults to 256 to bound one level-triggered readiness
turn. Zero means drain until EAGAIN and is required with
`edge_triggered => 1`.

Each accepted descriptor is used immediately to construct the configured
`IO::Sock::Stream` subclass and attach that object to the same Loop. Linux::Event
does not create a temporary accepted-descriptor registration first.

## on_accept

A listener subclass can observe each fully constructed connection:

```perl
package ServerListener;
use parent 'Linux::Event::IO::Sock::Listener';

sub on_accept ($listener, $connection) {
    $listener->data->{connections}{ $connection->fd } = $connection;
}
```

The sequence is:

```text
accept4
  -> construct stream_class
  -> attach connection to Loop
  -> listener on_accept
  -> connection readiness
```

For a plain stream socket, `on_ready` follows after `on_accept`. For TLS,
`on_accept` still runs after attachment, while the connection's `on_ready` waits
until handshake and verification succeed.

`on_accept` may inspect, retain, configure application state on, or close the
connection.

Peer addresses are represented by `Linux::Event::Address` and formatted lazily.
Applications that never inspect `peer()` avoid textual address conversion.

## Accepted connection policy

Buffering, framing, backpressure, and established deadline policy belong to the
`stream_class` through `stream_options()`. Socket-specific established policy
belongs to that same class through `socket_options()`.

Example TLS server connection:

```perl
package SecureServerConnection;
use parent 'Linux::Event::IO::Sock::Stream';
use Linux::Event::TLS
    cert_file => '/etc/myapp/server-cert.pem',
    key_file  => '/etc/myapp/server-key.pem',
    alpn      => ['my-protocol/1'];

sub stream_options ($class) {
    return (
        idle_timeout => 60,
        max_buffer   => 8 * 1024 * 1024,
    );
}

sub socket_options ($class) {
    return tcp_nodelay => 1;
}
```

The listener then names the completed class:

```perl
my $listener = Linux::Event::IO::Sock::Listener->new(
    loop         => $loop,
    stream_class => 'SecureServerConnection',
    host         => '0.0.0.0',
    port         => 9443,
    data         => $server_state,
);
```

A server TLS declaration is validated before the listener begins accepting
traffic. Each accepted connection receives fresh server-side OpenSSL state.
There is no per-accept constructor callback layer.

Built-in accepted socket policy and the optional cached
`configure_socket($class, $fh, 'accepted', $peer)` hook run before application
readiness or TLS startup.

## Listener lifecycle

`pause()` and `resume()` control accepting without closing the listening
socket. `close()` ends listener ownership. `detach()` removes Loop readiness and
returns the still-open listener handle according to the ownership contract.

`state()` reports the listener lifecycle state, including unattached,
listening, paused, closed/failed, and detached states as defined by the
implementation.

## Errors

Runtime failures use `Linux::Event::Error`. Resource exhaustion such as
`EMFILE` pauses acceptance before reporting the error so a readable backlog
cannot create a tight error loop.

A listener subclass can handle runtime failure explicitly:

```perl
package AppListener;
use parent 'Linux::Event::IO::Sock::Listener';

sub on_error ($listener, $error) {
    warn "$error\n";
}
```

An exception from `on_accept` closes that accepted connection, suppresses its
pending readiness callback, and reports a nonfatal callback error to the
listener's error policy. The listening socket can remain active when the error
is handled.

## Address introspection

`family()` reports semantic family names such as `inet`, `inet6`, or `unix`.
`family_number()` exposes the native numeric address family. Convenience
predicates can distinguish Internet versus Unix-domain sources without
pretending address family is the socket type.

## Private implementation boundary

`Linux::Event::_Socket::Listener` is the private XS accept-engine boundary
beneath the supported public contract `Linux::Event::IO::Sock::Listener`. It is
`no_index`, excluded from META `provides`, and not an alternate public listener
API.

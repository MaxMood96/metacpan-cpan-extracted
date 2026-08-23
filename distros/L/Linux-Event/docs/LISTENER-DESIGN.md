# Listener design

`Linux::Event::Listener` owns an inbound TCP or Unix listening socket and
constructs one configured `Linux::Event::Stream` subclass for every accepted
connection. Listener is constructed directly; Stream does not own or proxy the
listening API. There is no separate generic Listen class.

## Public API

```perl
my $server_state = { connections => {} };
my $listener = Linux::Event::Listener->new(
    loop                => $loop,          # optional: attach immediately
    stream_class        => 'ServerStream', # required
    host                => '0.0.0.0',      # required for TCP
    port                => 9999,           # required for TCP
    backlog             => 4096,           # default
    max_accept_per_tick => 256,            # default
    edge_triggered      => 0,              # default
    data                => $server_state,  # optional; inherited by each Stream
);
```

Or construct detached and attach explicitly:

```perl
my $listener = $loop->add(Linux::Event::Listener->new(
    stream_class => 'ServerStream',  # required
    unix         => '/run/app.sock', # required for Unix
    unlink       => 1,               # optional; default 0
    permissions  => 0660,            # optional
));
```

`stream_class` is required and names the Stream subclass constructed for each
accepted connection. Every accepted Stream receives the Listener's `data`
value. `on_accept` may replace that value for one connection with
`$stream->data($connection_state)`.

## Socket sources

Exactly one source is required:

- `host => $host, port => $port` creates a TCP listener;
- `unix => $path` creates a filesystem Unix stream listener;
- `fh => $listening_socket` adopts an existing listening handle.

Created sockets are nonblocking and close-on-exec and are owned by Listener.
An adopted handle defaults to caller ownership; pass `owns_socket => 1` to
transfer it. `host => '*'` binds a passive wildcard address. When `port => 0`
is used, `port()` reports the assigned port after construction.

TCP options include `backlog`, `reuseaddr`, `reuseport`, `v6only`, and optional
`bind_device` (`SO_BINDTODEVICE`). Unix options include `backlog`, `unlink`,
`unlink_on_close`, and `permissions`.
Source-specific options are rejected when used with another source, preventing
configuration that appears to work but has no effect.

The complete source-specific shapes are:

```perl
my $tcp = Linux::Event::Listener->new(
    stream_class => 'ServerStream', # required
    host         => '::',           # required for TCP
    port         => 9999,           # required for TCP
    reuseaddr    => 1,              # default
    reuseport    => 0,              # default
    v6only       => 1,              # optional; kernel default if omitted
    bind_device  => 'eth0',         # optional
);

my $unix = Linux::Event::Listener->new(
    stream_class    => 'ServerStream',  # required
    unix            => '/run/app.sock', # required for Unix
    unlink          => 0,               # default
    unlink_on_close => 1,               # default
    permissions     => 0660,            # optional
);

my $adopted = Linux::Event::Listener->new(
    stream_class => 'ServerStream', # required
    fh           => $socket,        # required for adoption
    owns_socket  => 0,              # default
);
```

## Accept behavior

Native code drains `accept4()` with atomic `SOCK_NONBLOCK | SOCK_CLOEXEC`.
`max_accept_per_tick` defaults to 256 for level-triggered fairness. Setting it
to zero drains until `EAGAIN`; this unbounded mode is required when
`edge_triggered => 1` is selected.

The accepted descriptor is immediately used to construct the configured
Stream and attach it to the same Loop. There is no temporary accepted-socket
registration to remove or replace.

An optional Listener callback observes every fully constructed Stream:

```perl
package ServerListener;
use parent 'Linux::Event::Listener';

sub on_accept ($listener, $stream) {
    $listener->data->{connections}{ $stream->fd } = $stream;
}
```

The order is construction, Loop attachment, `on_accept`, then plain Stream
`on_ready`. For TLS, `on_accept` still runs immediately after attachment and
Stream `on_ready` waits for a successful handshake. The callback can inspect,
retain, configure, or close the Stream.

Peer addresses are represented by `Linux::Event::Address` and decoded lazily.
Applications that never inspect `peer()` do not pay for textual address
formatting.

## Accepted Stream policy

Accepted connection policy belongs to the Stream subclass. General buffering,
deadline, and accepted-socket defaults use `stream_options`. Built-in socket
policy and `configure_socket($stream, $fh, 'accepted', $peer)` run before plain
readiness or TLS startup. TLS is declared once on that same class:

```perl
package SecureServerStream;
use parent 'Linux::Event::Stream';
use Linux::Event::TLS
    cert_file => '/etc/myapp/server-cert.pem', # required for server role
    key_file  => '/etc/myapp/server-key.pem',  # required for server role
    alpn      => ['my-protocol/1'];             # optional

sub stream_options ($class) {
    return (
        idle_timeout => 60,                # optional; default 0
        max_buffer   => 8 * 1024 * 1024,   # default
        tcp_nodelay  => 1,                 # optional
    );
}

package main;
my $server_state = { connections => {} };
my $listener = Linux::Event::Listener->new(
    loop         => $loop,                 # optional: attach immediately
    stream_class => 'SecureServerStream',  # required
    host         => '0.0.0.0',             # required for TCP
    port         => 9443,                  # required for TCP
    data         => $server_state,         # optional; inherited by each Stream
);
```

Listener recognizes that `SecureServerStream` declares TLS, validates the
server certificate and key during Listener construction, and creates a fresh
server-side TLS transport for each accepted connection. There is no per-accept
options hook.

## Errors and lifecycle

`pause()` and `resume()` control acceptance without closing the socket.
`close()` ends Listener ownership. `detach()` cancels readiness and returns the
still-open listener handle. Terminal cleanup releases the Loop reference.
`state()` reports `unattached`, `listening`, `paused`, `closed`, `failed`, or
`detached`.

Runtime failures use `Linux::Event::Error`. Resource exhaustion errors such as
`EMFILE` pause acceptance before notification to avoid a readable-backlog error
spin. The base Listener dies after a runtime failure. A Listener subclass may
override that policy:

```perl
package AppListener;
use parent 'Linux::Event::Listener';

sub on_error ($listener, $error) {
    warn "$error\n";
}
```

Without that hook, Listener treats a runtime listener failure as fatal.
An exception from `on_accept` closes only that accepted Stream, suppresses its
pending `on_ready`, and delivers a nonfatal `callback` Error to `on_error`.
The Listener remains active when `on_error` handles the failure.

`family()` returns `inet`, `inet6`, `unix`, or `unknown` consistently with
`Linux::Event::Address`. `family_number()` returns the native numeric family;
`is_tcp()` and `is_unix()` provide direct predicates.

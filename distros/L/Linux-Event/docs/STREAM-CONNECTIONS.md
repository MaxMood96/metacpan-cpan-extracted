# Stream connection design

Outbound connection acquisition is part of `Linux::Event::Stream`. There is no
public Connect or Connector object. The application creates the object it wants
to use after establishment, and that same object owns every later state.

## Public API

```perl
package ClientStream;
use parent 'Linux::Event::Stream';
use Linux::Event::TLS
    verify => 1,              # default
    alpn   => ['http/1.1'];   # optional

package main;
my $state = { requests => {} };
my $stream = ClientStream->connect(
    loop    => $loop,              # optional: attach immediately
    host    => 'example.com',      # required
    port    => 443,                # required
    timeout => 10,                 # default
    data    => $state,             # optional
    local_host  => '192.0.2.20',   # optional numeric source address
    local_port  => 0,              # optional source port
    tcp_nodelay => 1,              # optional socket policy
);
```

The TLS declaration is part of the Stream type. `connect()` selects the client
role automatically and defaults SNI and hostname verification to its `host`.
Specify `server_name` in the declaration only when it must differ from the
connection host.

Detached construction is equivalent:

```perl
my $stream = ClientStream->connect(
    host => '127.0.0.1', port => 9999,
);
$loop->add($stream);
```

The Stream accepts `write()` and `send()` before it is ready. Pending output is
bounded by the Stream class's normal `max_pending_bytes` policy and is flushed
in order after establishment. Its `write()` result, `pending_bytes`, and
`is_write_blocked` use the normal high-watermark contract during acquisition;
if that interval blocks, one `on_drain` follows readiness after output reaches
the low watermark.

## Address modes

Exactly one address mode is required:

- `host => $host, port => $port` resolves IPv4/IPv6 candidates;
- `unix => $path` connects to a filesystem Unix stream socket;
- `sockaddr => $packed, family => $af` uses a caller-packed address.

`timeout` is a non-negative number of seconds and defaults to 10. A zero value
disables the connection deadline. The deadline covers hostname resolution and
every socket attempt. Numeric IPv4/IPv6 literals, Unix addresses, and packed
sockaddrs bypass the resolver.

Most clients omit `local_host` and `local_port`. Linux then chooses the source
address and ephemeral source port. Local binding constrains the source side;
it never replaces the remote `host` and `port`. `local_host` is numeric only,
and its family must match the chosen peer candidate. `bind_device` optionally
applies `SO_BINDTODEVICE` before local bind and connect.

## Socket configuration order

Class `stream_options` and constructor socket values are applied to every new
candidate before local binding and connect. Constructor values win over class
policy, while an omitted value leaves the kernel default unchanged. The cached
`configure_socket($stream, $fh, 'connect', $address)` hook runs after built-in
policy and before bind/connect. A hook or socket-policy failure is terminal and
does not become an unexplained candidate fallback.

See `SOCKET-CONFIGURATION.md` for TCP_NODELAY, keepalive, TCP_USER_TIMEOUT,
buffers, live setters, and accepted/adopted roles.

## State sequence

```text
unattached -> connecting -> active -> closed
     |             |                    ^
     +-------------+------ failure -----+
```

Supplying `loop =>` performs the first transition before the constructor
returns. Detached construction remains `unattached` until `Loop->add()`.
Closing during connection cancels all attempts and the deadline without firing
a later readiness or error callback.

## Readiness

`on_ready($stream)` runs once when the Stream is usable by the application. For
a plain connection that means the socket connected successfully. For TLS it
means TCP establishment, TLS handshake, and certificate/hostname verification
all completed. Accepted plain Streams are ready after Listener attaches them.

Connection failure is delivered to `on_error($stream, $error)`, followed by
the ordinary close lifecycle. The error is a `Linux::Event::Error`; its
`type`, `operation`, `errno`, address fields, and `attempts` distinguish resolve,
socket, connect, and deadline failures.

## Internal implementation

`Linux::Event::Stream::_Connection` is a private acquisition engine. It owns
candidate attempts and a Linux timerfd while the public Stream is connecting.
On success it hands the connected handle directly back to that Stream, which
installs its established native read/write state. No second public object or
callback adapter is created.

The private engine is deliberately in Perl because connection setup is a cold
lifecycle path. XS provides the timerfd, resolver workers, eventfd wakeup, and
established Stream hot paths. This keeps policy readable without adding Perl
dispatch to steady-state I/O.

## Resolver and Happy Eyeballs

Each Loop lazily acquires one private resolver service with two native pthread
workers. Workers call `getaddrinfo`, copy complete address results into native
memory, and write the service eventfd. They never enter the Perl interpreter or
touch Perl values. The Loop watches that eventfd through its ordinary raw
`watch()` mechanism, drains completions on the Loop thread, and resumes the
private connection engine there. This private typed queue is not routed through
the public Wakeup callback API: the resolver already owns a fixed native result
schema, cancellation table, and lifetime. Applications use Wakeup only with
their own safe result channel.

IPv6 and IPv4 candidates are interleaved. The first connection attempt starts
immediately; while it remains pending, the next family starts after 250 ms.
Further candidates use the same stagger. A failure may advance immediately,
the first successful socket wins, and every losing watcher and socket is
cancelled deterministically.

Cancellation removes the resolver request's Loop-thread recipient. A native
`getaddrinfo` already running may finish, but its late completion is discarded
safely. Applications do not need a threaded Perl build: the distribution uses
native C threads and keeps Perl confined to the Loop thread. Fork before a Loop
starts hostname resolution; a resolver service is not reusable in a forked
child.

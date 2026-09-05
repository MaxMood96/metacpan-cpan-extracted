# Stream socket connection design

Outbound connection acquisition belongs to
`Linux::Event::IO::Sock::Stream`. There is no public Connect or Connector
object. The application creates the stream-socket object it wants to use after
establishment, and that same object owns every acquisition and established
state.

## Public API

```perl
package ClientConnection;
use parent 'Linux::Event::IO::Sock::Stream';
use Linux::Event::TLS
    verify => 1,              # default
    alpn   => ['http/1.1'];   # optional

package main;
my $state = { requests => {} };
my $connection = ClientConnection->connect(
    loop       => $loop,            # optional: attach immediately
    host       => 'example.com',    # remote address
    port       => 443,
    timeout    => 10,               # connection acquisition deadline
    data       => $state,
    local_host => '192.0.2.20',     # optional numeric source address
    local_port => 0,                # optional source port
    tcp_nodelay => 1,               # optional socket policy
);
```

The TLS declaration is policy on the completed stream-socket subclass.
`connect()` selects client handshake semantics automatically and defaults SNI
and hostname verification to `host`. Declare a distinct `server_name` only when
the verified identity must differ from the connection host.

Detached construction is equivalent:

```perl
my $connection = ClientConnection->connect(
    host => '127.0.0.1',
    port => 9999,
);
$loop->add($connection);
```

The object can accept `write()` and framed `send()` before readiness. Pending
output follows the normal ordered-byte `max_pending_bytes`, high-watermark, and
`on_drain` policy and is flushed in order after establishment.

## Socket type versus address family

This class represents Linux `SOCK_STREAM`. Address family is an independent
configuration axis.

Supported address modes are:

- `host => $host, port => $port` for IPv4/IPv6 stream sockets;
- `unix => $path` for filesystem Unix-domain `SOCK_STREAM` sockets;
- `sockaddr => $packed, family => $af` for a caller-packed address.

A Unix-domain stream socket is therefore not a different public sibling class.
It is `IO::Sock::Stream` configured with an `AF_UNIX` address.

Exactly one remote address mode is required.

## Connection deadline

`timeout` is a non-negative number of seconds and defaults to 10. Zero disables
the connection-acquisition deadline. It covers hostname resolution and every
socket attempt.

Numeric IPv4/IPv6 literals, Unix addresses, and caller-packed addresses bypass
hostname resolution.

Connection acquisition deadlines are distinct from established
idle/read/write/operation deadlines and TLS handshake/shutdown deadlines. Each
layer reports its own operation rather than obscuring another lifecycle stage.

## Local source binding

Most clients omit `local_host` and `local_port`. Linux then chooses the source
address and ephemeral source port.

When supplied, `local_host` is numeric and must match the family of the remote
candidate. `local_port` selects the source port. These options constrain the
local side and never replace the remote `host` and `port`.

`bind_device` can apply `SO_BINDTODEVICE` before local bind and connect.

## Socket configuration order

Cached class `socket_options()` policy and per-instance socket options are
applied to each new candidate before local bind and connect. Constructor values
override class defaults; omitted values leave Linux kernel defaults unchanged.

An optional cached:

```perl
sub configure_socket ($class, $fh, $role, $address) {
    ...
}
```

hook runs after built-in socket policy and before bind/connect. A hook or socket
configuration error is terminal for the acquisition operation rather than
silently becoming an unrelated candidate fallback.

See [`SOCKET-CONFIGURATION.md`](SOCKET-CONFIGURATION.md) for TCP_NODELAY,
keepalive, TCP_USER_TIMEOUT, buffer sizing, live setters, and role-specific
option applicability.

## Lifecycle

```text
unattached -> connecting -> active -> closed
     |             |                    ^
     +-------------+------ failure -----+
```

Supplying `loop =>` attaches before `connect()` returns. Without a Loop the
object remains unattached until `$loop->add($connection)`.

Closing while connecting cancels attempts, resolver delivery, and connection
deadline state. A cancelled connection must not later report readiness or an
operational error from stale acquisition work.

## Readiness

`on_ready($connection)` runs once when application I/O is usable.

For a plain stream socket this means connection establishment succeeded. For a
TLS-declared type it means the socket connected and the TLS handshake,
certificate validation, and hostname verification completed successfully.

Connection failure is delivered through:

```perl
sub on_error ($connection, $error) {
    ...
}
```

followed by normal close lifecycle. `Linux::Event::Error` fields distinguish
resolution, socket creation/configuration, connect, and timeout failures.

## Pre-readiness output and backpressure

A connecting object uses the same application-facing write contract as an
established ordered-byte object. Output accepted before the native transport is
ready is retained in order.

`pending_bytes` includes preconnection output. `is_write_blocked` and the
return value from `write()` reflect the configured high watermark. If output
crosses the watermark during acquisition, exactly one `on_drain` is delivered
after readiness once pending output reaches the low watermark.

A nonzero `max_pending_bytes` remains a hard limit during acquisition as well as
after establishment.

## Internal acquisition engine

`Linux::Event::_Socket::Connection` is the private acquisition implementation
package. It is not part of the public namespace contract.

The acquisition engine owns candidate attempts and its connection deadline.
On success it transfers the connected descriptor directly into the same
`IO::Sock::Stream` application object, which then installs its established
native ordered-byte state. No second public connection object or callback
adapter is created.

Connection setup intentionally remains a cold policy path. Native code is used
where it materially matters: resolver workers, timerfd/eventfd facilities, and
established ordered-byte I/O. This keeps connection policy readable without
adding Perl dispatch to steady-state traffic.

## Resolver and Happy Eyeballs behavior

Each Loop lazily acquires a private resolver service backed by native worker
threads. Workers call `getaddrinfo`, copy results into native storage, and
signal a private eventfd. They do not enter the Perl interpreter.

Completion is consumed on the Loop thread and routed back to the pending
connection request. This typed internal queue is separate from the public
`Kernel::Event` abstraction because resolver results already have a fixed native
schema and cancellation table.

IPv6 and IPv4 candidates are interleaved. The first attempt starts immediately;
while it remains pending, the next family can start after the configured
internal stagger currently used by the implementation. Failure can advance to
a later candidate immediately. The first successful descriptor wins and losing
watchers/descriptors are closed deterministically.

Cancellation removes the Loop-thread recipient. A native `getaddrinfo` already
running may complete, but its late result is discarded safely.

Linux::Event does not require threaded Perl for this resolver path. Perl state
remains confined to the Loop thread.

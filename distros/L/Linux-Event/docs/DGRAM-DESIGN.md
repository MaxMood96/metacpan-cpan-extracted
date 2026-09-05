# Dgram socket design

`Linux::Event::IO::Sock::Dgram` is the packet-preserving socket leaf for Linux
`SOCK_DGRAM`. It supports UDP and Unix-domain datagram sockets without
flattening packets into the ordered-byte engine.

A packet queue is semantically different from a byte stream: packet boundaries,
per-packet destinations, truncation, and peer addresses must be preserved.

## Public type model

A concrete subclass defines `on_datagram` once:

```perl
package EchoDgram;
use parent 'Linux::Event::IO::Sock::Dgram';

sub on_datagram ($socket, $payload, $peer) {
    $socket->is_connected
        ? $socket->send("echo:$payload")
        : $socket->send("echo:$payload", to => $peer);
}

sub on_error ($socket, $error) {
    warn "$error\n";
}
```

Callbacks and immutable class policy are cached per subclass. Each instance
owns its socket, packet queue, backpressure state, addresses, and application
`data`.

## Socket type versus family

The public class represents `SOCK_DGRAM`. Address family is separate
configuration.

UDP over IPv4/IPv6 and Unix-domain datagrams therefore share
`IO::Sock::Dgram`; there is no sibling `Socket::Unix` class.

## Unconnected UDP

An unconnected Internet datagram socket binds a local address and receives the
source `Linux::Event::Address` with each packet:

```perl
my $server = $loop->add(EchoDgram->new(
    host => '0.0.0.0',
    port => 9999,
));
```

`port => 0` requests an ephemeral local port.

## Connected UDP

A connected datagram object installs a default peer and can resolve a hostname
asynchronously when needed:

```perl
my $client = $loop->add(EchoDgram->connect(
    host       => 'collector.example.com',
    port       => 9000,
    local_host => '192.0.2.20',
    local_port => 0,
));
```

Connected UDP still preserves one packet per `send()` call. Kernel `connect`
selects the default peer and filters incoming packets to that peer; it does not
turn the socket into an ordered byte stream.

## Unix-domain datagrams

Filesystem Unix-domain sockets use path options:

```perl
my $server = EchoDgram->new(
    unix            => '/run/example.sock',
    unlink          => 0,
    unlink_on_close => 1,
    permissions     => 0660,
);
```

A connected Unix-domain client can have an optional local reply path:

```perl
my $client = EchoDgram->connect(
    unix            => '/run/example.sock',
    local_unix      => '/run/example-client.sock',
    unlink          => 0,
    unlink_on_close => 1,
    permissions     => 0600,
);
```

Closing a client may remove only its owned local path; it never unlinks the
peer path. `detach()` suppresses owned-path cleanup because ownership has been
transferred away from Linux::Event.

## Adopted sockets

An adopted `fh` must be a datagram socket in a supported IPv4, IPv6, or Unix
family. Linux::Event sets nonblocking and close-on-exec flags, detects an
existing connected peer where applicable, and defaults to caller ownership.

`owns_socket => 1` transfers descriptor close ownership to the Dgram object.

## Lifecycle

Bound server sockets are created during `new()` and begin unattached when no
Loop is supplied. Connected hostname work begins on attachment so DNS and
operational failure do not occur as a hidden constructor side effect.

Conceptually:

```text
unattached -> resolving/configuring -> active -> closed
     |                  |                |         ^
     |                  +-- error -------+-> failed
     +------------------------------------> detached
```

Literal numeric/Unix connection setup also follows the attachment lifecycle.
`on_ready` is delivered from the Loop after the packet socket is active.

`close()` is idempotent. `detach()` returns the still-open socket according to
the ownership contract, does not call `on_close`, and is terminal for the
Linux::Event object.

The owning Loop remains available during terminal error/close callbacks and is
released afterward.

## Packet input

XS drains `recvmsg()` into a reusable native buffer during readiness dispatch.
Each semantic callback receives exactly one packet payload and one lazy peer
`Linux::Event::Address` where a peer address is applicable.

Zero-length packets are valid.

`max_datagram_size` defaults to 65,535 bytes. Input uses `MSG_TRUNC` so the
implementation can learn the original packet length. An oversized packet is
discarded as one packet and reported as a `datagram_size` error; Linux::Event
does not deliver a misleading truncated payload as though it were complete.

`max_datagrams_per_tick` defaults to 256 for level-triggered fairness. Zero
means drain until EAGAIN and is required when edge-triggered operation is
selected.

## Packet output

One `send()` call is one packet:

```perl
$connected->send('metrics');
$unconnected->send('reply', to => $peer);
```

The connected form rejects `to`. The unconnected form requires a destination.

Native output uses nonblocking `send`/`sendto` with `MSG_NOSIGNAL`. Datagram
writes are atomic from the application model. A packet that would block remains
one queued packet and is retried whole.

Soft byte watermarks provide cooperative backpressure. A false return means the
packet was accepted but the producer should wait for `on_drain` before adding
more.

Hard `max_pending_bytes` and `max_pending_datagrams` limits reject only the new
packet and report `output_limit`; already queued packets remain in order.

## Class policy

Dgram-specific class policy caches packet limits, fairness, watermarks, and
socket options once per concrete subclass. Per-instance constructor values can
override supported settings for one socket.

Internet-only and Unix-only options are validated against the selected family,
including explicit false values. See `SOCKET-CONFIGURATION.md` for the socket
policy matrix.

## Resolver boundary

Connected hostname UDP reuses the Loop's private native resolver service with
`SOCK_DGRAM` hints. Native workers return C-owned address candidates and signal
a private service eventfd without entering Perl.

Cancellation removes the Loop-thread recipient so a late `getaddrinfo`
completion can be discarded safely.

UDP does not use TCP-style Happy Eyeballs connection racing because datagram
`connect()` performs no handshake. Candidates can be tried until one socket can
be created, configured, locally bound, and connected. Socket-configuration
failure is terminal; ordinary candidate failure can move to another address.

## Error policy

Packet-size violations, queue overflow, and ordinary active datagram I/O errors
can be reported without automatically closing a still-valid packet socket.
Resolver/acquisition failure before activation is terminal.

`last_error` retains the most recent structured error. A subclass can define
`on_error`; otherwise the implementation's documented default reporting policy
applies.

## Private implementation boundary

`Linux::Event::_Socket::Dgram` is the private `no_index` packet-engine boundary
beneath the supported application class `Linux::Event::IO::Sock::Dgram`. It is
excluded from META `provides` and is not an application construction or
subclassing surface.

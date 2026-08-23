# Datagram design

`Linux::Event::Datagram` is the packet-preserving network object for UDP and
Unix datagram sockets. It does not adapt Stream: a byte queue cannot represent
packet boundaries, per-packet destinations, truncation, or source addresses
correctly.

## Public type model

A concrete subclass defines `on_datagram` once:

```perl
package EchoDatagram;
use parent 'Linux::Event::Datagram';

sub on_datagram ($socket, $payload, $peer) {
    $socket->is_connected
        ? $socket->send("echo:$payload")
        : $socket->send("echo:$payload", to => $peer);
}

sub on_error ($socket, $error) {
    warn "$error\n";
}
```

Callbacks are cached per subclass. Each object owns its socket, packet queue,
backpressure state, addresses, and application `data`.

## Socket forms

Unconnected UDP binds a local address and receives the source Address with
each packet:

```perl
my $server = $loop->add(EchoDatagram->new(
    host => '0.0.0.0', # required
    port => 9999,      # required; 0 chooses an ephemeral port
));
```

Connected UDP resolves a hostname asynchronously when necessary, installs a
default peer, and filters incoming traffic to that peer:

```perl
my $client = $loop->add(EchoDatagram->connect(
    host       => 'collector.example.com', # required
    port       => 9000,                    # required
    local_host => '192.0.2.20',            # optional numeric source address
    local_port => 0,                       # optional source port
));
```

Unix datagrams use filesystem paths:

```perl
my $server = EchoDatagram->new(
    unix            => '/run/example.sock', # required
    unlink          => 0,                   # default
    unlink_on_close => 1,                   # default
    permissions     => 0660,                # optional
);

my $client = EchoDatagram->connect(
    unix            => '/run/example.sock',        # required peer path
    local_unix      => '/run/example-client.sock', # optional reply path
    unlink          => 0,                          # default
    unlink_on_close => 1,                          # default
    permissions     => 0600,                       # optional
);
```

Closing a connected Unix client may remove only `local_unix`; it never unlinks
the peer's path. `detach` suppresses all path removal.

An adopted `fh` must be a datagram socket in the IPv4, IPv6, or Unix family.
Datagram sets nonblocking and close-on-exec flags, detects a connected peer,
and defaults to caller ownership. `owns_socket => 1` transfers close ownership.

## Lifecycle

Bound server sockets are created during `new` and start `unattached`.
Connected sockets are created on Loop attachment so outbound hostname work and
failure do not occur in the constructor. States are:

```text
unattached -> resolving -> active -> closed
     |            |          |         ^
     |            +-- error -+-> failed|
     +--------------------------> detached
```

Literal Internet and Unix connection setup happens during attachment;
hostname completion resumes on the Loop thread. `on_ready` is deferred to a
later Loop turn after the socket is active. `close` is idempotent. `detach`
returns the still-open handle, does not call `on_close`, and is terminal.

The Loop remains available during terminal `on_error` and `on_close`
notifications and is released afterward.

## Packet input

XS drains `recvmsg` into one native buffer per readiness dispatch. Each
delivered callback receives exactly one payload and one lazy
`Linux::Event::Address`. Zero-length packets are valid.

`max_datagram_size` defaults to 65,535 bytes. Native input uses `MSG_TRUNC` to
learn the original packet length. An oversized packet is discarded whole and
reported as a `datagram_size` Error; no partial payload is delivered.

`max_datagrams_per_tick` defaults to 256 for level-triggered fairness. Zero
drains until `EAGAIN` and is required by `edge_triggered => 1`.

## Packet output

One `send` call represents one packet:

```perl
$connected->send('metrics');
$unconnected->send('reply', to => $peer);
```

The connected form rejects `to`; the unconnected form requires an Address.
Native output uses `send` or `sendto` with `MSG_DONTWAIT | MSG_NOSIGNAL`.
Datagram writes are atomic. A packet that would block remains one queued
segment and is retried whole.

Soft byte watermarks provide cooperative backpressure. A false return means
the packet was accepted and the producer should wait for `on_drain`. Hard
`max_pending_bytes` and `max_pending_datagrams` limits reject only the new
packet and report `output_limit`; existing queued packets remain ordered.

## Policy and options

`datagram_options` caches packet limits, fairness, watermarks, and common
socket policy once per subclass. Constructor values override the class for one
object. Internet-only and Unix-only options are validated against the selected
source, including explicit false values. See `SOCKET-CONFIGURATION.md` for the
full matrix and live setters.

## Resolver boundary

Connected hostname UDP reuses the Loop's private native resolver service with
`SOCK_DGRAM` hints. Workers copy candidates into C-owned completion values and
signal the service eventfd; they never enter Perl. Cancellation removes the
recipient, so late `getaddrinfo` completion is discarded safely.

UDP does not use a TCP-style Happy Eyeballs race because `connect` does not
perform a handshake. Candidates are tried in resolver order until one socket
can be configured, locally bound, and connected. A socket-configuration error
is terminal; ordinary address or connect failure may advance to another
candidate.

## Error policy

Queue overflow, packet truncation, and ordinary datagram I/O are reported
without automatically closing an active packet socket. Resolver and connection
failure make the object terminal. `last_error` always retains the most recent
Error. Without `on_error`, Datagram warns rather than hiding the failure.

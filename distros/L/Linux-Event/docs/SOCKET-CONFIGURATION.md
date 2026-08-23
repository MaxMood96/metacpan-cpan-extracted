# Socket configuration

Linux::Event applies common Linux socket policy during acquisition and exposes
live setters only where a post-acquisition change has clear kernel semantics.
Omitted policy leaves the kernel value untouched.

## Precedence

For Stream and Datagram socket policy, precedence is:

1. constructor option for one object;
2. cached `stream_options` or `datagram_options` value;
3. the existing kernel default when both are omitted.

Linux::Event does not manufacture a second set of network defaults. This keeps
system tuning, container policy, and inherited filehandle configuration
observable instead of silently replacing them.

## Stream policy

A Stream type may cache policy once:

```perl
sub stream_options ($class) {
    return (
        tcp_nodelay        => 1,       # optional
        keepalive          => 1,       # optional
        keepalive_idle     => 60,      # optional; seconds
        keepalive_interval => 10,      # optional; seconds
        keepalive_count    => 5,       # optional
        tcp_user_timeout   => 15,      # optional; seconds
        send_buffer        => 262_144, # optional; bytes
        receive_buffer     => 262_144, # optional; bytes
    );
}
```

The same names may be supplied to `new` for an established handle or to
`connect` for one outbound Stream:

```perl
my $stream = ClientStream->connect(
    host        => '198.51.100.20', # required
    port        => 443,             # required
    tcp_nodelay => 0,               # optional constructor override
    send_buffer => 524_288,         # optional constructor override
);
```

TCP-only options reject Unix Streams. Send and receive buffers are valid for
TCP and Unix Stream sockets. `tcp_user_timeout` is public seconds and is
converted to Linux milliseconds; a positive duration below one millisecond is
rounded up.

## Local binding

The remote `host` and `port` identify where a Stream connects. Most clients
should supply only those values and let Linux choose the source address and
ephemeral source port.

Local binding is an optional source-side constraint:

```perl
my $stream = ClientStream->connect(
    host       => '203.0.113.10', # required remote address
    port       => 8443,           # required remote port
    local_host => '192.0.2.20',   # optional numeric source address
    local_port => 0,              # optional source port; 0 is ephemeral
);
```

`local_host` must be numeric so connection does not start a second DNS lookup.
`local_port` by itself binds the wildcard address for the candidate family.
The local and remote families must match. `0.0.0.0` and `::` are wildcard bind
addresses; they are not normally useful remote destinations.

`bind_device => 'eth0'` applies Linux `SO_BINDTODEVICE` before local binding or
connection. The kernel may require privilege. It is separate from
`local_host`: the former constrains an interface, while the latter selects a
source address.

## Listener policy

Listener owns policy for the listening socket:

```perl
my $listener = Linux::Event::Listener->new(
    stream_class => 'ServerStream', # required
    host         => '0.0.0.0',      # required for TCP
    port         => 9443,           # required for TCP
    reuseaddr    => 1,              # default
    reuseport    => 0,              # default
    bind_device  => 'eth0',         # optional
);
```

That policy does not replace accepted-connection policy. Every accepted
`ServerStream` independently applies its cached Stream options and
`configure_socket` hook before plain readiness or TLS startup.

## Datagram policy

Datagram adds packet-socket creation options:

| Option | Applicability | Default or omission behavior |
| --- | --- | --- |
| `reuseaddr` | created Internet socket | `0` |
| `reuseport` | created Internet socket | `0` |
| `broadcast` | IPv4 | `0` |
| `v6only` | IPv6 | kernel value when omitted |
| `bind_device` | Internet socket | no interface constraint when omitted |
| `send_buffer` | Internet, Unix, adopted | kernel value when omitted |
| `receive_buffer` | Internet, Unix, adopted | kernel value when omitted |

Unix path options are `unlink`, `unlink_on_close`, and `permissions`.
Source-specific options are rejected even when explicitly set to zero. This
prevents a typo such as `unlink => 0` on UDP from appearing to be supported.

## Controlled hook

Stream and Datagram subclasses may define a cached `configure_socket` method:

```perl
use Socket qw(IPPROTO_TCP TCP_QUICKACK);

sub configure_socket ($stream, $fh, $role, $address) {
    setsockopt($fh, IPPROTO_TCP, TCP_QUICKACK, pack('i', 1))
        or die "setsockopt(TCP_QUICKACK): $!";
}
```

Stream roles are `connect`, `accepted`, and `adopted`. Datagram roles are
`connect` and `adopted`. Built-in policy runs first. For outbound sockets the
hook runs before local bind and connect; for accepted or adopted sockets it
runs before transport startup. An exception becomes a structured
`socket_configuration` Error and is never ignored for a fallback candidate.

## Live values

Established Stream supports live getter/setters for:

- `tcp_nodelay`;
- `keepalive`, `keepalive_idle`, `keepalive_interval`, and `keepalive_count`;
- `tcp_user_timeout`;
- `send_buffer` and `receive_buffer`.

Datagram supports live `send_buffer`, `receive_buffer`, and IPv4 `broadcast`.
Setters return the value read back from Linux. Buffer values may be rounded or
doubled by the kernel.

## TLS and framing order

Socket configuration is below both TLS and framing:

```text
socket creation -> socket policy -> local bind/connect or accept
                -> TLS handshake when declared -> plaintext Stream framing
```

A framer sees plaintext messages and has no socket options. TLS is a Stream
transport, not a framer. Protocol `transition_to` changes callbacks and framing
for an existing connection; it does not reapply acquisition-time socket policy
or replace TLS.

## Errors

System and hook failures use `Linux::Event::Error` type
`socket_configuration`. `operation` identifies `setsockopt`, `getsockopt`,
`bind`, or `configure_socket`; `option` names the affected policy when known.
Unsupported family combinations fail explicitly instead of being skipped.

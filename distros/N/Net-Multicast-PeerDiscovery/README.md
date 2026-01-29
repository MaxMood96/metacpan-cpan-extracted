# NAME

Net::Multicast::PeerDiscovery - Local Peer Discovery via UDP Multicast

# SYNOPSIS

```perl
use Net::Multicast::PeerDiscovery;

my $discovery = Net::Multicast::PeerDiscovery->new();

# Register discovery callback
$discovery->on( peer_found => sub ($info) {
    say "Found local peer $info->{ip}:$info->{port} for swarm $info->{info_hash}";
});

# Periodically announce our presence
$discovery->announce($info_hash, 6881);

# Drive discovery logic
$discovery->tick(0.1) while 1;
```

# DESCRIPTION

`Net::Multicast::PeerDiscovery` implements a multicast-based peer discovery mechanism. While originally developed for
BitTorrent (**BEP 14**), this module is general-purpose and can be used by any peer-to-peer or local-first application
to find neighbors on the same LAN without requiring a central registry or external internet access.

## Dual-Stack Support

This implementation is [RFC 6724 compliant](https://datatracker.ietf.org/doc/html/rfc6724) and supports both IPv4 and
IPv6 multicast:

- **IPv4 Group**: `239.192.152.143`
- **IPv6 Group**: `ff15::efc0:988f` (Site-local scope)

It correctly handles [IPv6 link-local](https://en.wikipedia.org/wiki/Link-local_address#IPv6) addresses (`fe80::/10`),
preserving the `scope_id` required for local connectivity.

# METHODS

## `announce( $info_hash, $port )`

Broadcasts a `BT-SEARCH` message to the multicast groups.

Expected params:

- `$info_hash` - a unique binary identifier for the swarm/service
- `$port` - the port your application is listening on

## `tick( [$timeout] )`

Listens for incoming multicast packets and processes them. Triggers `peer_found` events.

## `is_available( )`

Returns boolean. Requires [IO::Socket::Multicast](https://metacpan.org/pod/IO%3A%3ASocket%3A%3AMulticast). If the module is missing, discovery will gracefully disable itself
and return false.

## `on( peer_found => sub ($info) { ... } )`

Registers a handler for discovered peers. `$info` is a hashref containing:

- `ip`: The IP address (includes `%scope` for link-local IPv6)
- `port`: The remote peer's port
- `info_hash`: The binary identifier they are participating in

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

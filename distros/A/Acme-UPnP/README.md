# NAME

Acme::UPnP - Cheap UPnP Port Mapping (IGD)

# SYNOPSIS

```perl
use Acme::UPnP;

my $mapper = Acme::UPnP->new( );

# Discovery
if ( $mapper->discover_device( ) ) {
    say 'Found router: ' . $mapper->upnp_device->getfriendlyname( );

    # Map a port
    $mapper->map_port( 8080, 8080, 'TCP', 'My Silly App' );
}

# Clean up on exit
$mapper->unmap_port( 8080, 'TCP' );
```

# DESCRIPTION

`Acme::UPnP` provides a high-level, easy-to-use interface for the UPnP Internet Gateway Device (IGD) protocol. It
automates the complex task of requesting port forwarding from residential routers, which is often required for
peer-to-peer applications and local servers to be accessible from the internet.

# PUBLIC METHODS

## `discover_device()`

Scans the local network for UPnP-capable gateway devices. Returns true if a device was successfully identified.

## `map_port( $internal, $external, $protocol, $description )`

Requests a new port mapping.

- `$protocol`: 'TCP' or 'UDP'.
- `$description`: A label for the router's mapping table.
- Triggers `map_success` or `map_failed` events.

## `unmap_port( $external, $protocol )`

Removes an existing port mapping.

## `get_external_ip( )`

Queries the router for its public WAN IP address.

## `is_available( )`

Returns boolean indicating if the required [Net::UPnP](https://metacpan.org/pod/Net%3A%3AUPnP) dependency is installed.

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

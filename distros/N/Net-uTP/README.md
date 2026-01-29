# NAME

Net::uTP - Micro Transport Protocol (μTP, BEP 29)

# SYNOPSIS

```perl
use Net::uTP;

my $utp = Net::uTP->new(
    conn_id_send => 1234,
    conn_id_recv => 1235
);

# Initiate connection
my $syn_pkt = $utp->connect( );

# Handle incoming UDP data
my $reply = $utp->receive_packet( $raw_udp_payload );

# Send data (returns one or more μTP packets)
my $pkts = $utp->send_data( 'Hello World' );

# Periodically handle retransmissions
my $resends = $utp->tick( 0.1 );
```

# DESCRIPTION

`Net::uTP` implements μTP, the [Micro Transport Protocol](https://www.bittorrent.org/beps/bep_0029.html) (originally
μTorrent transport protocol), a congestion-controlled UDP transport designed to prevent background traffic from
"choking" other internet activity (like VoIP or gaming) on the same network.

While originally developed for BitTorrent, this module is general-purpose and can be used for any application requiring
high-throughput, low-impact data transfer.

## Key Mechanisms

- [LEDBAT Congestion Control](https://en.wikipedia.org/wiki/LEDBAT): Uses one-way delay measurements to detect network congestion **before** packet loss occurs. It targets a specific queuing delay (100ms) and yields to other traffic.
- Selective ACKs (SACK): Efficiently recovers from packet loss by acknowledging specific received packets out-of-order, reducing redundant retransmissions.
- Out-of-Order Reassembly: Automatically buffers and re-sequences packets received out of order, delivering a contiguous stream to the application.
- Fast Retransmit: Detects dropped packets via duplicate ACKs and resends them immediately.

# METHODS

## `connect( )`

Transitions to `SYN_SENT` state and returns the raw `ST_SYN` packet to be sent over UDP.

## `receive_packet( $data )`

Processes an incoming raw μTP packet.

- Updates congestion windows and delay metrics.
- Emits `data` or `connected` events.
- Returns a `ST_STATE` (ACK) packet if a response is required.

## `send_data( $payload )`

Fragments the payload into 1400-byte μTP data packets and returns them. Data is only sent if within the current
congestion window.

## `tick( $delta )`

Handles timers for retransmissions. If a packet has not been ACKed within the current RTO (Retransmission TimeOut), it
is resent.

## `state( )`

Returns the current connection state: `CLOSED`, `SYN_SENT`, `CONNECTED`, etc.

## `on( $event, $callback )`

Registers a handler for:

- `connected`: Handshake successful.
- `data`: contiguous payload received.
- `closed`: Connection lost or reset.

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# COPYRIGHT

Copyright (C) 2026 by Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

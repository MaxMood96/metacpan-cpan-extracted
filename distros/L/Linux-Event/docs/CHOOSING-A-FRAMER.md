# Choosing a framer

Ordered byte resources deliver bytes, not application messages. This includes
stream sockets, pipes, FIFOs, terminals, and PTYs. Choose framing from the
protocol's wire format, then declare that framing once in the concrete
Linux::Event ordered-byte subclass.

## Quick selection table

| Wire pattern | Declaration name | Typical use |
|---|---|---|
| payload followed by a marker | `Delimiter` | lines, CRLF records, sentinel protocols |
| every message is exactly N bytes | `Fixed` | fixed binary records |
| 1/2/4-byte unsigned payload length | `LengthPrefix` | configurable binary protocols |
| 4-byte network-order payload length | `U32BE` | common binary message convention |
| `length:payload,` | `Netstring` | canonical self-delimiting records |
| unsigned LEB128 length plus payload | `Varint` | compact binary protocols |
| ASCII digits, separator, payload | `DecimalLength` | RFC 6587 octet-counted syslog |
| none of these | no framer; use `on_data` | application-specific parsing |

Names are case-sensitive exact package components below
`Linux::Event::Framer`.

A resource whose wire protocol changes after negotiation may transition between
loaded subclasses with `transition_to()`. The underlying Linux resource does
not change: a stream socket remains a stream socket, a pipe remains a pipe.
Unread native bytes are preserved, and a raw stage may pass its unconsumed
suffix with `input => $bytes`.

## Delimiter

Use this when a non-empty byte sequence ends each message:

```perl
package CRLFConnection;
use parent 'Linux::Event::IO::Sock::Stream';
use Linux::Event::Framer 'Delimiter', "\r\n",
    max_frame => 1_048_576;

sub on_message ($self, $message) {
    $self->send($message);
}
```

The delimiter can contain arbitrary bytes and can cross kernel reads.
`include_delimiter => 1` includes it in inbound messages. `send($payload)`
appends it.

There is deliberately no separate `line` alias. A line protocol states its
actual delimiter directly, such as `"\n"` or `"\r\n"`.

The same declaration works for terminal line input:

```perl
package Console;
use parent 'Linux::Event::IO::TTY';
use Linux::Event::Framer 'Delimiter', "\n";
```

or a line-oriented child-process/FIFO pipe:

```perl
package PipeLines;
use parent 'Linux::Event::IO::Pipe';
use Linux::Event::Framer 'Delimiter', "\n";
```

## Fixed

Use this only when every message has exactly the same byte length:

```perl
use Linux::Event::Framer 'Fixed', size => 32;
```

`send()` rejects payloads that are not exactly `size` bytes.

## LengthPrefix

Use this for a one-, two-, or four-byte unsigned payload length:

```perl
use Linux::Event::Framer 'LengthPrefix',
    bytes          => 2,
    endian         => 'big',
    include_prefix => 0,
    max_frame      => 1_048_576;
```

`bytes` defaults to 4 and `endian` defaults to `big`. The encoded value is the
payload length, not the total prefix-plus-payload length.

## U32BE

Use this convenience family for an unsigned four-byte network-order payload
length:

```perl
use Linux::Event::Framer 'U32BE',
    max_frame => 16 * 1024 * 1024;
```

It has the same wire representation as `LengthPrefix` with `bytes => 4` and
`endian => 'big'`.

## Netstring

Use this for canonical netstrings:

```perl
use Linux::Event::Framer 'Netstring',
    max_frame => 1_048_576;
```

`send('hello')` emits `5:hello,`. The parser rejects malformed decimal lengths,
noncanonical leading zeroes, and a missing trailing comma.

## Varint

Use this when the payload length is an unsigned LEB128 integer:

```perl
use Linux::Event::Framer 'Varint',
    include_prefix => 0,
    max_frame      => 1_048_576;
```

Small messages use fewer prefix bytes. The parser rejects noncanonical,
overlong, or overflowing prefixes.

## DecimalLength

Use this when ASCII decimal digits state the payload length:

```perl
use Linux::Event::Framer 'DecimalLength',
    separator      => ' ',
    include_prefix => 0,
    max_frame      => 1_048_576;
```

The separator must be one non-digit byte. The default wire form for `HELLO` is
`5 HELLO`, matching RFC 6587 octet-counted syslog.

## If no built-in matches

Do not force an application protocol into the wrong framing family. Use raw
ordered-byte delivery and retain parser state in `on_data`:

```perl
package ProprietaryConnection;
use parent 'Linux::Event::IO::Sock::Stream';

sub on_data ($self, $bytes) {
    my $state = $self->data;
    $state->{buffer} .= $bytes;
    # Parse every complete application record now available.
}
```

This keeps application-specific parser policy in Perl without introducing a
second general framer-object contract. If a framing rule is broadly useful and
benchmarks justify native support, add it as a complete Linux::Event built-in.

## Safety limits

Set `max_frame` for untrusted framed input. Ordered-byte classes also have a
class-level `max_buffer` limit, defaulting to 8 MiB. Violations produce a
`Linux::Event::Error` with type `framing`, invoke `on_error` when defined, and
close through the normal resource lifecycle.

Any built-in framer can use explicit `message_batch_size` policy with
`on_messages` when a pipelined workload benefits from fewer Perl callback
crossings. Batching changes delivery shape, not the wire format, and partial
batches flush at the end of the current native drain rather than waiting for
future input.

See [`FRAMING.md`](FRAMING.md) for the complete declaration, transition,
batching, and native-extension contract.

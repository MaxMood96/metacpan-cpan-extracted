# Choosing a Stream framer

TCP and Unix stream sockets deliver bytes, not messages. Choose framing from
the protocol's wire format, then declare that framing once in the Stream
subclass.

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

Names are case-sensitive and are the exact final package components under
`Linux::Event::Framer`.

A connection whose wire format changes after a handshake or upgrade may use
different Stream subclasses at different stages. Use `transition_to()` rather
than forcing every stage into one parser; unread native bytes are preserved,
and a raw stage can pass its unconsumed chunk suffix with `input => $bytes`.

## Delimiter

Use this when a non-empty byte sequence ends each message:

```perl
package CRLFStream;
use parent 'Linux::Event::Stream';
use Linux::Event::Framer 'Delimiter', "\r\n",
    max_frame => 1_048_576;

sub on_message ($stream, $message) { $stream->send($message) }
```

The delimiter may contain arbitrary bytes and may cross socket reads.
`include_delimiter => 1` includes it in inbound messages. `send($payload)`
appends it.

There is deliberately no separate `line` alias. A line protocol states its
actual wire delimiter directly, such as `"\n"` or `"\r\n"`.

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
payload length, not the prefix-plus-payload length.

## U32BE

Use this convenience family for an unsigned four-byte network-order payload
length:

```perl
use Linux::Event::Framer 'U32BE',
    max_frame => 16 * 1024 * 1024;
```

It has the same wire form as `LengthPrefix` with `bytes => 4` and
`endian => 'big'`.

## Netstring

Use this for canonical netstrings:

```perl
use Linux::Event::Framer 'Netstring',
    max_frame => 1_048_576;
```

`send('hello')` emits `5:hello,`. The parser rejects malformed decimal lengths,
leading zeroes other than the canonical zero, and a missing trailing comma.

## Varint

Use this when the payload length is an unsigned LEB128 integer:

```perl
use Linux::Event::Framer 'Varint',
    include_prefix => 0,
    max_frame      => 1_048_576;
```

Small messages use fewer prefix bytes. The parser rejects non-canonical,
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
`5 HELLO`, which matches RFC 6587 octet-counted syslog.

## If no built-in matches

Do not force a protocol into the wrong framing family. Define a raw Stream and
buffer or parse in `on_data`:

```perl
package ProprietaryStream;
use parent 'Linux::Event::Stream';

sub on_data ($stream, $bytes) {
    my $state = $stream->data;
    $state->{buffer} .= $bytes;
    # Parse as many complete application records as are available.
}
```

This keeps application-specific state and policy in Perl without requiring a
per-connection framer-object protocol. If a framing rule is broadly useful and
profiling justifies it, add it to Linux::Event as a native built-in.

## Safety limits

Set `max_frame` for untrusted framed input. Stream also has a class-level
`max_buffer` transport limit, defaulting to 8 MiB. The parser reports violations
as `Linux::Event::Error` objects with type `framing`, invokes
`on_error` when defined, and closes the Stream.

See [`FRAMING.md`](FRAMING.md) for the complete declaration and extension
contract.

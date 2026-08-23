# Native framing declarations

## Public model

A framed Stream is a subclass with one declarative import and a named
`on_message` callback:

```perl
package MessageStream;
use parent 'Linux::Event::Stream';
use Linux::Event::Framer 'LengthPrefix',
    bytes => 4, endian => 'big', max_frame => 16 * 1024 * 1024;

sub on_message ($stream, $message) {
    $stream->data->{messages}++;
    $stream->send($message);
}
```

The declaration must appear after `use parent`, making both inheritance and the
protocol rule visible to readers. The import records immutable class metadata;
it does not construct a framer object.

The first Stream construction resolves the declaration and inherited callback
methods into a cached descriptor. Every connection of that class references
the same descriptor while retaining independent input, scan, output-queue, and
lifecycle state.

## Name resolution

The name is validated as a single Perl package component and expanded as:

```text
Linux::Event::Framer::<Name>
```

For example, `Delimiter` loads
`Linux::Event::Framer::Delimiter`. There is no central keyword or alias
table to keep synchronized. Misspelled or incorrectly cased names fail when the
class is compiled.

## Built-in wire contracts

| Name | Native input | Outbound `send($payload)` |
|---|---|---|
| `Delimiter` | payload through configured delimiter | appends delimiter |
| `Fixed` | exactly `size` bytes | requires exactly `size` bytes |
| `LengthPrefix` | unsigned 1/2/4-byte payload length | prepends configured binary length |
| `U32BE` | unsigned 4-byte network-order payload length | prepends network-order length |
| `Netstring` | canonical `length:payload,` | emits canonical netstring |
| `Varint` | canonical unsigned LEB128 payload length | prepends canonical LEB128 length |
| `DecimalLength` | ASCII length plus one separator byte | prepends decimal length and separator |

All lengths and limits describe bytes. Inbound boundary detection and parser
state machines run in XS. Outbound encoding is a named built-in function called
by `send()`, after which bytes enter the native write engine.

## Common options

Framers that accept `max_frame` reject larger inbound and outbound payloads.
Length-prefix families may accept `include_prefix`; `Delimiter` accepts
`include_delimiter`. These options change the message delivered to
`on_message`, not the bytes consumed from the wire.

The class-level Stream option `max_buffer` is an additional hard bound on
framed input storage. Its default is 8 MiB:

```perl
sub stream_options ($class) {
    return max_buffer => 32 * 1024 * 1024;
}
```

Choose explicit limits for untrusted protocols rather than relying only on
available process memory.

## Raw mode for application-specific protocols

A subclass without a framer must define `on_data`. It receives byte chunks as
the native read engine drains them:

```perl
package RawProtocolStream;
use parent 'Linux::Event::Stream';

sub on_data ($stream, $bytes) {
    my $state = $stream->data;
    $state->{input} .= $bytes;
    while ($state->{input} =~ s/\A([^\n]*\n)//) {
        push @{ $state->{records} }, $1;
    }
}
```

Chunk boundaries are not protocol boundaries. The callback must retain partial
state and may emit as many complete application records as are available.

Arbitrary `next_frame` objects and the former native-backed Buffer view are not
part of the API. This avoids a second framing contract, per-connection parser
objects, repeated dynamic dispatch, and XS-to-Perl boundary crossings merely to
ask where the next frame ends.

## Inheritance

A derived Stream inherits its nearest ancestor's framer declaration through
normal Perl method resolution order. It may inherit or override named
callbacks:

```perl
package AuditedMessageStream;
use parent 'MessageStream';

sub on_message ($stream, $message) {
    push @{ $stream->data->{audit_log} }, length($message);
    $stream->send($message);
}
```

Each concrete subclass gets its own cached descriptor, so its resolved callback
set is stable. It does not get a copy of immutable framing data per connection.
A class may not declare two framers or combine `on_data` with framed mode.

## Changing framing on a live connection

Negotiated and upgraded protocols may move between raw and framed Stream
subclasses with `transition_to()`:

```perl
$stream->transition_to('BinaryMessageStream', input => $remaining);
```

Unread bytes already stored by a native framer are preserved automatically and
reinterpreted under the target descriptor. The explicit `input` value is for a
raw callback's unconsumed suffix. Native buffered bytes, when present, come
first. This ordering supports a final old-protocol message followed immediately
by pipelined new-protocol bytes in the same kernel read.

The old native parser stops after the callback that changes the descriptor.
Complete target frames are then emitted without waiting for another readiness
event. Read pause survives the transition and postpones this delivery until
`resume_read()`.

The target class's `max_buffer` applies to all preserved bytes. An oversized
transition fails atomically instead of partially replacing the parser.
Existing queued output is not reframed; later `send()` calls use the target
framer, preserving protocol-response ordering across an upgrade.

## Adding a native built-in

The public declaration loader derives the implementation package from its name,
so adding a family does not require editing a keyword list. A complete built-in
still requires both sides:

1. a `Linux::Event::Framer::<Name>` module that validates declaration
   arguments and provides immutable native config plus outbound encoding;
2. a corresponding XS parser mode that handles partial input, multiple frames,
   limits, errors, pause/close reentrancy, and instrumentation;
3. contract tests for wire encoding, split input, invalid input, limits,
   independent per-connection state, and `send()`;
4. a row in `bench/run-native-framers-microbench.pl`.

The module's internal builder interface is distribution-internal and may change.
Copying a module without implementing its native parser semantics is not a new
framing family. Applications should use raw `on_data`; contributors should add
generally useful families to Linux::Event with the XS implementation and tests.

## Error behavior

Malformed or oversized input becomes a `Linux::Event::Error` with type
`framing`. Stream stores it in `last_error`, invokes the cached `on_error`
callback when present, and closes. Application callback exceptions are not
silently converted or swallowed.

## Performance model

The descriptor stores immutable parser config and resolved named CVs once per
class. XS appends bytes directly to per-connection native storage, finds every
complete built-in frame available, and crosses into Perl only to deliver
semantic messages or lifecycle errors. This removes per-read chunk scalars for
framed mode and removes per-frame parser calls whose only result would be a
boundary tuple.

Measure changes with `bench/run-framing-microbench.pl`,
`bench/run-native-framers-microbench.pl`, and the versioned lifecycle benchmark.

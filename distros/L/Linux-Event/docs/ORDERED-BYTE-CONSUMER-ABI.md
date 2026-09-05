# Native ordered-byte consumer ABI

The native consumer ABI is an extension boundary for distributions that need
complete framed messages without entering Perl through `on_message` for every
frame. It belongs to the private ordered-byte engine shared by
`IO::Pipe`, `IO::TTY`, and `IO::Sock::Stream`.

It is deliberately narrower than a transport, framer, Future, queue, or
scheduler. The core ABI contains no coroutine semantics, Future class,
continuation protocol, or cancellation policy.

The primary intended consumer is a separate higher-level async/await
distribution.

## Data path

Ordinary framed delivery is:

```text
epoll
  -> native byte transport read
  -> native framer
  -> cached on_message callback
```

A framed class with a native consumer uses:

```text
epoll
  -> native byte transport read
  -> native framer
  -> provider message function
```

The provider owns one context per ordered-byte object. It can retain an
outstanding receive, queue a result, or wake another abstraction; Linux::Event
core does not need to know the higher-level policy.

## Declaring a provider

An extension loads its native code, obtains the address of a static
`les_consumer_ops_v1_t`, and declares it on a framed concrete class through the
public extension-author support API:

```perl
Linux::Event::Framer->declare_native_consumer(
    'My::FramedConnection',
    {
        provider           => $provider_lifetime_token,
        abi_version        => 1,
        operations_address => $native_table_address,
    },
);
```

The target must inherit a Linux::Event ordered-byte leaf and also declare one
built-in native framer. A native consumer is mutually exclusive with
`on_message`, `on_messages`, and `message_batch_size`. Raw `on_data` classes
cannot attach one.

The declaration follows normal Perl MRO inheritance and becomes immutable when
the concrete class descriptor is built. The `provider` value is retained for
the descriptor lifetime so the extension and provider-owned static/native state
remain alive.

`declare_native_consumer()` is for extension authors. It does not expose an
application async API in Linux::Event core.

## Canonical C contract

The canonical ABI-v1 declarations live in
`xsbytestream/stream_consumer_abi.h`. The C filename describes the ordered-byte
engine contract and does not define the public Perl resource taxonomy.

External XS distributions should vendor the canonical versioned header and
retain the ABI version/size checks rather than including unrelated private
ordered-byte implementation headers.

The provider operations table contains:

| Function | Contract |
|---|---|
| `create` | Create one provider context for one host ordered-byte object. Return `NULL` on failure. |
| `message` | Consume one borrowed framed-message `SV *` and return a consumer status. |
| `event` | Observe the first terminal input/lifecycle event. |
| `destroy` | Release the provider context exactly once. |
| `flush` | Optional end-of-drain notification for bounded provider batching. |

The host table passed to `create` contains:

| Function | Contract |
|---|---|
| `resume` | Clear consumer pause, synchronously dispatch buffered frames when possible, and restore read interest. |
| `pause` | Stop application payload reads immediately, including while no message callback is active. |
| `stream` | Return the borrowed host Perl object `SV *`; the native ABI field retains its historical name. |
| `is_closed` | Report whether the host object is closed. |
| `retain` | Retain host state and provider context across a provider-owned reentrant frame. |
| `release` | Release a prior retain; this may destroy both contexts and must be the frame's final context access. |

Every table begins with `abi_version` and `struct_size`. Linux::Event rejects
version mismatches, structures smaller than required fields, unsupported flags,
missing provider names, and missing required functions before constructing the
host object.

The provider operations table must remain at a stable address for every cached
class descriptor that declares it.

## Optional v1 flush extension

`flush` is an optional appended ABI-v1 field. A provider requests it with
`LES_CONSUMER_F_WANT_FLUSH`. The host then requires a sufficiently large table
and a non-null function.

A host predating that extension rejects the flag, while providers compiled
against the original v1 layout remain valid when they do not request it.

The hook runs after a framed native-input drain that invoked `message` at least
once and returns the same consumer status values as `message`. This allows a
provider to retain a bounded batch and defer one higher-level wakeup until the
current native read/buffered-input drain completes.

## Host lifetime retain extension

`retain` and `release` are appended host-table ABI-v1 lifetime functions. A
provider that calls callback-capable host operations from its own XSUB or other
provider-owned frame must:

1. verify `struct_size` reaches the required retain/release fields;
2. call `retain` before entering reentrant host work;
3. guarantee matching `release` on normal return and exception unwinding;
4. perform no host/provider context access after `release`.

`release` can immediately cause provider `destroy` and host-context destruction.
The retain therefore covers the complete provider-owned frame, not merely one
call to `resume()` or `pause()`.

Retaining only the host Perl scalar is not a replacement for retaining the
native host context.

## Message ownership

The `message` argument is borrowed and valid for the duration of the provider
call. A provider that retains it increments its Perl reference count and later
releases that reference.

Retaining the same scalar transfers no payload bytes and is the intended
zero-copy-ish result path for a native receive integration.

The provider owns its context and any retained values. The host invokes
`destroy` only after native delivery has stopped and every provider-held host
lifetime retain has been released.

## Consumer statuses

`message` and requested `flush` operations return one of:

| Status | Effect |
|---|---|
| `LES_CONSUMER_CONTINUE` | Continue parsing complete frames when lifecycle permits. |
| `LES_CONSUMER_PAUSE` | Disable application payload read interest. |
| `LES_CONSUMER_CLOSE` | Close the host through normal lifecycle. |
| `LES_CONSUMER_ERROR` | Raise a fatal provider error. |

Every returned status is validated even if provider code made the host
terminal during the call. `ERROR` and out-of-range statuses remain fatal
provider failures.

After validation, a valid `CONTINUE`, `PAUSE`, or `CLOSE` result is not applied
as though it could revive a host that became terminal reentrantly.

## Pause, resume, and pull consumers

`LES_CONSUMER_F_START_PAUSED` prevents application payload reads until the
provider invokes host `resume`. This supports pull-style consumers without
forcing Linux::Event to maintain a second general message queue.

Host `pause` lets a provider withdraw an armed receive before a message arrives.
It does not close the resource or discard native/kernel-resident input.

`resume` can synchronously invoke `message` before returning when complete
frames are already buffered. Provider code must therefore establish its pending
operation state before calling `resume`.

If the provider will inspect context, call another host function, or continue
stateful work after a callback-capable host operation, it must hold the host
lifetime retain across that entire reentrant frame.

The same lifetime rule applies to `pause` when its state transition can produce
provider/application notifications.

## Delivery reentrancy

A provider can wake higher-level user code from `message`; that code may arm
the next receive immediately.

The provider should return `CONTINUE` when another receive is ready to consume
more buffered frames and `PAUSE` when no receive is armed. The host rechecks
pause, close, EOF, and descriptor state between semantic messages.

A `message` result of `CONTINUE` does not erase an independently requested
provider pause. A deferred `flush` result of `CONTINUE` can clear the
end-of-drain consumer pause and re-drive buffered input according to the
existing ABI-v1 contract.

Transport progress remains independent of consumer pause. TLS can continue
handshake/shutdown control traffic while plaintext application delivery is
paused.

## Terminal flush ordering

Entering `message` marks the current native drain as flush-owed immediately
when flush support is enabled.

If provider or user code begins terminal teardown reentrantly, the required
terminal flush runs before `message` returns and before the terminal consumer
event. The host first marks the relevant direction terminal so `resume` or
`pause` cannot restart application input.

At that terminal boundary valid `CONTINUE`, `PAUSE`, and `CLOSE` statuses do
not reopen or otherwise alter lifecycle. Invalid statuses and explicit
`ERROR` remain provider failures.

If `message` throws before terminal teardown consumes a pending flush,
exception unwinding clears the incomplete flush marker.

## Provider failure rules

`create` reports failure by returning `NULL`. `destroy` must not throw.

A `message`, `flush`, or `event` implementation that invokes Perl can propagate
an exception like an ordinary Linux::Event semantic callback. It must update
its ownership/pending-operation state before that invocation so exception
unwinding leaves the provider context valid.

An invalid status or explicit consumer error is treated as a provider bug, not
an ordinary protocol error to be ignored.

## Terminal events

The provider receives at most one terminal event for the host input/lifecycle
boundary:

| Event | Meaning |
|---|---|
| `LES_CONSUMER_EVENT_EOF` | Clean input EOF. |
| `LES_CONSUMER_EVENT_READ_ERROR` | Native transport read failure. |
| `LES_CONSUMER_EVENT_FRAMING_ERROR` | Active native framer rejected input. |
| `LES_CONSUMER_EVENT_CLOSED` | Explicit or error-driven complete close. |
| `LES_CONSUMER_EVENT_DETACHED` | Plain transport ownership was detached. |
| `LES_CONSUMER_EVENT_READ_CLOSED` | Application explicitly closed only the read direction. |

The consumer event runs before the corresponding ordinary EOF/error/close
application callback. Existing structured errors and semantic callbacks remain
active, so a higher-level integration can use them for richer error values
while using the native terminal event to settle pending provider state.

Host `resume` is rejected after terminal input state, including from a
reentrant terminal callback.

Additional terminal event codes can be appended while retaining the ABI-v1
table layout. A provider must treat an unknown event code conservatively as
terminal rather than reject it or attempt to resume input.

## Descriptor transitions

`transition_to()` can change framing while retaining one provider context only
when source and target cached descriptors use the same operations-table
pointer.

Adding, removing, or changing the native consumer provider on a live object is
rejected. Unread bytes stay in native input storage and are interpreted by the
target framer under the ordinary protocol-transition rules.

The transition also must remain within the same public resource category.

## Fairness

`read_budget_bytes` is a general ordered-byte class option. Zero preserves
drain-until-EAGAIN behavior. A positive value bounds transport bytes read in
one readiness callback; level-triggered readiness continues on a later Loop
turn.

This can be useful when a reentrant pull consumer continuously returns
`CONTINUE`, but the option is not specific to async/await and also applies to
ordinary raw/framed callback workloads.

## Stability boundary

ABI version 1 exposes only the two public native tables and constants in the
canonical consumer header. Provider code must not inspect the private native
ordered-byte state, descriptor implementation, watcher storage, input buffer,
or transport context.

New optional table fields require a larger `struct_size`. An incompatible
contract requires a new ABI version.

Historical C identifiers and the canonical header filename still use `Stream`
because they are stable native ABI names. The public Perl resource taxonomy can
change independently without gratuitously renaming those native symbols.

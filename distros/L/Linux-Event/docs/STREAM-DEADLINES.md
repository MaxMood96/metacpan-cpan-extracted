# Established Stream deadlines

Established deadlines protect a Stream after its byte transport is usable.
They do not replace the separate resolver, connection, TLS handshake, or TLS
shutdown deadlines.

## Configuration

Subclass defaults belong in the cached Stream descriptor:

```perl
sub stream_options ($class) {
    return (
        idle_timeout  => 60,
        read_timeout  => 30,
        write_timeout => 10,
    );
}
```

All values are non-negative seconds and may be fractional. Zero disables the
policy. A constructor value overrides its subclass default for one Stream:

```perl
my $stream = ClientStream->connect(
    host => $host,
    port => $port,
    idle_timeout => 120,
    read_timeout => 20,
    write_timeout => 5,
);
```

The same options work with `new(fh => $connected_socket)`. A Listener-created Stream uses the
accepted Stream subclass's `stream_options` defaults. An explicit zero
constructor value disables a nonzero subclass default. Constructor overrides
remain in force across `transition_to`; policy that was not overridden changes
to the target subclass default.

## Inactivity policies

- `idle_timeout` measures time since the latest successful transport read or
  write. `pause_read` does not suspend whole-connection idle policy.
- `read_timeout` measures time since successful inbound application bytes.
  `pause_read` suspends it and `resume_read` begins a fresh interval. Peer EOF
  permanently disarms it.
- `write_timeout` exists only while output is queued. It begins when an empty
  output queue first gains unsent bytes, resets on successful transport write
  progress, and disappears when the queue drains.

For TLS, activity means successful plaintext progress through the Stream
transport boundary. TLS handshake control traffic occurs before established
policy starts and remains governed by the provider handshake timeout.

## Overall-operation deadline

One explicit fixed deadline may coexist with inactivity policy. It can be
provided at construction:

```perl
my $stream = ClientStream->new(
    fh => $socket,
    deadline => { after => 30, operation => 'authentication' },
);
```

Or set and replaced at runtime:

```perl
$stream->set_deadline(after => 5, operation => 'response');
$stream->set_deadline(
    at => Linux::Event::Timer->now + 10,
    operation => 'request',
);
$stream->clear_deadline;
```

`after` starts when the Stream becomes usable if supplied before readiness.
`at` is an absolute `CLOCK_MONOTONIC` deadline. Ordinary reads and writes do
not extend an overall-operation deadline. `deadline` returns its active
absolute time, or undef for a detached relative deadline;
`deadline_operation` returns its label.

## Expiration and ordering

Expiration creates a `Linux::Event::Error` with:

- `type` equal to `timeout`;
- `operation` equal to `idle`, `read`, `write`, or the explicit label;
- `timeout` equal to the relative policy duration when applicable;
- `deadline` equal to the expired absolute monotonic deadline.

Stream calls `on_error` and then follows its normal terminal close path,
including `on_close`. When exact deadlines tie, an explicit operation wins,
followed by write, read, and idle policy. This ordering affects only the error
label; every expiration is terminal.

## Scheduler and hot path

Every deadline-enabled Stream owns at most one private Timer representing the
earliest applicable condition. Those Timers use the Loop's existing timerfd
and indexed native heap. No Stream creates a deadline fd and no internal Timer
is exposed publicly.

Successful native reads and writes update monotonic timestamps only when at
least one inactivity policy is enabled. A Stream with all three inactivity
values at zero performs no activity clock reads. I/O progress does not enter
Perl merely to reschedule a Timer. If progress moves a deadline, an early Timer
callback reads the latest native snapshot and reschedules itself.

Closing, detaching, failure, and Loop teardown cancel scheduler ownership.
Protocol transitions retain an explicit operation deadline and apply the
target subclass's non-overridden inactivity defaults.

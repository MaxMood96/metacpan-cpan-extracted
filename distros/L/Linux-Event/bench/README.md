# Benchmark Guide

The benchmark directory contains current reactor, callback, Timer, Signal, Stream
transport, framing, native-framer, and lifecycle measurements. Older optimization
experiments are preserved under `bench/archive/` and are not the recommended
way to measure the current implementation.

## Release performance-regression suite

`run-performance-regression.pl` is the permanent same-version-contract guard
for Linux::Event releases. It covers raw registration churn, Timer attachment,
cancellation and expiration, raw and framed Stream construction, raw and
natively framed message throughput, deadline-tracked raw Stream throughput,
and the full public `connect`/`listen` lifecycle. Every workload records median
wall rate and process CPU microseconds per operation after warmup. Workload
order rotates across repeats.

Capture a full baseline from a clean, idle machine:

```bash
perl Makefile.PL && make
perl -Mblib bench/run-performance-regression.pl \
  --json bench/results/performance-baseline.json
```

Build the candidate on the same machine and compare it with exactly the same
configuration:

```bash
perl -Mblib bench/run-performance-regression.pl \
  --baseline bench/results/performance-baseline.json \
  --threshold-percent 10 \
  --fail-on-regression \
  --json bench/results/performance-candidate.json
```

The comparison reports throughput and CPU deltas for every workload. With
`--fail-on-regression`, it exits with status 2 if median throughput falls by at
least the threshold or median CPU cost rises by at least the threshold. It
rejects baselines with a different benchmark contract or configuration.

Use `--quick` only while developing the harness. Release decisions should use
the default seven repeats and full workload sizes. Do not compare reports from
different machines, Perl builds, power modes, or competing system load.

## Timer microbenchmark

`run-timer-microbench.pl` isolates the native scheduler at increasing heap
sizes. It measures attach/cancel lifecycle, indexed-heap rescheduling, and
zero-delay expiration delivery:

```bash
perl -Mblib bench/run-timer-microbench.pl \
  --counts=1000,10000,100000 \
  --repeats=5 \
  --json=bench/results/timer-microbench.json
```

The lifecycle and reschedule rows count one operation per Timer. The expiration
row schedules an equal-deadline cohort and runs the Loop until all callbacks
have completed. Use the standard performance-regression suite for release
gating; use this benchmark to diagnose Timer-specific scaling.

## Signal microbenchmark

`run-signal-microbench.pl` measures one-at-a-time real-time signal delivery and
native fan-out at increasing subscriber counts:

```bash
perl -Mblib bench/run-signal-microbench.pl \
  --deliveries=10000 --subscribers=1,10,100 --repeats=5
```

It reports delivered signals per second, resulting Perl callbacks per second,
and process CPU microseconds per signal. The real-time signal keeps every
delivery queued; only one signal is outstanding at a time so the benchmark
measures the Loop/signalfd round trip rather than queue saturation.

## Resolver microbenchmark

`run-resolver-microbench.pl` measures the private worker/eventfd path with
batched asynchronous hostname requests. It reports aggregate resolution rate
and median submit-to-Loop-delivery latency:

```bash
perl -Mblib bench/run-resolver-microbench.pl \
  --host=localhost --requests=1000 --repeats=5
```

Use a stable local or controlled DNS target when comparing builds. Public
internet resolver latency is environment noise and is not a release gate.

## Wakeup microbenchmark

`run-wakeup-microbench.pl` measures public eventfd signalling and Loop callback
delivery at several coalescing batch sizes:

```bash
perl -Mblib bench/run-wakeup-microbench.pl \
  --signals=100000 --batch-sizes=1,16,256 --repeats=5 \
  --json=bench/results/wakeup-microbench.json
```

Each callback issues the next batch, so batch size one measures a full
signal-to-Loop round trip and larger rows expose eventfd coalescing. The report
separates logical signals from resulting Perl callbacks and includes parent CPU
microseconds per signal.

## Datagram microbenchmark

`run-datagram-microbench.pl` runs exact serial IPv4 loopback UDP echo through
connected and unconnected public Datagram objects:

```bash
perl -Mblib bench/run-datagram-microbench.pl \
  --packets=100000 --bytes=64 --modes=connected,unconnected --repeats=5 \
  --json=bench/results/datagram-microbench.json
```

The timed interval begins in client `on_ready`; construction, asynchronous
hostname resolution, and teardown are outside it. Every payload is checked and
only one request is outstanding, making packets/second, payload MiB/second, and
CPU microseconds per packet directly comparable across the two modes.

## Process microbenchmark

`run-process-microbench.pl` measures `posix_spawnp`, pidfd registration,
reaping, and `on_exit` delivery for a no-output executable:

```bash
perl -Mblib bench/run-process-microbench.pl \
  --program=/bin/true --processes=1000 --concurrency=1,8,32 --repeats=5 \
  --json=bench/results/process-microbench.json
```

It reports complete child lifecycles per second and parent CPU microseconds per
child. Keep the executable, concurrency, libc, kernel, process limits, and host
load identical when comparing reports.

## Listener lifecycle microbenchmark

Run the permanent inbound connection benchmark from the distribution root:

```bash
perl -Mblib bench/run-listen-microbench.pl \
  --clients=1,10,100 \
  --connections=10000 \
  --repeats=9 \
  --timeout=30
```

All rows create loopback clients through `MyStream->connect`. The `manual` row
uses explicit socket setup, `Loop->watch`, Perl `accept`, and close. The `add`
row constructs a detached `Linux::Event::Listener` and attaches it with
`Loop->add`. The `loop` row passes `loop => $loop` directly to the Listener
constructor. Both public rows automatically construct and close the same
minimal Stream subclass. Execution order rotates across repeats, so use a
repeat count divisible by three for a balanced run.
The script reports median accepts per second and process CPU microseconds per
accepted connection. The timeout is a per-request catastrophic safeguard, not
the duration of a benchmark row; increase it on a heavily loaded host rather
than allowing deadline failures to truncate the workload. Every row uses the
same abortive client-close policy. This is intentional: hundreds of thousands
of short sequential TCP connections would otherwise accumulate client-side
`TIME_WAIT` sockets and make later rows measure ephemeral-port exhaustion.

## Stream connection lifecycle microbenchmark

Run the permanent outbound connection benchmark from the distribution root:

```bash
perl -Mblib bench/run-connect-microbench.pl \
  --clients=1,10,100 \
  --connections=10000 \
  --repeats=6 \
  --timeout=30 \
  --json=bench/results/connect-lifecycle.json
```

It uses loopback TCP and reports median connections per second plus process CPU
microseconds per completed connection. The `manual` row uses a raw nonblocking
socket and opaque Loop registration. The `add` row constructs a detached
Stream and calls `Loop->add`; the `loop` row passes `loop => $loop` directly to
`MyStream->connect`. Both Stream rows close that same object from `on_ready`.
Connection setup and teardown are timed; this
is intentionally separate from the established-connection Stream and TLS
message benchmark. Both rows use abortive connected-client teardown to avoid
TIME_WAIT exhaustion. Their order rotates across repeats; use a repeat count
divisible by three for balanced execution order. The timeout is a per-request catastrophic
deadline rather than a benchmark-row duration.

## 1. Permanent reactor comparison

`run-reactor-comparison.pl` is the canonical same-work comparison.

Default leaderboard:

1. Linux::Event XSLoop
2. EV
3. AnyEvent `AE::io` on EV
4. `UV::Poll`
5. `IO::Async::Loop::Epoll`
6. `Mojo::Reactor::Epoll`

Diagnostic AnyEvent variants are still selectable but are not part of the
default leaderboard.

### Fairness contract

Every ranked system receives the same workload:

- TCP IPv4 loopback
- all connections established and accepted before timing
- watcher registration outside timing
- identical named Perl `echo_read()` function
- `sysread($fh, $buffer, 8192)` drain logic
- identical `syswrite` loop
- serial request/reply: at most one outstanding message per client
- warmup outside timing
- teardown outside timing
- no framework timeout watcher during timing
- fresh process for each system/client/repeat case
- parent process provides catastrophic timeout protection
- balanced rotating execution order

The benchmark checks exact messages/bytes and rejects cases with client
failures, partial writes, unexpected closes, or write EAGAIN.

### Dependencies

Build Linux::Event first and check installed competitor versions:

```bash
perl bench/run-reactor-comparison.pl --build --check-deps
```

Typical dependency installation:

```bash
cpanm EV AnyEvent UV IO::Async IO::Async::Loop::Epoll Mojolicious Mojo::Reactor::Epoll
```

### Recommended reference run

Increase the open-file limit before high-client tests:

```bash
ulimit -n 100000
```

Then:

```bash
perl bench/run-reactor-comparison.pl --build \
  --systems linuxevent,ev,anyevent-ae,uv,ioasync-epoll,mojo-epoll \
  --clients 1000,5000,10000,20000 \
  --warmup 1 \
  --messages 100 \
  --bytes 64 \
  --client-workers 4 \
  --repeats 6 \
  --timeout 180 \
  --out bench/results/reactor-comparison.html \
  --json bench/results/reactor-comparison.json
```

Six repeats matter when the default six systems are selected: each system then
occupies every execution position exactly once at each client scale.

### Reading the report

The JSON contains raw records, summary records, the fairness contract, backend
information, CPU, RSS, latency, syscall/callback counters, and correctness
fields.

The HTML is self-contained and works without a web server or internet access.
It provides:

- click-to-sort on every table header
- text search across result rows
- exact system filter
- exact client-count filter
- reset button
- visible-row counter

For close reactor comparisons, prefer **server CPU microseconds/message** over
small differences in wall-clock msg/s. Wall throughput is more sensitive to
client-worker scheduling and machine load.

Do not compare `reactor_iterations` across unrelated frameworks unless their
counters have identical semantics. `n/a` is intentional when a backend does
not expose a comparable counter.

## 2. Callback/I/O decomposition diagnostic

`run-callback-ceiling.pl` exists to study where echo CPU is spent. It separates
native echo, empty Perl callback entry, and the normal Perl read/write body.
It is a diagnostic tool, not the public competitor leaderboard.

## Historical experiments

`bench/archive/` contains the scripts used during earlier optimization phases,
including capacity, watcher reclaim/reuse, older comparison harnesses, and EV /
AnyEvent studies. They are retained to make the research reproducible but may
refer to phase-era names and assumptions.

## 3. Stream transport comparison

`run-stream-microbench.pl` compares direct raw-reactor echo with raw
subclass-defined Streams using the same AF_UNIX request/reply workload. The
Stream rows cover the default unlimited output queue, an otherwise identical
class with a 16 MiB `max_pending_bytes` limit, and a class with an enabled idle
deadline. These comparisons guard the optional hard-limit branch, the disabled
deadline fast path, and the cost of native activity tracking. The same
benchmark guards the specialized `plain` provider path as the native transport
contract evolves. This is not the public cross-runtime leaderboard.

```bash
perl -Mblib bench/run-stream-microbench.pl \
  --clients=1,10,100,1000 --warmup=10 --messages=100 \
  --bytes=64 --repeats=8
```

Use a repeat count divisible by four so every implementation occupies every
execution position equally.

`run-tls-microbench.pl` is the permanent established-connection comparison
between the same subclass-defined Stream using its specialized `plain`
transport and the OpenSSL `Linux::Event::TLS` provider. Construction
and handshake occur before timing; the measured interval covers equal 64-byte
request/reply messages. The provider is part of the main build:

```bash
perl Makefile.PL && make
perl -Mblib bench/run-tls-microbench.pl \
  --clients=1,10,100 --messages=1000 --warmup=100 --repeats=6 \
  --json=bench/results/stream-plain-vs-tls.json
```

The repository test certificate is the default identity. A packaged benchmark
outside this checkout can use `--cert-file` and `--key-file` to supply an
equivalent localhost certificate and private key.

## 4. Framing measurements

`run-framing-microbench.pl` compares two canonical Stream subclasses on the
same delimiter wire protocol:

- `raw-on-data` buffers and searches for boundaries in the named Perl callback
- `native-delimiter` uses the built-in native Delimiter parser

Both use the same XS read/write engine. This isolates the practical reason to
add a general framing family natively while preserving raw `on_data` as the
fallback for application-specific protocols.

`run-native-framers-microbench.pl` measures each canonical native built-in
through a declarative Stream subclass. The current matrix is Delimiter, Fixed,
LengthPrefix, U32BE, Netstring, Varint, and DecimalLength. There is no custom
Perl parser mode or factory-object row in the current API.

```bash
perl -Mblib bench/run-native-framers-microbench.pl \
  --framers=delimiter,fixed,length,u32be,netstring,varint,decimal \
  --clients=1,10,100 --warmup=10 --messages=100 --bytes=64 --repeats=6
```

Compare framer rows only at identical payload sizes, client counts, host load,
and build flags. Different wire formats have different prefix sizes and parser
work.

## 5. Stream lifecycle and retained memory

`run-stream-lifecycle-bench.pl` is the versioned construction and retained
memory measurement for the subclass-descriptor architecture. It reports:

- construction/detach operations per second and process CPU microseconds per
  operation over pre-created socketpairs
- retained RSS delta for live objects in fresh child processes after socket,
  loop, and retention-vector setup

Benchmark contract 2 compares the two supported attachment styles. The current
default is `loop-add`; `framed-full-named` is the primary comparable case.
`registration` is an opaque native-registration floor, not a Stream
feature-equivalence claim.

Build, raise the file-descriptor limit, and run the after snapshot with the same
settings used for the baseline:

```bash
perl Makefile.PL
make
ulimit -n 100000
perl -Mblib bench/run-stream-lifecycle-bench.pl \
  --api-style=loop-add \
  --iterations=100000 \
  --pool=256 \
  --live=1000,10000,20000 \
  --warmup=1000 \
  --repeats=7 \
  --memory-repeats=3 \
  --json=bench/results/stream-lifecycle-after.json
```

`loop-add` measures detached Stream construction followed by `Loop->add()`.
`loop-option` passes `loop => $loop` to the Stream constructor. Both are current
public APIs. Historical contract-1 results remain useful as release baselines,
but are not mechanically interchangeable with contract 2. Compare JSON files only when
`benchmark_contract_version`, `workload`, case list, iteration counts, live
counts, Perl, compiler flags, and machine are equivalent.

For `framed-full-named`, compare median CPU time per operation first, then
operations/second and retained bytes/object. RSS is page-granular, so the larger
live counts are the meaningful memory samples. Each socketpair consumes two
file descriptors; increase `ulimit -n` or lower `--live` if creation fails.

## 6. Live protocol transitions

`run-stream-transition-bench.pl` measures descriptor changes on already-live
Streams. Every timed operation calls `transition_to()` and retains the same fd,
watcher, XSState, output queue, lifecycle, and application data. No bytes are
injected, so this benchmark isolates shared-descriptor replacement and the raw
scratch-buffer allocation required by the target mode.

The contract-1 cases are:

- `raw-raw`: both target classes use raw delivery
- `framed-framed`: Delimiter and Fixed native parsers
- `raw-framed`: alternates raw scratch allocation and release

```bash
perl -Mblib bench/run-stream-transition-bench.pl \
  --iterations=1000000 \
  --pool=256 \
  --warmup=10000 \
  --repeats=7 \
  --json=bench/results/stream-transition.json
```

Transitions are normally rare semantic operations, so this is primarily a
regression and architecture benchmark rather than a throughput leaderboard.
Compare CPU microseconds per transition first and keep the contract, cases,
pool size, Perl, compiler flags, and host identical.

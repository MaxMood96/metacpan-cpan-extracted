# Benchmark Guide

Linux::Event keeps permanent benchmark harnesses for the reactor, public
IO/Kernel resources, ordered-byte engine, framing, TLS, process I/O, and
release-regression decisions. Older one-off experiments live under
`bench/archive/` and are not the recommended release gates.

Some script filenames predate the 0.110 public taxonomy. Names such as
`run-stream-*`, `run-wakeup-*`, and `run-datagram-*` are retained engineering
tool names so historical result sets remain comparable. They do **not** make
`Linux::Event::Stream`, `Linux::Event::Wakeup`, or
`Linux::Event::Datagram` public application classes. Current application code
uses `Linux::Event::IO::*` and `Linux::Event::Kernel::*`.

Some low-level benchmark rows also deliberately instantiate retained private
implementation hosts to measure native-engine overhead. Those rows are
implementation baselines, not API examples.

## Release performance regression

`run-performance-regression.pl` is the permanent release gate. Capture the
baseline and candidate on the same idle machine, with the same Perl build and
system configuration:

```bash
perl Makefile.PL && make
perl -Mblib bench/run-performance-regression.pl \
  --json bench/results/performance-baseline.json
```

Then build the candidate and compare:

```bash
perl -Mblib bench/run-performance-regression.pl \
  --baseline bench/results/performance-baseline.json \
  --threshold-percent 10 \
  --fail-on-regression \
  --json bench/results/performance-candidate.json
```

The full suite uses seven repeats and covers reactor registration, timer
lifecycle/expiration, ordered-byte lifecycle and throughput, native framing,
deadline-enabled ordered-byte throughput, and stream-socket connect/listener
lifecycle. It reports wall throughput and process CPU cost. A baseline with a
different benchmark contract/configuration is rejected.

Use `--quick` only while developing the harness. Release decisions should use
the full default workload.

## Public-surface overhead

`run-public-api-overhead.pl` is repository engineering tooling used to compare
retained private implementation hosts with the 0.110 public leaves on the same
build. It is intentionally excluded from the CPAN distribution.

Its purpose is to catch overhead introduced by semantic wrappers such as
`IO::Pipe` and `IO::Sock::Stream`; it is not a user-facing API benchmark.
Large 200 KB stream-socket payloads are measured with a dedicated longer run so
tiny sample sizes cannot decide the median.

## Reactor comparison

`run-reactor-comparison.pl` compares the low-level reactor with equivalent
poller/readiness APIs in other event systems. This is deliberately separate
from the high-level stream-socket comparison.

Typical reference run:

```bash
ulimit -n 100000
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

The fairness contract keeps TCP loopback, connection setup, registration,
warmup, payload size, request/reply behavior, correctness checks, teardown, and
execution-order rotation comparable across systems.

## Stream-socket competitor plan

`STREAM-COMPETITOR-PLAN.md` defines the high-level comparison contract for
`Linux::Event::IO::Sock::Stream` against framework stream abstractions such as
AnyEvent::Handle, IO::Async::Stream, Mojo stream facilities, Node.js
`net.Socket`, and Python asyncio streams/protocols.

Raw and delimiter-framed rankings remain separate. Framework buffering and
backpressure are part of the measurement because they are part of what an
application actually uses.

## Ordered-byte payload sweep

`run-stream-payload-sweep.pl` measures established ordered-byte receive
performance across the permanent 64 B through 200 KB matrix. The historical
filename refers to the shared native ordered-byte engine; interpret application
results through `IO::Pipe`, `IO::TTY`, or `IO::Sock::Stream` as appropriate.

```bash
perl -Mblib bench/run-stream-payload-sweep.pl \
  --modes=raw,delimiter --repeats=5 --warmup=1 \
  --variant=baseline --commit=COMMIT_SHA \
  --output=bench/results/stream-payload-sweep.json
```

The report records receiver/producer CPU, throughput, native reads/writes, Perl
callback counts, buffering peaks, and effective ordered-byte/socket settings.
This is a saturated one-way local throughput benchmark, not a latency test.

## Ordered-byte lifecycle and transition diagnostics

The following harnesses target specific private engine properties while public
classes remain `IO::Pipe`, `IO::TTY`, and `IO::Sock::Stream`:

- `run-stream-lifecycle-bench.pl` — object construction/teardown and retained
  state costs.
- `run-stream-microbench.pl` — established ordered-byte callback throughput.
- `run-stream-transition-bench.pl` — in-place protocol/framer transitions.
- `run-stream-watcher-state-bench.pl` — readiness-interest state transitions.
- `run-callback-ceiling.pl` — callback-delivery ceiling diagnostics.

These are implementation diagnostics. Do not copy private class names from a
benchmark row into application code.

## Callback batching

`run-callback-batching-microbench.pl` compares ordinary raw/framed callbacks
with explicit raw-byte and framed-message batching:

```bash
perl -Mblib bench/run-callback-batching-microbench.pl \
  --messages=1000000 --bytes=64 --read-size=4096 \
  --raw-batch-bytes=0,16384,65536,262144 \
  --message-batch-sizes=0,1,4,16,32,64,256 \
  --transports=unix,tcp --warmup=1 --repeats=7 \
  --json=bench/results/callback-batching.json
```

Zero selects ordinary callback behavior. Partial batches flush at the current
native drain boundary; they do not wait for future readiness merely to fill a
configured batch.

`run-callback-batching-fairness.pl` places a timestamped fixed-frame probe next
to a continuously readable ordered-byte workload and reports hot-path
throughput plus probe p50/p99/maximum latency:

```bash
perl -Mblib bench/run-callback-batching-fairness.pl \
  --duration=0.5 --ping-interval-us=2000 --bytes=64 --read-size=4096 \
  --batch-sizes=0,16,32,64 --transports=unix,tcp \
  --warmup=1 --repeats=5 \
  --json=bench/results/callback-batching-fairness.json
```

This is a deliberate saturation/fairness diagnostic rather than ordinary
network latency.

## Framing

`run-framing-microbench.pl` and `run-native-framers-microbench.pl` measure the
built-in framing families and native parser path.

`run-framer-send-bench.pl` measures the complete framed outbound path: Perl
prefix encoding, native submission/queueing, Loop-driven `writev` draining,
and peer receipt.

```bash
perl -Mblib bench/run-framer-send-bench.pl \
  --framers=length,varint --repeats=5 --warmup=1 \
  --variant=candidate --commit=COMMIT_SHA \
  --output=bench/results/framer-send.json
```

Framing is an ordered-byte capability and applies to public Pipe, TTY, and
stream-socket leaves.

## Native consumer lifetime

`run-async-consumer-lifetime-bench.pl` exercises the external
Linux::Event::Async native consumer against the core ordered-byte consumer ABI.
Use paired core/Async builds in `PERL5LIB`:

```bash
PERL5LIB=/path/to/async/blib/lib:/path/to/async/blib/arch:\
/path/to/core/blib/lib:/path/to/core/blib/arch:$PERL5LIB \
perl bench/run-async-consumer-lifetime-bench.pl \
  --repeat=5 --warmup=1 --variant=candidate \
  --core-commit=CORE_SHA --async-commit=ASYNC_SHA \
  --output=bench/results/async-consumer-lifetime.json
```

The benchmark is a saturated local throughput/lifetime diagnostic. It does not
claim request/response latency percentiles.

## Timer

`run-timer-microbench.pl` isolates the shared timerfd/indexed-heap scheduler used
by public `Linux::Event::Kernel::Timer` objects:

```bash
perl -Mblib bench/run-timer-microbench.pl \
  --counts=1000,10000,100000 \
  --repeats=5 \
  --cpu-clock=auto \
  --json=bench/results/timer-microbench.json
```

It measures attach/cancel lifecycle, rescheduling, and equal-deadline
expiration. Use the release regression suite for release gating and this
harness for Timer-specific scaling diagnosis.

## Signal

`run-signal-microbench.pl` measures public `Linux::Event::Kernel::Signal`
delivery and native fan-out at increasing subscriber counts:

```bash
perl -Mblib bench/run-signal-microbench.pl \
  --deliveries=10000 --subscribers=1,10,100 --repeats=5
```

The benchmark uses one-at-a-time real-time signals so it measures the
Loop/signalfd round trip rather than queue saturation.

## Event

`run-wakeup-microbench.pl` retains its historical filename but measures the
eventfd engine exposed publicly as `Linux::Event::Kernel::Event`:

```bash
perl -Mblib bench/run-wakeup-microbench.pl \
  --signals=100000 --batch-sizes=1,16,256 --repeats=5 \
  --json=bench/results/wakeup-microbench.json
```

Batch size one measures a full signal-to-Loop round trip; larger batches expose
eventfd coalescing. Logical signals and Perl callbacks are reported separately.

## Resolver

`run-resolver-microbench.pl` measures the private asynchronous hostname resolver
worker/eventfd service:

```bash
perl -Mblib bench/run-resolver-microbench.pl \
  --host=localhost --requests=1000 --repeats=5
```

Use a stable local or controlled DNS target. Public internet resolver latency is
environment noise and is not a release gate.

## Dgram

`run-datagram-microbench.pl` retains its historical filename and measures public
`Linux::Event::IO::Sock::Dgram` connected and unconnected UDP echo:

```bash
perl -Mblib bench/run-datagram-microbench.pl \
  --packets=100000 --bytes=64 --modes=connected,unconnected --repeats=5 \
  --json=bench/results/datagram-microbench.json
```

Every payload is checked and only one request is outstanding, making
packets/second and CPU cost comparable across modes.

## Process

`run-process-microbench.pl` measures public
`Linux::Event::Kernel::Process` spawn/pidfd/reap/`on_exit` lifecycle:

```bash
perl -Mblib bench/run-process-microbench.pl \
  --program=/bin/true --processes=1000 --concurrency=1,8,32 --repeats=5 \
  --json=bench/results/process-microbench.json
```

`run-process-pipe-drain-bench.pl` isolates native stdout/stderr pipe draining:

```bash
perl -Mblib bench/run-process-pipe-drain-bench.pl \
  --engines=perl,native --streams=stdout,stderr,both \
  --workers=1,8,32 --read-sizes=4096,65536 \
  --bytes-per-stream=16777216 --warmups=1 --repeats=7 \
  --json=bench/results/process-pipe-drain.json
```

The `perl` engine is a retained benchmark reference only; `native` is the
production path. `--heartbeat-us=1000` adds a recurring `Kernel::Timer` fairness
probe under saturated process output.

## Listener lifecycle

`run-listen-microbench.pl` measures inbound stream-socket acquisition:

```bash
perl -Mblib bench/run-listen-microbench.pl \
  --clients=1,10,100 \
  --connections=10000 \
  --repeats=9 \
  --timeout=30
```

The public rows exercise `Linux::Event::IO::Sock::Listener` and construct the
same minimal `IO::Sock::Stream` subclass for accepted connections. A manual row
provides an explicit socket/`Loop->watch`/Perl `accept` baseline. Execution order
rotates across repeats.

The benchmark uses abortive client close deliberately so very large short-lived
TCP matrices do not turn later rows into ephemeral-port/TIME_WAIT tests.

## Outbound stream-socket connection lifecycle

`run-connect-microbench.pl` measures outbound acquisition through public
`IO::Sock::Stream->connect()` against a raw nonblocking socket baseline:

```bash
perl -Mblib bench/run-connect-microbench.pl \
  --clients=1,10,100 \
  --connections=10000 \
  --repeats=6 \
  --timeout=30 \
  --json=bench/results/connect-lifecycle.json
```

Connection setup and teardown are timed; established-message throughput belongs
to the ordered-byte/TLS benchmarks. The timeout is a catastrophic per-request
safeguard rather than a benchmark-row duration.

## TLS

`run-tls-microbench.pl` compares established plain and OpenSSL transport paths
for public `IO::Sock::Stream` subclasses. TLS handshake cost is a separate
lifecycle concern unless a benchmark mode explicitly includes it.

Use the same certificate fixtures, OpenSSL build, Perl build, socket-buffer
settings, and host state when comparing reports.

## Benchmark decision records

Release-impacting performance decisions should preserve raw evidence and a
short rationale under `bench/decisions/`. `BENCHMARK-DECISIONS.md` is
engineering history and is intentionally excluded from CPAN distribution
artifacts.

A useful decision record includes:

- baseline and candidate commit SHAs;
- exact command/configuration;
- machine/runtime information;
- raw JSON reports and checksums;
- throughput and CPU deltas;
- the resulting KEEP/REJECT/INVESTIGATE decision.

Do not compare results from different hosts as though they were a controlled
before/after benchmark.

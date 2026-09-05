# Stream-socket competitor benchmark plan

The high-level stream-socket comparison must measure application stream
abstractions, not merely their underlying poller. Linux::Event's reactor
comparison remains a separate suite.

## Candidate systems

Perl stream layer:

- `Linux::Event::IO::Sock::Stream`
- `AnyEvent::Handle` on the EV backend
- `IO::Async::Stream` on `IO::Async::Loop::Epoll`
- `Mojo::IOLoop::Stream` / low-level Mojo stream facilities

Other runtimes:

- Node.js `net.Socket`
- Python `asyncio` stream/protocol implementation

Additional Perl/native bindings can be added only when the work performed maps
cleanly to the same contract.

## Benchmark categories

### Raw stream-socket echo

Each server receives bytes through its normal high-level stream abstraction and
writes the same bytes back. Framework buffering/backpressure machinery is part
of the result because that is what an application actually uses.

### Delimiter-framed message echo

Each server receives complete messages separated by the same arbitrary binary
delimiter and sends the same framed payload back. Use the best idiomatic
framing mechanism available in that runtime. This measures the practical cost
of obtaining message semantics, not just socket readiness.

Keep raw and framed rankings separate.

## Fairness contract

- TCP IPv4 loopback
- server and client driver in separate processes
- connections established before timing
- watcher/stream setup before timing
- warmup before timing
- serial one outstanding request per client
- fixed payload and exact byte counts
- clients remain connected through timing
- teardown after timing
- fresh server process per case
- balanced execution order
- identical client driver for every server when possible
- report server CPU time/message, throughput, p50/p95/p99, and RSS
- record runtime/module/backend versions in result JSON
- fail a case on byte/message mismatch, disconnect, timeout, or protocol error

The comparison should not force every runtime to mimic Linux::Event internals.
It should require the same observable application work while allowing each
runtime's recognizable stream abstraction to do that work in its intended way.
For Linux::Event, the tested application surface is the public
`IO::Sock::Stream` leaf, not the retained private historical Stream engine.

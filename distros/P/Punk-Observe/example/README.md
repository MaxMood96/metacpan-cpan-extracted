# The Punk::Observe demo

Three Punk applications on localhost: a shop, the card processor it calls,
and the receiver that watches both.

    ./bin/demo

That starts everything, drives real traffic through the shop, breaks the card
processor in the middle, and fixes it again. Ctrl-C stops it.

    ./bin/demo --seconds 60      how long the traffic runs
    ./bin/demo --no-traffic      just start the servers
    ./bin/traffic --seconds 120  drive an already-running demo

## What is actually happening

    bin/traffic  --HTTP-->  shop  --HTTP-->  cards
                             |                 |
                             +----- OTLP ------+
                                      |
                                      v
                                   observe

Nothing in this demo fabricates telemetry. `bin/traffic` makes real HTTP
requests with `Fetch`; the shop makes a real HTTP call to the card processor;
and every span the receiver sees was produced by the instrumentation because
the two applications each contain these two lines:

    otel service_name => 'shop';
    plugin 'OpenTelemetry';

That is the whole instrumentation. No manual spans on the request path, no
timing code, no logger threaded through the controllers.

## The receiver

`observe/lib/Demo/Observe.pm` is the part this demo exists to show:

    plugin 'Observe' => {
        prefix => '/observe',
        guard  => \&_demo_guard,          # not optional
        store  => 'var/store',
        ingest => { prefix => '/v1' },
        limits => { series => 100_000, attributes => [ ... ] },
    };

Comment out `guard` and the application **refuses to boot**. That is
deliberate: an unguarded mount is every log line the shop has ever written,
served to anybody who finds the prefix.

The demo's guard lets everybody in and says so in a comment. A real one is
whatever already protects your admin pages.

## The incident

A third of the way through the run, `bin/traffic` calls:

    PUT /incident?on=1

on the card processor, which then takes about three seconds to answer and
fails roughly half the time. Two thirds of the way through it is switched
back. You can drive that yourself:

    curl -X PUT '127.0.0.1:5002/incident?on=1'
    curl -X PUT '127.0.0.1:5002/incident?on=0'

The traffic driver prints a character per request - `.` for a 2xx, `4` for a
4xx, `!` for a 5xx - so the incident is visible as it happens.

## What to look at

    curl -s 127.0.0.1:5001/stats

All three signals arrive - a run of thirty seconds produces roughly

    5 POST /v1/logs   116 POST /v1/metrics   29 POST /v1/traces

`/stats` is the raw view; `/observe` is the rendered one. Everything on
both came out of real OTLP. During a run it shows both service names, the routes by **pattern** (`/product/:id`, never
`/product/7` - one series, not one per product), and the slowest spans:

    "slowest": [
      { "service": "cards", "name": "POST /authorize", "ms": 3262 },
      { "service": "cards", "name": "POST /authorize", "ms": 2897 },
      ...
      { "service": "cards", "name": "POST /authorize", "ms": 59 }
    ]

Three seconds against a healthy fifty-nine milliseconds, on one service, is
the incident - and it is on `cards` rather than on `shop`, which is the
question a service map exists to answer.

The durable copy is a write-ahead log per worker:

    ls var/store/default/wal/       one log per worker
    ls var/store/summary/           one summary per worker

The receiver runs a real prefork pool (`--workers 4`), and both directories
show it. Each worker appends to its own log with no lock; that is the storage
design, and running a single worker to make the demo tidy would have hidden
it.

The summaries are the same shape applied to the demo's own counters. A
counter in one worker's memory is a SHARD of the traffic, so refreshing
`/stats` would show a different quarter each time and look exactly like data
being lost. Each worker publishes its summary once per batch and the read
side merges every file it finds - so the page is stable whichever worker
answers it.

Logs from each process are in `var/`.

## Pointing something else at it

The receiver speaks OTLP, so anything that exports OTLP works:

    OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:5001 \
    OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
      your-app

The endpoint is the **base**. An exporter appends `/v1/traces`,
`/v1/metrics` and `/v1/logs` itself; those paths are fixed by the
specification. Putting `/v1` in the endpoint too gives `/v1/v1/traces` and a
404 that looks like a broken receiver.

`http/json` works as well, and is easier to read when something is wrong.

## The UI

    http://127.0.0.1:5001/observe

The screens are served by the plugin from the distribution's own templates
and stylesheet, behind the guard. `/observe/traces` shows the slowest spans
as a waterfall - during an incident that is `POST /checkout` at three
seconds, against fifty milliseconds either side of it.

The numbers come from the store, through the query engine - the same path a
question typed into `/observe/explore` takes. The application supplies
nothing, which is the only honest arrangement: a `stats` callback that made
the figures up would be showing the application's opinion of its telemetry
rather than the telemetry.

The charts are drawn in the browser from a figure the server computes, and
the library that draws them is served from the mount rather than a CDN. The
waterfall, the flamegraph and the service map are still laid out on the
server and are correct with scripting switched off.

`/observe/alerts` has two rules, declared in `observe/lib/Demo/Observe.pm`:

    error rate     spans | where status = 2 | bucket(30s) count by service
    slow checkout  spans | where service = "shop" | bucket(30s) p95

Both are evaluated over the run by the real evaluator, so their states are
what actually happened rather than what this file says. The first is grouped
`by service`, which is what makes `cards` and `shop` carry their own state -
one recovering cannot resolve the other. The timeline above the table is
drawn from the transitions, so a rule that flapped looks nothing like one
that broke once.

## What this demo does not show yet

**A database for the configuration.** Alert rules and dashboards belong in
one - `sqitch/` ships the schema - and this demo has none. The rules on the
alerts screen are declared in `observe/lib/Demo/Observe.pm` instead.

What they are *not* is faked: each one is a real query, evaluated over the
real spans by the real evaluator, so the states on that screen are what this
run actually did. Break the card processor and watch one go pending, then
firing, then back to ok.

**Exponential histograms and summaries.** Explicit histograms decode into
cumulative `_bucket` series labelled by `le`, plus `_sum` and `_count`, so a
percentile merges exactly from the buckets. An exponential histogram's
buckets are base-2 rather than explicit and have to be computed from a scale
first; a summary carries pre-computed quantiles that cannot be merged across
points at all. Both are skipped rather than half-decoded.

## The pieces

    shop/      a Punk app, instrumented. `punk new Demo::Shop`
    cards/     the dependency that breaks. `punk new Demo::Cards`
    observe/   mounts Punk::Plugin::Observe. `punk new Demo::Observe`
    bin/demo   starts all three and drives them
    bin/traffic  mock user traffic, on its own or driven by bin/demo

Each application was generated with `punk new` and then edited, so the
diff from a fresh skeleton is the interesting part.

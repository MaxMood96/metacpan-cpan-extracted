package Demo::Shop;

use strict;
use warnings;
use Punk;
use Punk::Plugin::OpenTelemetry;

our $VERSION = '0.01';

config 'config/punk.yml';

# THE INSTRUMENTATION IS TWO LINES, and that is the point of the demo. Nothing
# below this knows it is being observed: no manual spans on the hot path, no
# timing code, no logger threaded through the controllers.
#
# The endpoint is left to OTEL_EXPORTER_OTLP_ENDPOINT so the same file runs
# against the observe app beside it, against a vendor, or against nothing at
# all - with no endpoint configured the plugin exports nothing and costs
# nothing.
otel service_name => 'shop',
     resource_attributes => { 'deployment.environment' => 'demo' };

plugin 'OpenTelemetry';

# DEBUG, so the demo has something to filter.
#
# A line below the configured level costs nothing - the threshold is read
# before anything is formatted - so this is the demo deliberately turning the
# quiet ones on. It is also what makes `log | where severity >= warn` a
# filter that removes something rather than a filter over one severity.
#
# The logger is the LOGS SIGNAL. Nothing below calls a telemetry-specific
# logging function: the plugin taps this logger, so every line here is
# exported carrying the trace id of the request that wrote it - and still
# goes to the log as well.
logging level => 'debug';

# DELTA, not cumulative.
#
# A cumulative exporter re-sends the WHOLE series on every collection: the
# same histogram bucket, with a new timestamp, every five seconds for as long
# as the process runs. The receiver stores records, so it stores every one of
# them - a fifty-second demo run wrote four hundred thousand metric points
# describing about three thousand requests, and one bucket appeared fifty-four
# thousand times.
#
# Delta sends only what changed since the last collection, which is what a
# store of records wants. Cumulative is right for a backend that keeps the
# last value per series and can afford to be told it repeatedly; this one is
# not that, and the demo should not pretend otherwise.
otel temporality_preference => 'delta';

# The outbound agent. One per worker, on the worker's loop, so a call to the
# card processor parks the request rather than blocking the process - and the
# connection to it is pooled rather than rebuilt per checkout.
# LONGER THAN THE INCIDENT, deliberately.
#
# The acquirer takes about three seconds when it is broken, and the demo is
# about a service that is SLOW rather than one that is gone. A five-second
# timeout looks right until the card processor's own workers are all busy
# waiting on it - then the queue pushes past five seconds, the shop gives up
# first, and every failure reads as "payments unreachable" instead of the
# authorisation failure it actually was.
ua timeout => 15;

# Routes are named for their PATTERN, never for the path. `GET /product/:id`
# is one series; `GET /product/7` would be one series per product, which is
# the cardinality mistake no dashboard recovers from - and is exactly what
# this distribution's indexed-attribute allowlist exists to survive.
get  '/'             => 'Web::Shop#index',    { name => 'home'     };
get  '/product/:id'  => 'Web::Shop#product',  { name => 'product'  };
get  '/cart'         => 'Web::Shop#cart',     { name => 'cart'     };
post '/checkout'     => 'Web::Shop#checkout', { name => 'checkout' };
get  '/health'       => sub { $_[0]->json({ ok => 1 }) };

1;

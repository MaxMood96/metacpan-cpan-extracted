package Demo::Shop::Controller::Web::Shop;

use strict;
use warnings;
use parent 'Punk::Controller';
use Time::HiRes ();
use Punk::Plugin::OpenTelemetry ();

our $VERSION = '0.01';

our $CARDS = $ENV{DEMO_CARDS_URL} || 'http://127.0.0.1:5002';

# ALL THREE SIGNALS, not just traces.
#
# The plugin opens the server span for us. Metrics and log records it emits
# "when they are asked for", so the application asks - which is the honest
# division: a framework should not guess which business measurements matter.
#
# LOGGING IS `$c->log`. There is no telemetry-specific logging call: the
# plugin taps Punk's logger, so an ordinary log line is exported carrying this
# request's trace id, and the line still goes to the log as well.
#
# `$c->otel_meter` and `$c->otel_span` are the plugin's helpers, reaching the
# meter it already built and already drains on its own timer rather than
# standing up a second exporter that would ship a second copy of everything.
sub _measure {
    my ($c, $route, $status, $seconds) = @_;
    my $meter = $c->otel_meter or return;

    # The span goes with every point as an EXEMPLAR: the trace id stamped on
    # a measurement, which is what turns "the p99 got worse" into the specific
    # request that made it worse.
    my $span = $c->otel_span;

    # The attributes are the ROUTE PATTERN and the status - two
    # low-cardinality dimensions. Putting the path here instead would be one
    # series per product id.
    my $at = { 'http.route' => $route, 'http.response.status_code' => $status };

    # Kind 3 is a HISTOGRAM: a duration wants a distribution, not an average.
    # An average latency hides exactly the tail everybody actually cares
    # about, and no amount of dashboard fixes a number that was never kept.
    $meter->record('http.server.request.duration', 3, $seconds, $at, $span);

    # Kind 1 is a COUNTER, and it is here because the receiver stores sums and
    # gauges but skips histograms - that is phase 5's remaining shape, and the
    # skip is deliberate rather than a decode failure. So the rate of requests
    # is recorded as a counter and lands in the store today, while the
    # distribution arrives on the wire and waits for the histogram path.
    $meter->record('http.server.request.count', 1, 1, $at, $span);
}

# A CHILD SPAN, which is what makes a trace a tree rather than a line.
#
# The server span is opened by the instrumentation. Everything inside a
# request that is worth seeing separately - a query, a cache lookup, a
# template render - is a child of it, and a child is a child because it is
# given the parent explicitly. Nothing is ambient: two requests are in flight
# on the same worker at any moment, and a "current span" held in a global
# would attribute one request's work to the other.
sub _span {
    my ($c, $name, $kind, $ms, $attrs) = @_;
    my $parent = $c->otel_span;
    my $span = $parent ? $c->otel->start($name, kind => $kind,
                                         parent => $parent->child_of)
                       : undef;
    _query($ms) if $ms;
    return unless $span;
    $span->attr($_ => $attrs->{$_}) for keys %{ $attrs || {} };
    $c->otel->enqueue($span);
    return;
}

my @CATALOGUE = (
    { id => 1, name => 'Punk tee',        price => 1800 },
    { id => 2, name => 'Enamel mug',      price =>  900 },
    { id => 3, name => 'Sticker pack',    price =>  400 },
    { id => 4, name => 'Hardback manual', price => 3200 },
);

# A little real work, so the spans have a shape. Nothing here is timing code:
# the duration on the span is the duration of the request, measured by the
# instrumentation.
sub _query {
    my ($ms) = @_;
    Time::HiRes::sleep(($ms + int(rand $ms)) / 1000);
}

sub index {
    my ($c) = @_;
    my $t = Time::HiRes::time();
    _span($c, 'cache.get catalogue', 1, 1, { 'cache.hit' => 1 });
    $c->log->debug({ message => 'catalogue served from cache',
                     'cache.hit' => 1, 'catalogue.items' => scalar @CATALOGUE });
    _span($c, 'SELECT products', 1, 3,
          { 'db.system' => 'postgresql', 'db.operation' => 'SELECT',
            'db.sql.table' => 'products' });
    _span($c, 'render welcome', 1, 1, { 'template.name' => 'welcome' });
    _measure($c, '/', 200, Time::HiRes::time() - $t);
    return $c->render('welcome', {
        title     => 'Demo shop',
        catalogue => \@CATALOGUE,
    });
}

sub product {
    my ($c) = @_;
    my $t  = Time::HiRes::time();
    my $id = $c->param('id');
    _span($c, 'cache.get product', 1, 1,
          { 'cache.hit' => 0, 'product.id' => $id });
    $c->log->debug({ message => "cache miss for product $id",
                     'cache.hit' => 0, 'product.id' => $id });
    _span($c, 'SELECT product', 1, 4,
          { 'db.system' => 'postgresql', 'db.operation' => 'SELECT',
            'db.sql.table' => 'products' });
    my ($p) = grep { $_->{id} eq $id } @CATALOGUE;
    unless ($p) {
        _measure($c, '/product/:id', 404, Time::HiRes::time() - $t);
        $c->log->info({ message => "no such product: $id",
                        'product.id' => $id });
        return $c->status(404)->text("no such product\n");
    }
    _span($c, 'render product', 1, 1, { 'template.name' => 'product' });
    $c->log->debug({ message => "served $p->{name}",
                     'product.id' => $p->{id}, 'product.price' => $p->{price} });
    _measure($c, '/product/:id', 200, Time::HiRes::time() - $t);
    return $c->render('product', { title => $p->{name}, product => $p });
}

sub cart {
    my ($c) = @_;
    my $t = Time::HiRes::time();
    _span($c, 'session.load', 1, 1, { 'session.store' => 'redis' });
    _span($c, 'SELECT cart_items', 1, 3,
          { 'db.system' => 'postgresql', 'db.operation' => 'SELECT',
            'db.sql.table' => 'cart_items' });
    my $total = 0;
    $total += $_->{price} for @CATALOGUE;
    $c->log->debug({ message => 'cart loaded',
                     'cart.items' => scalar @CATALOGUE,
                     'cart.total' => $total, 'session.store' => 'redis' });
    _span($c, 'render cart', 1, 1, { 'template.name' => 'cart' });
    _measure($c, '/cart', 200, Time::HiRes::time() - $t);
    return $c->render('cart', { title => 'Your cart', catalogue => \@CATALOGUE });
}

# THE INTERESTING ONE. A real HTTP call to a real second service, and the one
# place where a trace stops being about one process.
#
# THE CLIENT SPAN AND ITS HEADER ARE MADE HERE, EXPLICITLY. Fetch's own
# observer opens a client span with no parent, so an outbound call starts a
# brand-new trace and the `traceparent` it injects carries that new id: the
# card processor then joins a trace containing nothing but itself, and every
# trace in the store is one span long. Parenting the call to this request's
# own span, and building the header from it, is what joins the two halves.
sub checkout {
    my ($c) = @_;
    my $t0 = Time::HiRes::time();

    _span($c, 'session.load', 1, 1, { 'session.store' => 'redis' });
    _span($c, 'SELECT cart_items', 1, 3,
          { 'db.system' => 'postgresql', 'db.operation' => 'SELECT',
            'db.sql.table' => 'cart_items' });
    _span($c, 'INSERT orders', 1, 4,
          { 'db.system' => 'postgresql', 'db.operation' => 'INSERT',
            'db.sql.table' => 'orders' });

    # THE FIELDS ARE WHAT MAKE THIS USEFUL LATER. A message that says
    # "checkout started" answers nothing during an incident; the same line
    # with the amount, the currency and the payment id on it is the one
    # somebody greps for, and every field here arrives as an attribute on the
    # exported record. Unbounded values are fine on a LOG record - the
    # cardinality cap gates metric label sets, not log fields.
    my $payment = sprintf('PAY-%06d', int(rand 1_000_000));
    $c->log->info({ message => 'checkout started',
                    'payment.id'       => $payment,
                    'payment.amount'   => 1800,
                    'payment.currency' => 'GBP',
                    'cart.items'       => scalar @CATALOGUE });

    my $parent = $c->otel_span;
    my $call   = $parent ? $c->otel->start('POST /authorize', kind => 3,
                                           parent => $parent->child_of)
                         : undef;

    # W3C trace context: version, trace id, the id of the span the callee is
    # a child of, and the sampled flag. The callee's propagator reads this and
    # its server span joins THIS trace.
    my %headers = ('Content-Type' => 'application/json');
    $headers{traceparent} = $call->traceparent if $call;

    # Every Fetch call returns a Future; ->get awaits it. On a Hyperman
    # worker that yields to the loop rather than blocking it, so the process
    # keeps serving other requests while this one waits on the acquirer -
    # which is exactly what makes the incident show as LATENCY rather than as
    # a dead server.
    $c->log->debug({ message => 'calling the card processor',
                     'peer.service' => 'cards', 'payment.id' => $payment,
                     'http.request.method' => 'POST',
                     'http.route' => '/authorize' });

    # `$c->ua`, NOT `Fetch->new`.
    #
    # One agent per worker, built on first use and bound to the loop that
    # serves inbound requests - so awaiting this PARKS the request and the
    # worker answers others while the acquirer thinks about it. A fresh
    # `Fetch->new` here has no loop, so `->get` BLOCKS: the worker stops
    # serving for the three seconds the incident takes, and the demo shows a
    # dead shop rather than a slow one, which is the wrong lesson and not
    # what the code does. It also pays a new TCP handshake per checkout,
    # which is the opposite of the reason to reach for Fetch.
    my $called = Time::HiRes::time();
    my $res = eval {
        $c->ua->post("$CARDS/authorize",
                     headers => \%headers,
                     body    => '{"amount":1800,"currency":"GBP"}')->get;
    };
    my $took = int((Time::HiRes::time() - $called) * 1000);

    if ($call) {
        $call->attr('server.address' => 'cards');
        $call->attr('http.request.method' => 'POST');
        $call->attr('http.route' => '/authorize');
        $call->attr('http.response.status_code' => $res->status) if $res;
        # The client span is ended and queued whatever happened, or a failed
        # call is a hole in the trace exactly where the failure was.
        $c->otel->enqueue($call);
    }

    if (!$res || $@) {
        # The dependency did not answer at all.
        _measure($c, '/checkout', 502, Time::HiRes::time() - $t0);
        $c->log->error({
            message        => 'payments unreachable: no response from the acquirer',
            'peer.service' => 'cards',
            'payment.id'   => $payment,
            'error.type'   => 'unreachable',
            'duration_ms'  => $took,
        });
        return $c->status(502)->json({ error => 'payments_unreachable' });
    }

    if ($res->status >= 500) {
        # A FAILED CHECKOUT IS A 5xx ON THIS SERVICE TOO, which is what makes
        # the incident visible at the edge rather than only inside payments.
        _measure($c, '/checkout', 503, Time::HiRes::time() - $t0);
        $c->log->error({
            message           => 'checkout failed: payment authorisation unavailable',
            'peer.service'    => 'cards',
            'payment.id'      => $payment,
            'error.type'      => 'checkout_failed',
            'upstream.status' => $res->status,
            'duration_ms'     => $took,
        });
        return $c->status(503)->json({
            error  => 'checkout_failed',
            detail => 'payment authorisation unavailable',
        });
    }

    # A SLOW SUCCESS IS STILL WORTH A LINE. The incident's first symptom is
    # not an error - it is checkouts that still work and take three seconds -
    # and a log that only records failures cannot show the half hour before
    # anything actually broke.
    $c->log->warn({ message => "payment authorisation was slow: ${took}ms",
                    'peer.service' => 'cards', 'payment.id' => $payment,
                    'duration_ms'  => $took })
        if $took > 1000;

    _measure($c, '/checkout', 200, Time::HiRes::time() - $t0);
    my $order = sprintf('ORD-%06d', int(rand 1_000_000));
    $c->log->info({ message => "checkout complete: $order",
                    'order.id'     => $order,
                    'payment.id'   => $payment,
                    'payment.amount' => 1800,
                    'duration_ms'  => $took,
                    'peer.service' => 'cards' });
    return $c->json({ ok => 1, order => $order });
}

1;

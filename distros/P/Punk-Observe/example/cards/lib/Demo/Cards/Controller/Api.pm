package Demo::Cards::Controller::Api;

use strict;
use warnings;
use parent 'Punk::Controller';
use Time::HiRes ();
use Punk::Plugin::OpenTelemetry ();

our $VERSION = '0.01';

# Authorise a payment.
#
# Healthy it takes 30-60ms. Broken it takes three seconds and fails about
# half the time - which is the shape of a real upstream timeout rather than a
# clean 500, and is why the demo's traces show a LONG span rather than a fast
# error.
# A child of this request's own span. Nothing ambient: two requests are in
# flight on the same worker at any moment, and a "current span" in a global
# would attribute one request's work to the other.
sub _span {
    my ($c, $name, $kind, $ms, $attrs) = @_;
    my $parent = $c->otel_span;
    my $span = $parent ? $c->otel->start($name, kind => $kind,
                                         parent => $parent->child_of)
                       : undef;
    Time::HiRes::sleep($ms / 1000) if $ms;
    return unless $span;
    $span->attr($_ => $attrs->{$_}) for keys %{ $attrs || {} };
    $c->otel->enqueue($span);
    return;
}

sub authorize {
    my ($c) = @_;
    my $ms;

    # A card, invented per request. Both of these are the shape of the thing
    # rather than the thing: a LAST FOUR and a scheme are what a support
    # engineer needs to find a payment, and a pan or an expiry is what a log
    # must never be able to leak. The demo is opinionated about this on
    # purpose - it is the one place where "log everything" is wrong.
    my $last4  = sprintf('%04d', int(rand 10_000));
    my $scheme = (qw(visa mastercard amex))[ int rand 3 ];

    # The work inside an authorisation, so the trace shows WHERE the time
    # went rather than only that it went.
    my $score = int(rand 100);
    _span($c, 'risk.score', 1, 2 + int(rand 4),
          { 'risk.model' => 'v3', 'risk.outcome' => 'accept' });
    $c->log->debug({ message => "risk scored $score",
                     'risk.model' => 'v3', 'risk.score' => $score,
                     'risk.outcome' => ($score > 80 ? 'review' : 'accept') });
    $c->log->warn({ message => "risk score $score is above the review threshold",
                    'risk.model' => 'v3', 'risk.score' => $score,
                    'risk.outcome' => 'review' })
        if $score > 80;

    _span($c, 'SELECT card', 1, 2 + int(rand 3),
          { 'db.system' => 'postgresql', 'db.operation' => 'SELECT',
            'db.sql.table' => 'cards' });
    $c->log->debug({ message => "card ending $last4 found",
                     'card.last4' => $last4, 'card.scheme' => $scheme });

    if (Demo::Cards::incident_on()) {
        $ms = 2800 + int(rand 700);

        # THE SPAN THAT SHOWS THE INCIDENT. The three seconds are inside this
        # child, not smeared across the request, so the waterfall points at
        # the acquirer rather than at the service that called it.
        _span($c, 'POST acquirer/authorize', 3, $ms,
              { 'peer.service' => 'acquirer',
                'server.address' => 'acquirer.example',
                'http.request.method' => 'POST' });

        if (rand() < 0.45) {
            # THE ORDINARY LOGGER. Nothing here knows about telemetry: the
            # plugin taps Punk's logger and the record leaves carrying this
            # request's trace id, which is what makes the jump from a log
            # line to the request that produced it one click rather than a
            # guess - and the whole difference between a log screen that is a
            # list of access lines and one somebody can work an incident in.
            $c->log->error({
                message => 'connection refused talking to acquirer: '
                         . "upstream timed out after ${ms}ms",
                'peer.service'    => 'acquirer',
                'error.type'      => 'acquirer_timeout',
                'payment.outcome' => 'refused',
                'retry.possible'  => 1,
                'duration_ms'     => $ms,
                'card.last4'      => $last4,
                'card.scheme'     => $scheme,
            });
            return $c->status(504)->json({
                error => 'acquirer_timeout',
                detail => "no response after ${ms}ms",
            });
        }
        $c->log->warn({ message => "slow authorisation: ${ms}ms",
                        'peer.service'    => 'acquirer',
                        'payment.outcome' => 'authorized',
                        'duration_ms'     => $ms,
                        'card.last4'      => $last4 });
    }
    else {
        $ms = 30 + int(rand 30);
        _span($c, 'POST acquirer/authorize', 3, $ms,
              { 'peer.service' => 'acquirer',
                'server.address' => 'acquirer.example',
                'http.request.method' => 'POST',
                'http.response.status_code' => 200 });
    }

    _span($c, 'INSERT authorisations', 1, 1 + int(rand 3),
          { 'db.system' => 'postgresql', 'db.operation' => 'INSERT',
            'db.sql.table' => 'authorisations' });
    $c->log->debug({ message => 'authorisation recorded',
                     'db.operation' => 'INSERT',
                     'db.sql.table' => 'authorisations' });

    # A histogram, because a latency wants a distribution: an average hides
    # exactly the tail this demo is about. The span goes with it as an
    # EXEMPLAR, which is the trace id on a point - and what turns "the p99 got
    # worse" into the specific request that made it worse.
    if (my $meter = $c->otel_meter) {
        $meter->record('payment.authorize.duration', 3, $ms / 1000,
                       { outcome => 'authorized' }, $c->otel_span);
    }

    $c->log->info({ message => "authorized in ${ms}ms",
                    'payment.outcome' => 'authorized',
                    'duration_ms'     => $ms,
                    'card.last4'      => $last4,
                    'card.scheme'     => $scheme });

    return $c->json({ authorized => 1, latency_ms => $ms,
                      auth_code => sprintf('A%06d', int(rand 1_000_000)) });
}

# Break it, or fix it. The demo driver calls this; so can you, with curl.
sub incident {
    my ($c) = @_;
    my $on = $c->param('on');
    my $broken = Demo::Cards::set_incident(
        (defined $on && $on =~ /^(1|true|on)$/i) ? 1 : 0);

    # A CONFIGURATION CHANGE IS AN EVENT. Half of working out what happened is
    # working out what somebody changed and when, and a deploy or a flag flip
    # that leaves no line is the gap every incident review runs into.
    $c->log->warn({ message => $broken
                        ? 'incident mode ENABLED: the acquirer will time out'
                        : 'incident mode disabled: the acquirer is healthy',
                    'incident.enabled' => $broken,
                    'change.source'    => 'api' });

    return $c->json({ broken => $broken });
}

1;

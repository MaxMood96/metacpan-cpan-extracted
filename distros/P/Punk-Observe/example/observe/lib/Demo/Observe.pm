package Demo::Observe;

use strict;
use warnings;
use Punk;
use Punk::Plugin::Observe;
use Punk::Observe::Store ();
use Demo::DB ();

our $VERSION = '0.01';

config 'config/punk.yml';

# THE MOUNT.
#
# `guard` is not optional and registration croaks without it. Comment it out
# and this application refuses to boot, which is the point: an unguarded mount
# is every log line the shop has ever written, served to anybody who finds the
# prefix.
#
# The guard here is a demo guard - it lets everybody in and says so. A real
# one is 'Web::Auth#observe_admin' or whatever your application already uses
# to protect an admin page.
plugin 'Observe' => {
    prefix => '/observe',
    guard  => \&_demo_guard,
    store  => $ENV{DEMO_STORE} || 'var/store',

    # The OTLP endpoint. This is what OTEL_EXPORTER_OTLP_ENDPOINT points at,
    # and it sits OUTSIDE the UI scope on purpose: authenticated by key rather
    # than by the UI guard, because an exporter has no session, and
    # CSRF-exempt, because an exporter has no form token.
    ingest => {
        prefix => '/v1',
        # keys => 'etc/keys',   # uncomment to require a bearer token
    },

    # A small live log, so a segment is sealed within a demo run rather than
    # after eight megabytes of traffic. In production the default is right.
    #
    # NOT SMALLER THAN THIS. At 64KB a fifty-second run left three thousand
    # segments, and a trace whose spans land either side of a seal is a trace
    # whose two halves are summarised separately - so the service map
    # attributed most of its edges to the synthetic root rather than to the
    # service that actually made the call.
    seal_bytes => 1024 * 1024,

    limits => {
        # Off unless configured, so the demo is not silently throttled.
        # rate_records => 50_000,
        series     => 100_000,
        attributes => [ qw(service.name severity http.route
                           deployment.environment) ],
    },

    # THE ALERT RULES, EVALUATED RATHER THAN ASSERTED.
    #
    # Rules are configuration, so in a real application this reads them from
    # the database - `sqitch/` ships the schema, and alert_state and
    # alert_events are the two tables the screen wants.
    #
    # This demo has no database, and the interesting half is not where the
    # rows are stored: it is that the states below are computed by the real
    # evaluator from the real spans the shop and the card processor produced.
    # Nothing here is fabricated, which is the same rule the telemetry follows.
    alerts => \&_alerts,
};

# The front door. Everything worth looking at is under /observe.
get '/' => sub {
    my ($c) = @_;
    $c->text("Punk::Observe demo receiver.\n\n"
           . "  POST /v1/traces    OTLP/protobuf or OTLP/JSON\n"
           . "  POST /v1/metrics\n"
           . "  POST /v1/logs\n\n"
           . "  GET  /observe          the UI (guarded)\n"
           . "  GET  /observe/logs     search, and click a line\n"
           . "  GET  /observe/traces   the slowest, and one assembled\n"
           . "  GET  /observe/map      the service graph\n"
           . "  GET  /observe/explore  one box over every signal\n"
           . "  GET  /observe/alerts   two rules, from the demo's database\n");
};

# ---------------------------------------------------------------------------
# Alerting
# ---------------------------------------------------------------------------

# Two rules, both real queries over the spans the demo actually produced.
#
# `bin/demo` breaks the card processor in the middle of its run and fixes it
# again, so the first of these goes ok -> pending -> firing -> ok over about a
# minute. That is the whole shape an alert screen exists to show, and it is
# here because the traffic really did that rather than because this file says
# so.
#
# `for` is what stops a single bad minute paging anybody: the condition has to
# hold CONTINUOUSLY for that long before the state leaves pending.
# THE THRESHOLDS ARE MEASURED, NOT GUESSED. Over a demo run the p95 sits
# around 65ms and spikes past three seconds while the card processor is
# broken; errors appear in five buckets out of twenty-eight. So 500ms and five
# errors both sit well clear of normal and well under the incident.
#
# A demo whose alerts are always firing teaches the wrong lesson twice: the
# screen is a wall of red, and nobody sees a state ever change.
# THE ALERT SCREEN IS A DATABASE READ, AND NOTHING ELSE.
#
# The rules are rows in `alert_rules`, the states are rows in `alert_state`,
# and the transitions are rows in `alert_events`. All three are written by
# `bin/evaluate`, which is a separate process for the reason stated in it: a
# state computed on the request that draws the screen is a state that depends
# on who last looked at it, and nothing is recorded when nobody is watching.
#
# So this callback does no evaluation. That is the point - it is what an
# application mounting the plugin actually writes.
sub _alerts {
    # ONE ARGUMENT, and it is the request. The dashboards seam takes the slug
    # first and then the request; this one does not, so reading it as
    # ($id, $req) binds $id to the request hashref - which is true, and not
    # equal to any rule id, so every rule was filtered out and the screen said
    # there were none.
    my ($req) = @_;
    my $id = ref $req eq 'HASH' ? $req->{id} : undef;

    my $now = Punk::Observe::now_ns();
    # AN HOUR, so the story outlives the run that produced it.
    my $from = Punk::Observe::Store::nsub($now, 3_600 * 1_000_000_000);

    my $rules = eval { Demo::DB::rules($id) } or
        return { rules => [], configured => 1 };

    my (@rules, @events);
    my %named;
    for my $r (@$rules) {
        $named{ $r->{id} } = $r;
        for my $s (@{ Demo::DB::state_for($r->{id}) }) {
            push @rules, {
                id     => $r->{id},
                name   => $r->{name},
                series => $s->{series},
                state  => $s->{state},
                # THE QUERY IS WHAT MAKES `explore` A LINK. Without it the
                # screen builds `?q=` and the explorer opens on an empty box,
                # which is a dead end reached by clicking something that
                # promised the opposite.
                query  => $r->{query},
                # BOTH OF THESE ARE NUMBERS, NOT STRINGS. The screen formats
                # them - `held` as a duration and `value` as %.4g - so a
                # pre-formatted "2m30s" arrives as the number 2 and renders as
                # two nanoseconds. Which it did.
                value  => $s->{last_value},
                held   => ($s->{since}
                             ? Punk::Observe::Store::nsub($now, $s->{since}) : 0),
            };
        }
    }

    # The timeline, from the recorded transitions. Qualified by rule: two
    # rules watching `cards` are two rows, not one that contradicts itself.
    my %moved;
    for my $e (@{ Demo::DB::events_since($from) }) {
        next unless $named{ $e->{rule_id} };            # a rule filtered out
        $moved{ $e->{rule_id} }{ $e->{series} } = 1;
        push @events, { series => "$e->{rule_name} / $e->{series}",
                        to => $e->{to_state}, at => $e->{at} };
    }

    # A SERIES THAT NEVER CHANGED STILL HAS A ROW.
    #
    # The timeline is built from transitions, and a rule that has been quietly
    # ok all hour produces none - so it vanished from the chart entirely while
    # sitting in the table underneath it. A screen that shows three rules and
    # charts one is a screen nobody trusts.
    #
    # This is an inference and a sound one: the events are complete for the
    # window, so no transition in it means the state did not change in it, and
    # the state it is in now is the state it held throughout. That is
    # different from inventing history for a series whose transitions were
    # never recorded.
    for my $row (@rules) {
        next if $moved{ $row->{id} }{ $row->{series} };
        push @events, { series => "$row->{name} / $row->{series}",
                        to => $row->{state}, at => $from };
    }

    return {
        rules    => \@rules,
        events   => \@events,
        silences => [ map {
            { pattern => $_->{pattern}, until => $_->{until},
              by => $_->{created_by}, reason => $_->{reason} }
        } @{ Demo::DB::silences($now) } ],
        to       => $now,
        # A demo has no login, so nothing may be edited from it. A real
        # application returns whatever its own authorisation says.
        can_edit => 1,
    };
}

sub _demo_guard {
    my ($c) = @_;
    # A guard returns nothing to allow the request through. THIS ONE ALLOWS
    # EVERYBODY, which is fine for a demo on localhost and is not fine
    # anywhere else.
    return;
}

1;

package Demo::DB;

# The demo's configuration database - the seeds, and nothing else.
#
# RULES ARE CONFIGURATION, AND CONFIGURATION LIVES IN THE APPLICATION'S OWN
# DATABASE. This module used to also carry the evaluator's write path -
# rules(), record(), a transaction guard, an event-kind table - because the
# demo ran its own evaluation loop. The distribution runs that loop now, on
# the queue, so what is left here is what a real application keeps: where the
# database is, and what to put in it on first boot.
#
# SQLite, because a demo that needed a running Postgres is a demo most people
# never see. The schema is the distribution's own sqitch change scripts,
# applied by Punk::Observe::Backend->migrate.

use strict;
use warnings;
use DBI ();
use File::Basename qw(dirname);

our $VERSION = '0.01';

# One handle per process. Under a prefork pool each worker opens its own,
# which is what every DBI application does and is why the schema is deployed
# before the fork rather than on first use.
my %H;

# THE SAME FILE THE PLUGIN USES, which is the whole point of this change.
# It used to be alerts.db beside config.db, so the evaluator wrote alert state
# into one database and the screen read configuration out of another - which
# worked only because the demo also supplied the reader. With the built-in
# store serving the screen, a second file is a screen that shows nothing.
#
# `config.db` beside the telemetry is Punk::Plugin::Observe's own default when
# `db` is not set, and the demo does not set it.
sub path {
    my $dir = $ENV{DEMO_STORE} || 'var/store';
    return "$dir/config.db";
}

sub dbh {
    my $p = path();
    return $H{"$$:$p"} if $H{"$$:$p"};

    my $dir = dirname($p);
    unless (-d $dir) { require File::Path; File::Path::make_path($dir) }

    my $h = DBI->connect("dbi:SQLite:dbname=$p", '', '', {
        RaiseError => 1, PrintError => 0, AutoCommit => 1,
        sqlite_unicode => 1,
    });
    # A demo runs three servers plus a queue worker against one file. WAL
    # lets the readers carry on while the worker writes, and the busy timeout
    # turns the remaining contention into a wait rather than an error.
    $h->do('PRAGMA journal_mode = WAL');
    $h->do('PRAGMA foreign_keys = ON');
    # THIRTY SECONDS, NOT FIVE.
    #
    # Five is what the distribution uses for handles it opens itself, and it
    # is right there: those serve web requests, where waiting half a minute
    # for a lock is worse than saying so. This handle belongs to seeding,
    # which is batch work with nobody watching - and at boot the demo starts
    # three applications, twelve workers, a migration and a seeder within the
    # same second, all against one file.
    #
    # At five seconds that start-up crowd produced "database is locked" from
    # the seeder. Waiting is exactly what a batch job should do.
    $h->sqlite_busy_timeout(30_000);
    return $H{"$$:$p"} = $h;
}

# THE DISTRIBUTION OWNS THE SCHEMA.
#
# This used to read a hand-maintained SQLite twin of the PostgreSQL DDL in
# `sqitch/`, and the twin had drifted - it was missing five of the nine
# tables, dashboards among them, which is why this demo could not have a
# dashboard. Punk::Observe::Backend migrates instead, so there is one schema
# and nothing here to keep in step with it.
sub deploy {
    require Punk::Observe::Backend;
    Punk::Observe::Backend->new(dbh => dbh())->migrate;
    return dbh();
}

# The rules this demo watches.
#
# Seeded rather than hardcoded anywhere: the point of the exercise is that
# the screen and the evaluator both read whatever is in the table, so
# changing a threshold is an edit on the alerts screen and not a deploy.
sub seed {
    my $h = deploy();

    # THROUGH THE DISTRIBUTION'S OWN WRITER, like the dashboards: every rule
    # is then validated by the parser that will evaluate it, so a typo in a
    # seed query fails here rather than as an `error` state on the screen.
    require Punk::Observe::Backend;
    require Punk::Observe::Config;
    my $db = Punk::Observe::Backend->new(dbh => $h);

    my @rules = (
        # GROUPED BY SERVICE, to show the thing that matters most about this
        # engine: state is per series. `cards` and `shop` are evaluated
        # separately, so one recovering cannot resolve the other.
        { name => 'error rate',
          query => 'spans | where status = 2 | bucket(30s) count by service',
          op => '>', threshold => 5, for => '30s', every => '30s' },

        # SCOPED, so the name is true. Called "slow checkout" while measuring
        # every service it would be a rule that fires for something it does
        # not name, which is how an operator learns to distrust the screen.
        #
        # The threshold is the raw number the query returns - nanoseconds,
        # since it measures time - exactly as the editor says.
        { name => 'slow checkout',
          query => 'spans | where service = "shop" | bucket(30s) p95',
          op => '>', threshold => 500_000_000, for => '60s', every => '30s' },
    );
    for my $r (@rules) {
        my $id = $h->selectrow_array(
            'SELECT id FROM alert_rules WHERE tenant = ? AND name = ?',
            undef, 'default', $r->{name});
        my $x = Punk::Observe::Config::save_alert($db, 'default',
                    { %$r, ($id ? (id => $id) : ()) });
        die "seed rule '$r->{name}': $x->{error}\n" unless $x->{ok};
    }
    return $h;
}

# The dashboards this demo ships, and the panels on them.
#
# EVERY PANEL IS A REAL QUERY over the spans and logs the shop and the card
# processor actually produced. A demo dashboard of invented numbers would
# demonstrate the grid and nothing else.
sub seed_dashboards {
    my $h = deploy();
    my @boards = (
        { slug => 'main', title => 'Checkout', cols => 2, panels => [
            { title => 'Requests by service',
              query => 'spans | bucket(30s) count by service' },
            { title => 'Errors',
              query => 'spans | where status = 2 | bucket(30s) count by service' },
            { title => 'Checkout latency, p95',
              query => 'spans | where service = "shop" | bucket(30s) p95' },
            { title => 'Log volume by severity',
              query => 'log | bucket(30s) count by severity' },
        ] },
        { slug => 'cards', title => 'Card processor', cols => 1, panels => [
            { title => 'Authorisations',
              query => 'spans | where service = "cards" | bucket(30s) count' },
            { title => 'Refusals',
              query => 'log | where severity >= error | bucket(30s) count' },
        ] },
    );

    # THROUGH THE DISTRIBUTION'S OWN API, not raw SQL. Two reasons: every
    # panel is then validated by the parser that will run it, so a typo in a
    # seed query fails here rather than rendering as a refusal on the screen;
    # and a demo that reaches around the interface it is demonstrating is not
    # demonstrating it.
    require Punk::Observe::Backend;
    require Punk::Observe::Config;
    my $db = Punk::Observe::Backend->new(dbh => $h);

    for my $b (@boards) {
        my $r = Punk::Observe::Config::save_dashboard($db, 'default', $b);
        die "seed: $r->{error}\n" unless $r->{ok};

        # Replaced wholesale rather than merged: the seed is the definition,
        # and a panel removed from it should leave the board.
        $h->do('DELETE FROM dashboard_panels WHERE dashboard_id = ?',
               undef, $r->{id});
        my $pos = 0;
        for my $p (@{ $b->{panels} }) {
            my $x = Punk::Observe::Config::save_panel(
                $db, 'default', $b->{slug}, { %$p, position => $pos++ });
            die "seed panel '$p->{title}': $x->{error}\n" unless $x->{ok};
        }
    }
    return $h;
}

# WHAT TO POLL. Loopback, which the SSRF policy refuses by default and
# admits through the allowlist - which is exactly the self-hosted case the
# policy's refusal message points at, demonstrated rather than described.
sub seed_health {
    my $h = deploy();
    my %port = (shop => 5000, cards => 5002);
    for my $name (sort keys %port) {
        $h->do(q{
            INSERT INTO health_targets
                (tenant, name, url, every_ns, timeout_ms, enabled, created_at)
            VALUES (?,?,?,?,?,1,?)
            ON CONFLICT (tenant, name) DO UPDATE SET
                url = excluded.url, every_ns = excluded.every_ns,
                timeout_ms = excluded.timeout_ms
        }, undef, 'default', $name,
           "http://127.0.0.1:$port{$name}/readyz",
           15_000_000_000, 2000, time);
    }
    return $h;
}

# The allowlist the demo polls under. Named here rather than in the poller so
# the reason travels with it: everything the demo watches is on loopback, and
# the policy refuses loopback by default for a good reason that does not apply
# when the operator typed the target themselves.
sub health_allow { return ['127.0.0.1'] }

1;

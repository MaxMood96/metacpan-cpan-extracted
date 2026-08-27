package Demo::DB;

# The demo's alert database.
#
# RULES ARE CONFIGURATION, AND CONFIGURATION LIVES IN THE APPLICATION'S OWN
# DATABASE. That is the whole reason Punk::Plugin::Observe takes a reader
# callback instead of shipping a rule store: a rule has an owner, a review and
# a history, and none of those belong in a telemetry store that retention
# deletes from. This module is what a real application already has, spelled
# small enough to read.
#
# SQLite, because a demo that needed a running Postgres is a demo most people
# never see. F<sql/schema.sql> is the SQLite twin of the shipped
# F<sqitch/deploy/alerts.sql>, which is the real one.

use strict;
use warnings;
use DBI ();
use File::Basename qw(dirname);

our $VERSION = '0.01';

# One handle per process. Under a prefork pool each worker opens its own,
# which is what every DBI application does and is why the schema is deployed
# before the fork rather than on first use.
my %H;

sub path {
    my $dir = $ENV{DEMO_STORE} || 'var/store';
    return "$dir/alerts.db";
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
    # A demo runs three servers plus an evaluator against one file. WAL lets
    # the readers carry on while the evaluator writes, and the busy timeout
    # turns the remaining contention into a wait rather than an error.
    $h->do('PRAGMA journal_mode = WAL');
    $h->do('PRAGMA foreign_keys = ON');
    $h->sqlite_busy_timeout(5_000);
    return $H{"$$:$p"} = $h;
}

# Deployed from the file rather than from a string in here, so the schema a
# reader inspects is the schema that runs.
sub deploy {
    my $h = dbh();
    my $sql = do {
        my $f = dirname(__FILE__) . '/../../sql/schema.sql';
        open my $fh, '<', $f or die "$f: $!";
        local $/; <$fh>;
    };
    # SQLite's driver takes one statement per do().
    for my $stmt (grep { /\S/ } split /;\s*\n/, $sql) {
        $h->do($stmt);
    }
    return $h;
}

# The rules this demo watches.
#
# Seeded rather than hardcoded in the reader: the point of the exercise is
# that the screen reads whatever is in the table, so changing a threshold is
# an UPDATE and not a deploy.
sub seed {
    my $h = deploy();
    my @rules = (
        # GROUPED BY SERVICE, to show the thing that matters most about this
        # engine: state is per series. `cards` and `shop` are evaluated
        # separately, so one recovering cannot resolve the other.
        { name => 'error rate',
          query => 'spans | where status = 2 | bucket(30s) count by service',
          op => '>', threshold => 5,
          for_ns => 30_000_000_000, every_ns => 30_000_000_000,
          unit => 'count', series_label => undef },

        # SCOPED, so the name is true. Called "slow checkout" while measuring
        # every service it would be a rule that fires for something it does
        # not name, which is how an operator learns to distrust the screen.
        #
        # Durations are nanoseconds all the way down, so the threshold is too.
        { name => 'slow checkout',
          query => 'spans | where service = "shop" | bucket(30s) p95',
          op => '>', threshold => 500_000_000,
          for_ns => 60_000_000_000, every_ns => 30_000_000_000,
          unit => 'p95', series_label => 'shop' },
    );

    my $ins = $h->prepare(q{
        INSERT INTO alert_rules
            (tenant, name, query, op, threshold, for_ns, every_ns,
             series_label, unit, enabled)
        VALUES (?,?,?,?,?,?,?,?,?,1)
        ON CONFLICT (tenant, name) DO UPDATE SET
            query = excluded.query, op = excluded.op,
            threshold = excluded.threshold, for_ns = excluded.for_ns,
            every_ns = excluded.every_ns,
            series_label = excluded.series_label, unit = excluded.unit
    });
    $ins->execute('default', @{$_}{qw(name query op threshold for_ns every_ns
                                      series_label unit)}) for @rules;
    return $h;
}

sub rules {
    my ($id) = @_;
    my $h = dbh();
    my $sql = 'SELECT * FROM alert_rules WHERE tenant = ? AND enabled = 1';
    my @bind = ('default');
    if (defined $id && length $id) { $sql .= ' AND id = ?'; push @bind, $id }
    $sql .= ' ORDER BY id';
    return $h->selectall_arrayref($sql, { Slice => {} }, @bind);
}

# THE STATE WRITE IS THE TRANSITION WRITE, IN ONE TRANSACTION.
#
# An event recorded without the state that produced it, or the other way
# round, is a timeline that disagrees with the table beside it - and the
# disagreement survives, because nothing recomputes either one afterwards.
sub record {
    my ($rule_id, $series, $new, $since, $value, $at) = @_;
    my $h = dbh();

    $h->begin_work;
    my $prev = $h->selectrow_hashref(
        'SELECT state, fired_at FROM alert_state WHERE rule_id = ? AND series = ?',
        undef, $rule_id, $series);
    my $from = $prev ? $prev->{state} : 'ok';

    my $fired = $prev ? $prev->{fired_at} : undef;
    $fired = $at if $new eq 'firing' && (!$prev || $prev->{state} ne 'firing');
    $fired = undef if $new ne 'firing';

    $h->do(q{
        INSERT INTO alert_state
            (rule_id, series, state, since, fired_at, last_seen, last_value)
        VALUES (?,?,?,?,?,?,?)
        ON CONFLICT (rule_id, series) DO UPDATE SET
            state = excluded.state, since = excluded.since,
            fired_at = excluded.fired_at, last_seen = excluded.last_seen,
            last_value = excluded.last_value
    }, undef, $rule_id, $series, $new, $since, $fired, $at, $value);

    $h->do(q{
        INSERT INTO alert_events (rule_id, series, from_state, to_state, value, at)
        VALUES (?,?,?,?,?,?)
    }, undef, $rule_id, $series, $from, $new, $value, $at)
        if $from ne $new;

    $h->commit;
    return $from ne $new;
}

sub state_for {
    my ($rule_id) = @_;
    return dbh()->selectall_arrayref(
        'SELECT * FROM alert_state WHERE rule_id = ? ORDER BY series',
        { Slice => {} }, $rule_id);
}

sub events_since {
    my ($from_ns) = @_;
    return dbh()->selectall_arrayref(q{
        SELECT e.*, r.name AS rule_name, r.series_label
          FROM alert_events e
          JOIN alert_rules r ON r.id = e.rule_id
         WHERE e.at >= ?
         ORDER BY e.at
    }, { Slice => {} }, $from_ns);
}

# Expired silences are excluded HERE rather than by a sweep, because a silence
# set for a deploy and forgotten is how a real page goes unsent for a month.
sub silences {
    my ($now_ns) = @_;
    return dbh()->selectall_arrayref(
        'SELECT * FROM silences WHERE tenant = ? AND until > ? ORDER BY id',
        { Slice => {} }, 'default', $now_ns);
}

1;

__END__

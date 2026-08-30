package Punk::Observe::Evaluate;

use 5.010;
use strict;
use warnings;
use Carp ();

use Punk::Observe ();
use Punk::Observe::Store ();
use Punk::Observe::Alert ();
use Punk::Observe::Config ();

our $VERSION = $Punk::Observe::VERSION;

# The evaluation pass, in the distribution.
#
# THIS LOOP IS WHAT EVERY HOST USED TO WRITE, and the demo's copy is why it
# must not be written twice more: in one week its transaction had no rollback
# - a single bad write held the SQLite lock for the life of the process - and
# its INSERT omitted a NOT NULL column, so every transition died and the
# events table had never held a row. Those were not demo bugs; they were the
# bugs any host would write.
#
# The shape mirrors Punk::Observe::Health: `run` is the pass over an explicit
# db and store so tests need neither a queue nor an app; `cron_task` wraps it
# in the queue's leader lock; `evaluate_job`/`notify_job` are the Punk::Queue
# task bodies, which receive ($job, @args) and nothing else and recover the
# plugin's state from the app class carried in the args.

# --- the tick transpose -----------------------------------------------------

# A bucketed answer is series -> points; an evaluation is an instant with
# every series' value at it. Instants sort as STRINGS, width first - a
# nanosecond instant past 2^53 does not survive numeric comparison, and two
# buckets a microsecond apart would sort as equal.
sub _ticks {
    my ($res) = @_;
    my (%rows, %val);
    for my $s (@{ $res->{series} || [] }) {
        for my $p (@{ $s->{points} || [] }) {
            push @{ $rows{ $p->[0] } }, ($s->{key} // ''), $p->[1];
            $val{ $s->{key} // '' } = $p->[1];
        }
    }
    my @at = sort { length($a) <=> length($b) || $a cmp $b } keys %rows;
    return ([ map { { at => $_, rows => $rows{$_} } } @at ], \%val);
}

# --- the window -------------------------------------------------------------

# Derived from the rule, never fixed: `for` needs at least that much history
# to be measured over, and a couple of `every`s of slack keeps the first tick
# from being the boundary bucket. The demo's fixed hour read twelve times the
# data a 5-minute rule needed and not enough for a 40-minute one.
my $WINDOW_FLOOR_NS = 900 * 1_000_000_000;             # fifteen minutes

sub _window_ns {
    my ($rule) = @_;
    my $w = 2 * ($rule->{for_ns} || 0);
    my $e = 4 * ($rule->{every_ns} || 0);
    $w = $e             if $e > $w;
    $w = $WINDOW_FLOOR_NS if $w < $WINDOW_FLOOR_NS;
    return $w;
}

# --- what a transition means for delivery -----------------------------------

# The state machine's own vocabulary: 1 firing, 2 resolved, 3 resolved
# because the series vanished, 4 error. 0 is a move that pages nobody -
# ok to pending, pending back to ok, a vanished series returning - and a 0
# writes the event and no notification.
sub _event_kind {
    my ($from, $to) = @_;
    return 1 if $to eq 'firing';
    return 4 if $to eq 'error';
    return 3 if $to eq 'stale' && $from eq 'firing';
    return 2 if $to eq 'ok' && ($from eq 'firing' || $from eq 'error');
    return 0;
}

# --- one pass ---------------------------------------------------------------

# run(db => $backend, store => $store, %opt)
#
#   now             the clock, injectable for tests (ns string)
#   tenant          evaluate one tenant; default is every tenant with rules
#   group_wait_ns   how long a group holds before its first send (default 30s)
#   repeat_ns       re-notify a still-firing group this often (default 0, off)
#   force           evaluate rules even before next_eval_at
#
# Returns { evaluated, transitions, enqueued, groups => [ {id, token,
# rule_id} ] } - the claimed groups are handed back rather than delivered,
# because delivery belongs on the queue with its retries, and a test wants to
# see what WOULD be sent without sending it.
sub run {
    my (%opt) = @_;
    my $db    = $opt{db}    or Carp::croak('Evaluate::run needs db');
    my $store = $opt{store} or Carp::croak('Evaluate::run needs store');
    my $dbh   = $db->dbh;
    my $now   = defined $opt{now} ? $opt{now} : Punk::Observe::now_ns();
    my $wait  = defined $opt{group_wait_ns} ? $opt{group_wait_ns}
                                            : 30_000_000_000;

    my @tenants = defined $opt{tenant} ? ($opt{tenant})
        : map { $_->[0] } @{ $dbh->selectall_arrayref(
            'SELECT DISTINCT tenant FROM alert_rules WHERE enabled = 1') };

    my ($evaluated, $transitions) = (0, 0);
    for my $tenant (@tenants) {
        my $rules = $dbh->selectall_arrayref(
            'SELECT * FROM alert_rules WHERE tenant = ? AND enabled = 1
              ORDER BY id', { Slice => {} }, $tenant);

        for my $r (@$rules) {
            # Each rule keeps its own cadence inside the shared pass; the
            # pass interval is the resolution, the rule's `every` is honoured
            # on top of it.
            next if !$opt{force}
                 && $r->{next_eval_at}
                 && _ncmp($r->{next_eval_at}, $now) > 0;

            my $from = Punk::Observe::Store::nsub($now, _window_ns($r));
            my $res  = eval { $store->query($r->{query},
                                            from => $from, to => $now) };
            my $qerr = $@;

            # THE REASON IS CAPTURED AT BIRTH. Every failure used to collapse
            # into an anonymous fail tick, and the screen could only count
            # broken rules with nothing to say what was wrong with any of
            # them.
            my ($ticks, $latest, $reason);
            if ($res && $res->{ok} && ($res->{shape} || '') eq 'buckets') {
                ($ticks, $latest) = _ticks($res);
            }
            elsif (!$res)       { $reason = _reason($qerr)
                                    || 'the query died with no message' }
            elsif (!$res->{ok}) { $reason = _reason($res->{error})
                                    || 'the store refused the query' }
            else {
                $reason = "the query answered with shape '"
                        . ($res->{shape} || '') . "' - an alert evaluates a "
                        . 'bucketed answer; add a bucket stage to the query';
            }

            # A QUERY THAT DID NOT ANSWER IS A FAIL TICK, not a hand-written
            # error state. The machine's own latch then notifies once and
            # re-arms on the next success - the demo bypassed this and
            # re-derived that logic in SQL, wrongly.
            #
            # AN EMPTY SUCCESS IS NOT A FAILURE. A query that answered with
            # no series in the window is a rule whose every series vanished -
            # the machine's stale semantics, not its error latch - so no fail
            # tick is minted and the reconcile below retires the rows.
            $ticks = [ { at => $now, fail => 1 } ] if !$ticks || $reason;

            my $out;
            if (@$ticks) {
                $out = eval { Punk::Observe::Alert::run(
                    { op => $r->{op}, threshold => $r->{threshold},
                      for => $r->{for_ns}, every => $r->{every_ns} },
                    $ticks) };
                next unless $out && @$out;

                $transitions += _record($dbh, $r, $out->[-1], $latest || {},
                                        $now, $wait, $reason);
            }

            # RETIRE WHAT THIS EVALUATION DID NOT MENTION. The machine stales
            # a series that vanishes within one run, but a series absent from
            # the whole window - including the synthetic `all` a fail tick
            # once recorded - was never mentioned again, so its row was
            # immortal: an error state outliving its cause by days. Only a
            # successful evaluation says anything about liveness, so a fail
            # tick reconciles nothing.
            $transitions += _reconcile($dbh, $r,
                                       $out ? $out->[-1]{states} : [],
                                       $now, $wait)
                unless $reason;
            $dbh->do('UPDATE alert_rules SET next_eval_at = ? WHERE id = ?',
                     undef, Punk::Observe::Store::nadd($now, $r->{every_ns}),
                     $r->{id});
            $evaluated++;
        }
    }

    my ($groups, $enqueued) = _flush($dbh, $now, \%opt);
    return { evaluated => $evaluated, transitions => $transitions,
             enqueued => $enqueued, groups => $groups };
}

# Decimal-string comparison for ns instants: width first, then lexical.
sub _ncmp {
    my ($a, $b) = @_;
    ($a, $b) = ("$a", "$b");
    return length($a) <=> length($b) || $a cmp $b;
}

# A reason fit for a screen: stringified, stripped of the croak location -
# which names this module's line, not the rule's problem - and bounded, so a
# store error carrying a request body does not become a TEXT column of it.
sub _reason {
    my ($e) = @_;
    return undef unless defined $e;
    $e = "$e";
    $e =~ s/ at \S+ line \d+\.?\s*\z//s;
    $e =~ s/\s+\z//;
    return undef unless length $e;
    $e = substr($e, 0, 497) . '...' if length($e) > 500;
    return $e;
}

# --- recording --------------------------------------------------------------

# State, event and outbox row in ONE transaction with a rollback guard.
#
# The transaction is the idempotency: a pass that dies here leaves the old
# state, and the re-run re-derives the same transition. The guard is the
# lesson - a die between begin_work and commit with nothing to roll it back
# left the demo's evaluator holding the write lock while it slept, and every
# other writer in the application got "database is locked" with nothing
# visibly contending.
sub _record {
    my ($dbh, $rule, $last, $latest, $now, $wait, $reason) = @_;
    my $moved = 0;
    for my $s (@{ $last->{states} || [] }) {
        my $key = defined $s->{series} && length $s->{series}
                    ? $s->{series} : 'all';
        my $val = $latest->{ $s->{series} // '' };
        my $ok  = eval {
            $moved += _record_one($dbh, $rule, $key, $s->{state},
                                  $s->{since}, $s->{fired_at}, $val,
                                  $now, $wait, $reason);
            1;
        };
        unless ($ok) {
            my $err = $@;
            eval { $dbh->rollback };
            die $err;
        }
    }
    return $moved;
}

# Rows this evaluation did not mention. An error row - the synthetic `all` a
# fail tick records - resolves once the query answers again, which is the
# machine's own re-arm carried across passes; anything else goes stale, which
# is the machine's own vanish carried across passes. A stale row stays as it
# is, and a row the machine spoke for this pass is not touched.
sub _reconcile {
    my ($dbh, $rule, $states, $now, $wait) = @_;
    my %seen;
    for my $s (@{ $states || [] }) {
        my $key = defined $s->{series} && length $s->{series}
                    ? $s->{series} : 'all';
        $seen{$key} = 1;
    }
    my $rows = $dbh->selectall_arrayref(
        'SELECT series, state FROM alert_state WHERE rule_id = ?',
        { Slice => {} }, $rule->{id});
    my $moved = 0;
    for my $row (@$rows) {
        next if $seen{ $row->{series} };
        next if $row->{state} eq 'stale';
        my $to = $row->{state} eq 'error' ? 'ok' : 'stale';
        my $ok = eval {
            $moved += _record_one($dbh, $rule, $row->{series}, $to,
                                  $now, undef, undef, $now, $wait);
            1;
        };
        unless ($ok) {
            my $err = $@;
            eval { $dbh->rollback };
            die $err;
        }
    }
    return $moved;
}

sub _record_one {
    my ($dbh, $rule, $series, $new, $since, $fired, $value, $now, $wait,
        $reason) = @_;

    $dbh->begin_work;
    my $prev = $dbh->selectrow_hashref(
        'SELECT state FROM alert_state WHERE rule_id = ? AND series = ?',
        undef, $rule->{id}, $series);
    my $from = $prev ? $prev->{state} : 'ok';

    $dbh->do(q{
        INSERT INTO alert_state
            (rule_id, series, state, since, fired_at, last_seen, last_value,
             reason)
        VALUES (?,?,?,?,?,?,?,?)
        ON CONFLICT (rule_id, series) DO UPDATE SET
            state = excluded.state, since = excluded.since,
            fired_at = excluded.fired_at, last_seen = excluded.last_seen,
            last_value = excluded.last_value, reason = excluded.reason
    }, undef, $rule->{id}, $series, $new, $since || 0,
       ($new eq 'firing' ? ($fired || $now) : undef), $now, $value,
       ($new eq 'error' ? $reason : undef));

    if ($from ne $new) {
        my $kind = _event_kind($from, $new);
        $dbh->do(q{
            INSERT INTO alert_events
                (rule_id, series, kind, from_state, to_state, value, at)
            VALUES (?,?,?,?,?,?,?)
        }, undef, $rule->{id}, $series, $kind, $from, $new, $value, $now);

        # Kind 0 pages nobody; anything else joins the outbox. The unique
        # key is THE TRANSITION ITSELF - (rule, series, fired_at, at) - so a
        # concurrent leader inserting the same one is refused, and a
        # resolve-and-refire, carrying a new fired_at and a new at, is a new
        # notification rather than a duplicate.
        if ($kind) {
            $dbh->do(q{
                INSERT INTO notifications
                    (rule_id, series, kind, value, at, fired_at, created_at)
                VALUES (?,?,?,?,?,?,?)
                ON CONFLICT DO NOTHING
            }, undef, $rule->{id}, $series, $kind, $value, $now,
               ($new eq 'firing' ? ($fired || $now) : ($fired || 0)), $now);
            _attach_to_group($dbh, $rule->{id}, $now, $wait);
        }
    }

    $dbh->commit;
    return $from ne $new ? 1 : 0;
}

# The rule's open group, made if there is none. The partial unique index -
# at most one open group per rule - makes two racing leaders collapse onto
# one row, and makes a member arriving after a flush open a NEW group, which
# is "the forty-first service is a second notification" as schema rather
# than as code.
sub _attach_to_group {
    my ($dbh, $rule_id, $now, $wait) = @_;
    my ($gid) = $dbh->selectrow_array(
        "SELECT id FROM notification_groups
          WHERE rule_id = ? AND state = 'open'", undef, $rule_id);
    unless ($gid) {
        $dbh->do(q{
            INSERT INTO notification_groups (rule_id, opened_at, due_at)
            VALUES (?,?,?) ON CONFLICT DO NOTHING
        }, undef, $rule_id, $now, Punk::Observe::Store::nadd($now, $wait));
        ($gid) = $dbh->selectrow_array(
            "SELECT id FROM notification_groups
              WHERE rule_id = ? AND state = 'open'", undef, $rule_id);
    }
    $dbh->do('UPDATE notifications SET group_id = ?
               WHERE rule_id = ? AND group_id IS NULL AND sent_at IS NULL
                 AND dead = 0', undef, $gid, $rule_id) if $gid;
    return $gid;
}

# --- the flush --------------------------------------------------------------

# Claims due groups and reopens stale claims. Returns the claimed groups
# rather than delivering them: delivery belongs on the queue.
my $LEASE_NS = 900 * 1_000_000_000;      # a claim older than this is a crash

sub _flush {
    my ($dbh, $now, $opt) = @_;
    my $repeat = $opt->{repeat_ns} || 0;

    # A claim nobody followed up is a leader that died between claim and
    # enqueue. Reopened loudly - due now - rather than left to rot.
    $dbh->do(q{
        UPDATE notification_groups SET state = 'open', due_at = ?
         WHERE state = 'claimed' AND claimed_at <= ?
    }, undef, $now, Punk::Observe::Store::nsub($now, $LEASE_NS));

    # A sent group whose rule is firing again past repeat_interval re-enters
    # the queue; one whose rule went quiet retires instead of re-paging.
    if ($repeat) {
        $dbh->do(q{
            UPDATE notification_groups SET state = 'open', due_at = ?
             WHERE state = 'sent' AND next_repeat_at IS NOT NULL
               AND next_repeat_at <= ?
               AND EXISTS (SELECT 1 FROM alert_state s
                            WHERE s.rule_id = notification_groups.rule_id
                              AND s.state IN ('firing','error'))
        }, undef, $now, $now);
        $dbh->do(q{
            UPDATE notification_groups SET next_repeat_at = NULL
             WHERE state = 'sent' AND next_repeat_at IS NOT NULL
               AND next_repeat_at <= ?
               AND NOT EXISTS (SELECT 1 FROM alert_state s
                                WHERE s.rule_id = notification_groups.rule_id
                                  AND s.state IN ('firing','error'))
        }, undef, $now);
    }

    my $due = $dbh->selectall_arrayref(q{
        SELECT id, rule_id FROM notification_groups
         WHERE state = 'open' AND due_at <= ? ORDER BY id
    }, { Slice => {} }, $now);

    my (@claimed, $enqueued);
    for my $g (@$due) {
        # Single-winner claim: rows-affected zero means another leader took
        # it, which is a loss it is allowed to have.
        my $n = $dbh->do(q{
            UPDATE notification_groups
               SET state = 'claimed', claimed_at = ?, attempts = 0
             WHERE id = ? AND state = 'open' AND due_at <= ?
        }, undef, $now, $g->{id}, $now);
        next unless $n && $n != 0;
        push @claimed, { id => $g->{id}, rule_id => $g->{rule_id},
                         token => $now };
    }
    return (\@claimed, scalar @claimed);
}

# --- delivery ---------------------------------------------------------------

# notify(db => $backend, group => $id, token => $t, on_alert => sub {...},
#        prefix => '/observe', app => $class)
#
# Loads the claimed group, suppresses silenced members, builds ONE callback
# invocation, marks sent. Returns what happened rather than hiding it:
#   { status => 'sent' | 'stale' | 'empty', ... }
#
# A stale token - the group was reaped and re-claimed while this job sat in
# the queue - is a LOUD NO-OP, not a die: dying would spend five retries
# delivering nothing.
sub notify {
    my (%opt) = @_;
    my $db  = $opt{db} or Carp::croak('Evaluate::notify needs db');
    my $dbh = $db->dbh;
    my $gid = $opt{group} or Carp::croak('Evaluate::notify needs group');
    my $now = defined $opt{now} ? $opt{now} : Punk::Observe::now_ns();

    my $g = $dbh->selectrow_hashref(q{
        SELECT g.*, r.tenant, r.name, r.query, r.op, r.threshold,
               r.for_ns, r.every_ns
          FROM notification_groups g JOIN alert_rules r ON r.id = g.rule_id
         WHERE g.id = ?
    }, undef, $gid);
    return { status => 'stale' }
        unless $g && $g->{state} eq 'claimed'
            && defined $opt{token} && "$g->{claimed_at}" eq "$opt{token}";

    my $members = $dbh->selectall_arrayref(q{
        SELECT id, series, kind, value, at, fired_at FROM notifications
         WHERE group_id = ? AND sent_at IS NULL AND dead = 0
         ORDER BY at, id
    }, { Slice => {} }, $gid);

    # SILENCES ARE CHECKED HERE, AT DELIVERY, not at insert - a silence
    # created after a member was enqueued but before its group came due must
    # still suppress it. Suppression is RECORDED on the row, so the screen
    # can say why nobody was paged; the state machine never hears of it.
    my $sil = $dbh->selectall_arrayref(
        'SELECT pattern, is_prefix FROM silences
          WHERE tenant = ? AND until > ?',
        { Slice => {} }, $g->{tenant}, $now);
    my (@send, @quiet);
    for my $m (@$members) {
        my $key = "$g->{name}/$m->{series}";
        if (grep { Punk::Observe::Config::silence_match(
                       @{$_}{qw(pattern is_prefix)}, $key) } @$sil) {
            push @quiet, $m->{id};
        }
        else { push @send, $m }
    }
    $dbh->do('UPDATE notifications SET suppressed = 1 WHERE id IN ('
             . join(',', ('?') x @quiet) . ')', undef, @quiet) if @quiet;

    my %kinds = (1 => 'firing', 2 => 'resolved', 3 => 'vanished', 4 => 'error');
    my $sent = 0;
    if (@send && $opt{on_alert}) {
        # THE CALLBACK IS THE DELIVERY SEAM. Everything the host needs to
        # build a webhook or an email is in the one argument, values raw -
        # nanoseconds where the query measured time - because formatting is
        # the host's, and `delivery_key` is the idempotency token for a host
        # that wants exactly-once on its own side of an at-least-once queue.
        my $event = {
            app    => $opt{app},
            tenant => $g->{tenant},
            rule   => { map { $_ => $g->{$_} }
                        qw(rule_id name query op threshold for_ns every_ns) },
            kind   => $kinds{ $send[0]{kind} } || 'firing',
            series => [ map { {
                series   => $_->{series},
                kind     => $kinds{ $_->{kind} } || '',
                value    => $_->{value},
                at       => "$_->{at}",
                fired_at => "$_->{fired_at}",
            } } @send ],
            count        => scalar @send,
            at           => "$now",
            path         => defined $opt{prefix}
                              ? "$opt{prefix}/alerts/$g->{rule_id}" : undef,
            delivery_key => 'g' . $gid . '.s' . ($g->{sends} + 1),
        };
        $event->{rule}{id} = delete $event->{rule}{rule_id};
        $opt{on_alert}->($event);      # a die propagates: the queue retries
        $sent = scalar @send;
    }

    # Mark-sent is a CAS on the claim token, AFTER the callback: delivery is
    # at-least-once, and the alternative - marking first - is at-most-once,
    # which is a lost page. The POD says so, and delivery_key is the remedy.
    my $n = $dbh->do(q{
        UPDATE notification_groups
           SET state = 'sent', sent_at = COALESCE(sent_at, ?),
               last_sent_at = ?, sends = sends + 1,
               next_repeat_at = ?
         WHERE id = ? AND state = 'claimed' AND claimed_at = ?
    }, undef, $now, $now,
       ($opt{repeat_ns} ? Punk::Observe::Store::nadd($now, $opt{repeat_ns})
                        : undef),
       $gid, $opt{token});
    $dbh->do('UPDATE notifications SET sent_at = ?
               WHERE group_id = ? AND sent_at IS NULL AND suppressed = 0
                 AND dead = 0', undef, $now, $gid) if $n && $n != 0;

    return { status => (@send ? 'sent' : 'empty'), delivered => $sent,
             suppressed => scalar @quiet };
}

# --- the queue entry points -------------------------------------------------

# Both bodies recover the plugin's state from the app class in the args -
# the Mailer pattern, because a task body receives ($job, @args) and nothing
# else, and the worker compiled the same app class so registration has run.
sub _plugin_state {
    my ($class) = @_;
    require Punk::Plugin::Observe;
    my $st = Punk::Plugin::Observe->state_for($class)
        or Carp::croak("Punk::Observe::Evaluate: no Observe plugin state for "
                     . "$class - is the worker running the same application "
                     . "class as the server?");
    return $st;
}

sub evaluate_job {
    my ($job, $class) = @_;
    my $st = _plugin_state($class);
    my $q  = $job->queue_object;

    # The queue's cron dedupe is per occurrence, but execution is
    # at-least-once and workers are many: the lease is what makes the pass
    # single-flight. Losing it is a result, not an error.
    my $owner = 0 + $$;
    return { skipped => 'lock' }
        unless $q->lock('observe.evaluate', 60, owner => $owner);

    my $out = eval { run(
        db     => $st->{db},
        store  => Punk::Plugin::Observe::store_for($st,
                      $st->{tenant}{fixed} || 'default'),
        group_wait_ns => $st->{alerts_opts}{group_wait_ns},
        repeat_ns     => $st->{alerts_opts}{repeat_ns},
    ) };
    my $err = $@;

    for my $g (@{ $out ? $out->{groups} : [] }) {
        $q->enqueue('observe.notify' => [ $class, $g->{id}, "$g->{token}" ]);
    }
    $q->unlock('observe.evaluate', $owner) if $q->can('unlock');
    die $err if $err;
    return { evaluated => $out->{evaluated},
             transitions => $out->{transitions},
             enqueued => $out->{enqueued} };
}

sub notify_job {
    my ($job, $class, $gid, $token) = @_;
    my $st = _plugin_state($class);

    my $out = eval { notify(
        db       => $st->{db},
        group    => $gid,
        token    => $token,
        on_alert => $st->{opts}{on_alert},
        repeat_ns => $st->{alerts_opts}{repeat_ns},
        prefix   => $st->{prefix},
        app      => $class,
    ) };
    if (my $err = $@) {
        # The attempt count and the error land on the GROUP, where the screen
        # can show them; the final failure is a dead letter, recorded and
        # loud, never dropped - and the next fire opens a fresh group, so one
        # unreachable webhook does not stop alerting.
        my $dbh  = $st->{db}->dbh;
        my $last = ($job->retries + 1) >= 5;
        $dbh->do('UPDATE notification_groups
                     SET attempts = attempts + 1, last_error = ?'
               . ($last ? ", state = 'dead'" : '')
               . ' WHERE id = ?', undef, "$err", $gid);
        $dbh->do("UPDATE notifications SET dead = 1, last_error = ?
                   WHERE group_id = ? AND sent_at IS NULL", undef, "$err", $gid)
            if $last;
        die $err;
    }
    return $out;
}

# cron_task(%opt) - the Health-shaped closure for a host that declares its
# own cron rather than letting the plugin do it. Takes the queue, returns
# the transition count, dies on error.
sub cron_task {
    my (%opt) = @_;
    my $lease = $opt{lease_seconds} || 60;
    my $owner = defined $opt{owner} ? 0 + $opt{owner} : 0 + $$;
    return sub {
        my ($q) = @_;
        return 0 unless $q->lock('observe.evaluate', $lease, owner => $owner);
        my $out = eval { run(%opt) };
        my $err = $@;
        if ($out && $opt{on_alert}) {
            for my $g (@{ $out->{groups} }) {
                my $n = eval { notify(%opt, group => $g->{id},
                                      token => "$g->{token}") };
                $err ||= $@ if $@;
            }
        }
        $q->unlock('observe.evaluate', $owner) if $q->can('unlock');
        die $err if $err;
        return $out ? $out->{transitions} : 0;
    };
}

1;

__END__

=head1 NAME

Punk::Observe::Evaluate - the alert evaluation pass, and its delivery

=head1 SYNOPSIS

    # what the plugin registers on the host's queue - nothing to write:
    #   task observe.evaluate   the pass
    #   task observe.notify     one delivery, retried by the queue
    #   cron observe-evaluate   @every 30s

    # the pass, directly, for a host or a test that has no queue
    my $out = Punk::Observe::Evaluate::run(db => $backend, store => $store);
    # { evaluated => 3, transitions => 1, enqueued => 1, groups => [...] }

    # one delivery
    Punk::Observe::Evaluate::notify(
        db => $backend, group => $id, token => $t,
        on_alert => sub { my ($event) = @_; ... });

=head1 DESCRIPTION

The loop every host used to write, in the distribution.

Rules live in the configuration store and are edited on the alerts screen;
this module reads them, queries the telemetry store, drives
L<Punk::Observe::Alert>'s state machine, records state and transitions, and
hands deliveries to the queue. The host's whole contribution is the
C<on_alert> callback - delivery is the one thing the core cannot know.

=head2 One pass

Each rule keeps its own cadence inside the shared pass: the cron interval is
the resolution, the rule's C<every> is honoured on top of it. The query
window is derived from the rule - twice its C<for>, four of its C<every>,
never less than fifteen minutes - rather than fixed, so a five-minute rule
does not read an hour of data and a forty-minute one is not starved.

A query that fails or answers with the wrong shape becomes a B<fail tick>,
so the state machine's own error latch does the work: the rule goes to
C<error>, notifies once, and re-arms on the next successful evaluation.
Hand-recording error states beside the machine is how the demo got that
wrong. The failure's B<reason> - the store's error, or "add a bucket stage"
for the unbucketed query somebody writes by accident - is written onto the
state row and shown on the alerts screen, and cleared when the rule
recovers, so it can never be stale.

An B<empty successful answer is not a failure>: a query that answered with
no series in the window is every series vanishing, which is the machine's
stale semantics rather than its error latch. And a successful evaluation
B<reconciles> the rule's state rows it did not mention: an C<error> row -
including the synthetic C<all> a fail tick records - resolves to C<ok>, and
anything else goes C<stale>, exactly as it would had the series vanished
within one run. Without this, a rule whose query was fixed to group by a
label kept its old error row for ever, because no evaluation mentioned that
series again. A failed pass reconciles nothing - a query that could not run
says nothing about which series exist.

State, transition and outbox row are written in B<one transaction with a
rollback guard>. The transaction is the idempotency - a crashed pass leaves
the old state and the re-run re-derives the same transition - and the guard
is a lesson paid for: a die between C<begin_work> and C<commit> with nothing
to roll it back left an evaluator holding the write lock while it slept, and
every other writer in the application saw "database is locked".

=head2 Grouping, and the outbox

One bad deploy is one message listing forty series, not forty messages.
Notifying transitions join their rule's B<open group>; the group holds for
C<group_wait> and is then claimed and delivered whole. At most one group per
rule is open at a time - enforced by a partial unique index, not by code
remembering to - so a series arriving after its group flushed opens a new
one: the forty-first service is a second notification, not a lost one.

The outbox key is the transition itself: C<(rule, series, fired_at, at)>. A
concurrent leader inserting the same transition is refused, and a
resolve-and-refire carries new instants and is a new notification. Keying on
C<fired_at> alone would have silently dropped every error episode after the
first, because a rule that cannot evaluate has no C<fired_at>.

C<repeat_interval> (off unless configured) re-delivers a group whose rule is
B<still> firing; one whose rule went quiet retires instead of re-paging.

=head2 Silences

Checked at B<delivery>, not at insert - a silence created after a member was
enqueued but before its group came due must still suppress it. Suppression
is recorded on the row, so the screen can say why nobody was paged; the
state machine never hears of it, which is what "a silence suppresses
notification, not state" means mechanically.

=head2 Delivery

C<observe.notify> makes one callback invocation per group and lets the queue
own the failure story: a die retries with full jitter, five attempts, and
the terminal failure is a B<dead letter> - recorded on the group and its
members, visible, never dropped. The next fire opens a fresh group, so one
unreachable webhook does not stop alerting.

Delivery is B<at least once>: a crash between the callback returning and the
sent-mark re-delivers. The alternative - marking first - is at most once,
which is a lost page. C<delivery_key> in the event is the idempotency token
for a host that wants exactly-once on its own side.

=head1 FUNCTIONS

=head2 run

    my $out = Punk::Observe::Evaluate::run(
        db => $backend, store => $store,
        now => $ns, tenant => $t, force => 1,
        group_wait_ns => 30e9, repeat_ns => 0);

The pass. Returns C<evaluated>, C<transitions>, C<enqueued> and the claimed
C<groups> - handed back rather than delivered, because delivery belongs on
the queue with its retries, and a test wants to see what would be sent
without sending it. C<now> injects the clock; C<force> ignores each rule's
own cadence.

=head2 notify

    my $r = Punk::Observe::Evaluate::notify(
        db => $backend, group => $id, token => $t,
        on_alert => sub { ... }, prefix => '/observe', app => $class);

One delivery. A stale token - the group was reaped and re-claimed while the
job sat in the queue - is a B<loud no-op>, not a die: dying would spend five
retries delivering nothing. The event handed to C<on_alert> carries the app
class, tenant, the rule row, C<kind>, one entry per series with raw values,
the path to the rule's screen, and C<delivery_key>.

=head2 evaluate_job / notify_job

The Punk::Queue task bodies. Each receives C<($job, $app_class, ...)> and
recovers the plugin's state - store, database, callback - from the class,
because a task body receives its job and its arguments and nothing else, and
the worker compiled the same application class the server did.

=head2 cron_task

    my $code = Punk::Observe::Evaluate::cron_task(db => ..., store => ...,
                                                  on_alert => ...);
    $code->($queue);

The Health-shaped closure, for a host that declares its own cron rather than
letting the plugin register one. Takes the queue, takes the leader lock,
runs the pass, delivers, returns the transition count.

=head1 SEE ALSO

L<Punk::Observe::Alert> - the state machine this drives.
L<Punk::Observe::Route> - the in-memory grouping primitives this persists.
L<Punk::Plugin::Observe> - where the tasks and the cron are registered.

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut

package Punk::Observe::Health;

use 5.010;
use strict;
use warnings;

use Carp ();
use Punk::Observe ();
use Punk::Observe::Store ();
use Punk::Observe::Target ();
use File::Raw::JSON ();
use Fetch;

our $VERSION = $Punk::Observe::VERSION;

use constant {
    M_OK => 'punk.health.ok',
    M_MS => 'punk.health.ms',
};

# The store's budgets default to 500,000 when left unset. A STRING, not
# `1 << 62`, because a perl with 32-bit integers does not have that number and
# would quietly pass something else; the store parses nanosecond-width decimals
# everywhere already.
use constant NO_CEILING => '4611686018427387904';

# Every query here is one this file wrote, and every one of them is an
# aggregate over the window - so none can be answered by stopping part way. An
# uptime band that stops mid-window reports a service as up because the scan
# ran out, which is the one reading this page must never give. It is also what
# keeps the page cheap: a chunk that truncates is never cached, so a query left
# on the default ceiling has its busiest chunk rescanned on every poll.
sub _read {
    my ($store, @args) = @_;
    push @args, limit => NO_CEILING, hard_max => NO_CEILING,
                max_rows => NO_CEILING;
    return $store->can('cached_query')
         ? $store->cached_query(@args)
         : $store->query(@args);
}

sub _rec {
    my ($t, $name, $value, $attrs) = @_;
    return { t => $t, kind => 1, body => $name, value => $value + 0,
             severity => 0, span_kind => 0, status => 0,
             trace_hi => 0, trace_lo => 0, span_id => 0, parent_id => 0,
             attrs => $attrs };
}

sub points {
    my ($target, $status, $body, $now, $rtt_ms) = @_;
    $now = Punk::Observe::now_ns() unless defined $now;
    my @recs;

    push @recs, _rec($now, M_MS, 0 + sprintf('%.3f', $rtt_ms),
                     { target => $target })
        if defined $rtt_ms && $status;

    if (!defined $status || !$status) {
        push @recs, _rec($now, M_OK, 0,
                         { target => $target, state => 'unreachable' });
        return (\@recs, 'error');
    }

    my $doc = eval { File::Raw::JSON::file_json_decode($body) };
    if (!$doc || ref $doc ne 'HASH') {
        push @recs, _rec($now, M_OK, 0,
                         { target => $target, state => 'unknown' });
        return (\@recs, 'error');
    }

    my $ready = (defined $doc->{status} && $doc->{status} eq 'ok') ? 1 : 0;
    $ready = 0 if $status >= 500;
    push @recs, _rec($now, M_OK, $ready,
                     { target => $target,
                       state  => ($ready ? 'ready' : 'unready') });

    my $checks = $doc->{checks};
    return (\@recs, $ready ? 'ok' : 'error')
        unless ref $checks eq 'HASH' && %$checks;

    for my $name (sort keys %$checks) {
        my $c = $checks->{$name};
        next unless ref $c eq 'HASH';
        my $labels = { target => $target, check => $name };

        if ($c->{skipped}) {
            $labels->{skipped} = 'true';
            push @recs, _rec($now, M_OK, 0, $labels);
            next;
        }

        push @recs, _rec($now, M_OK, ($c->{ok} ? 1 : 0), $labels);
        push @recs, _rec($now, M_MS, ($c->{ms} || 0) + 0, $labels)
            if defined $c->{ms};
    }

    return (\@recs, $ready ? 'ok' : 'error');
}

sub poll {
    my ($target, %opt) = @_;
    my $now = $opt{now} || Punk::Observe::now_ns();
    my $url = $target->{url};

    my $t = Punk::Observe::Target::check($url, $opt{allow});
    return (points($target->{name}, 0, '', $now))[0] unless $t->{ok};

    my $timeout = ($target->{timeout_ms} || 5000) / 1000;
    my ($status, $body) = (0, '');
    require Time::HiRes;
    my $t0 = Time::HiRes::time();

    eval {
        my $ua = $opt{ua};
        unless ($ua) {
            $ua = Fetch->new(timeout => $timeout,
                             ($opt{loop} ? (loop => $opt{loop}) : ()));
        }
        my $res = $ua->get($url)->get;
        if ($res) {
            $status = $res->status;
            $body   = $res->content;
            $body   = '' unless defined $body;
        }
        1;
    };
    my $rtt_ms = (Time::HiRes::time() - $t0) * 1000;
    return (points($target->{name}, $status, $body, $now, $rtt_ms))[0];
}

sub run {
    my (%opt) = @_;
    my $db     = $opt{db}     or return [];
    my $tenant = defined $opt{tenant} ? $opt{tenant} : 'default';
    my $now    = $opt{now} || Punk::Observe::now_ns();

    require Punk::Observe::Config;
    my $targets = Punk::Observe::Config::health_targets($db, $tenant);
    return [] unless ref $targets eq 'ARRAY';

    my $ua = $opt{ua};
    if (!$ua && $opt{loop}) {
        eval { require Fetch; $ua = Fetch->new(loop => $opt{loop}); 1 };
    }

    my @recs;
    for my $t (@$targets) {
        next unless $t->{enabled};
        my $r = eval { poll($t, ua => $ua, allow => $opt{allow}, now => $now) };
        push @recs, @$r if ref $r eq 'ARRAY';
    }
    return \@recs;
}

sub run_and_store {
    my (%opt) = @_;
    my $store = $opt{store} or return 0;
    my $recs  = run(%opt);
    return 0 unless @$recs;

    require Punk::Observe::WAL;
    my $r = Punk::Observe::WAL::append($store->wal_path, $recs, 1, '200000000');
    return 0 unless $r && $r->{ok} && $r->{frames};
    $store->seal_if_full($r->{bytes} || 0);
    return scalar @$recs;
}

sub page_vars {
    my (%opt) = @_;
    my $store  = $opt{store};
    my $db     = $opt{db};
    my $tenant = defined $opt{tenant} ? $opt{tenant} : 'default';
    my $now    = $opt{now} || Punk::Observe::now_ns();
    my $window = $opt{window_ns} || 3_600 * 1_000_000_000;
    my $from   = Punk::Observe::Store::nsub($now, $window);

    my $targets = $db
        ? eval { require Punk::Observe::Config;
                 Punk::Observe::Config::health_targets($db, $tenant) }
        : undef;
    $targets = [] unless ref $targets eq 'ARRAY';

    my @out;
    for my $t (@$targets) {
        my $row = {
            name    => $t->{name},
            url     => $t->{url},
            every_s    => int(($t->{every_ns} || 60_000_000_000) / 1_000_000_000),
            timeout_ms => $t->{timeout_ms} || 5000,
            enabled => ($t->{enabled} ? 1 : 0),
            state   => ($t->{enabled} ? 'never polled' : 'disabled'),
            ok      => 0,
            held    => 0,
            held_min => 0,
            checks  => [],
        };
        push @out, $row;
        next unless $store && $t->{enabled};

        my $secs = int(($t->{every_ns} || 60_000_000_000) / 1_000_000_000) || 60;
        my $q = sprintf('metric %s | where target == "%s" | bucket(%ds) min by check',
                        M_OK, $t->{name}, $secs);
        my $res = eval { _read($store, $q, from => $from, to => $now) };
        next unless $res && $res->{ok} && ref $res->{series} eq 'ARRAY';

        for my $s (@{ $res->{series} }) {
            my @pts = @{ $s->{points} || [] };
            next unless @pts;
            @pts = sort { Punk::Observe::Store::ncmp($a->[0], $b->[0]) } @pts;

            my $last = $pts[-1];
            my $val  = ($last->[1] || 0) >= 1 ? 1 : 0;

            my $since = $last->[0];
            my $walked = 0;
            for my $p (reverse @pts) {
                last if ((($p->[1] || 0) >= 1) ? 1 : 0) != $val;
                $since = $p->[0];
                $walked++;
            }
            my $held = Punk::Observe::Store::nsub($now, $since);

            my $capped = ($walked >= scalar @pts) ? 1 : 0;

            my $key = defined $s->{key} ? $s->{key} : '';
            if (!length $key) {
                $row->{ok}       = $val;
                $row->{held}     = $held;
                $row->{held_min} = $capped;
                $row->{state}    = $val ? 'ready' : 'not ready';
            }
            else {
                push @{ $row->{checks} }, {
                    name     => $key,
                    ok       => $val,
                    state    => ($val ? 'ok' : 'failing'),
                    held     => $held,
                    held_min => $capped,
                };
            }
        }
        @{ $row->{checks} } = sort { $a->{name} cmp $b->{name} }
                              @{ $row->{checks} };

        my $qm = sprintf('metric %s | where target == "%s" | bucket(%ds) max by check',
                         M_MS, $t->{name}, $secs);
        my $ms = eval { _read($store, $qm, from => $from, to => $now) };
        if ($ms && $ms->{ok} && ref $ms->{series} eq 'ARRAY') {
            my %by_check;
            for my $s (@{ $ms->{series} }) {
                my @pts = sort { Punk::Observe::Store::ncmp($a->[0], $b->[0]) }
                          @{ $s->{points} || [] };
                next unless @pts;
                my $key = defined $s->{key} ? $s->{key} : '';
                my $val = sprintf('%.2f', $pts[-1][1] || 0);
                if (!length $key) { $row->{ms} = $val }
                else              { $by_check{$key} = $val }
            }
            for my $c (@{ $row->{checks} }) {
                $c->{ms} = $by_check{ $c->{name} }
                    if exists $by_check{ $c->{name} };
            }
        }
    }
    return \@out;
}

my $UP_BUCKETS = 120;          # across the window, whatever it is
my $UP_MIN_NS  = 30 * 1_000_000_000;

sub _up_bucket_ns {
    my ($from, $to) = @_;
    my $span = Punk::Observe::Store::nsub($to, $from);
    my $each = int(($span + 0) / $UP_BUCKETS);
    $each = $UP_MIN_NS if $each < $UP_MIN_NS;
    my $secs = int($each / 1_000_000_000) || 1;
    return $secs;
}

sub uptime_events {
    my (%opt) = @_;
    my $store = $opt{store} or return [];
    my ($from, $to) = @opt{qw(from to)};
    return [] unless defined $from && defined $to;

    my $secs = _up_bucket_ns($from, $to);
    my $res  = eval {
        _read($store, 'metric ' . M_OK . " | bucket(${secs}s) min by target, check",
              from => $from, to => $to)
    };
    return [] unless $res && $res->{ok} && ($res->{shape} || '') eq 'buckets';

    my @ev;
    for my $ser (@{ $res->{series} || [] }) {
        my ($target, $check) = split /\x1f/, ($ser->{key} // ''), 2;
        next unless defined $target && length $target;
        my $label = (defined $check && length $check)
                  ? "$target \x{203a} $check" : $target;

        my @pts = sort { length($a->[0]) <=> length($b->[0])
                      || $a->[0] cmp $b->[0] } @{ $ser->{points} || [] };
        my $last = '';
        for my $p (@pts) {
            my $state = (($p->[1] // 0) >= 1) ? 'up' : 'down';
            next if $state eq $last;
            push @ev, { series => $label, at => "$p->[0]", to => $state };
            $last = $state;
        }
    }
    return \@ev;
}

sub _plugin_state {
    my ($class) = @_;
    require Punk::Plugin::Observe;
    my $st = Punk::Plugin::Observe->state_for($class)
        or Carp::croak("Punk::Observe::Health: no Observe plugin state for "
                     . "$class - is the worker running the same application "
                     . "class as the server?");
    return $st;
}

sub health_job {
    my ($job, $class) = @_;
    my $st = _plugin_state($class);
    my $q  = $job->queue_object;

    my $owner = 0 + $$;
    return { skipped => 'lock' }
        unless $q->lock('observe.health', 60, owner => $owner);

    my $n = eval { run_and_store(
        db    => $st->{db},
        store => Punk::Plugin::Observe::store_for(
                     $st, $st->{tenant}{fixed} || 'default'),
        allow => $st->{opts}{health_allow},
    ) };
    my $err = $@;
    $q->unlock('observe.health', $owner) if $q->can('unlock');
    die $err if $err;
    return { points => $n || 0 };
}

sub cron_task {
    my (%opt) = @_;
    my $db     = $opt{db};
    my $store  = $opt{store};
    my $owner  = $opt{owner};
    $owner = $$ unless defined $owner && $owner =~ /\A[0-9]+\z/;
    my $lease  = $opt{lease_seconds} || 30;

    return sub {
        my ($q) = @_;
        return 0 unless $q && $db && $store;

        return 0 unless $q->lock('leader', $lease, owner => $owner);

        my $n = eval {
            run_and_store(db => $db, store => $store,
                          tenant => $opt{tenant}, allow => $opt{allow},
                          loop => $opt{loop}, ua => $opt{ua});
        };
        my $err = $@;

        $q->renew_lock('leader', $owner, $lease);

        die $err if $err;
        return $n || 0;
    };
}

1;

__END__

=head1 NAME

Punk::Observe::Health - poll the services being observed

=head1 SYNOPSIS

    my ($recs, $state) = Punk::Observe::Health::points(
        'shop', 503, '{"status":"unready","checks":{"db":{"ok":false}}}');

=head1 DESCRIPTION

A client for a protocol that already exists. Every Punk service with
L<Punk::Plugin::Health> enabled has a C</readyz> that runs its registered
checks and answers with named checks, a boolean, a duration and a reason.
Nothing had been reading it.

=head2 C</readyz>, not C</healthz>

C</healthz> runs zero checks by construction: the liveness callback is never
given the check list. It answers "this process is up and serving", which is
worth knowing and is not health. Polling it and calling the answer a health
check would be a filter that is never applied wearing a different hat.

=head2 The result is a metric, which is why there is no new alerting code

Each poll writes metric points. Because they are ordinary metrics, everything
downstream already works: the history is queryable in OQL, a dashboard panel
charts it with no new panel type, and the alert evaluator fires on it with no
new rule type. C<punk.health.ok> below 1 for five minutes B<is> the alert,
expressible in the language today.

That is the argument for storing rather than showing live. A status page that
polls on request can say what is broken now; it cannot say "this has been
flapping since 03:00", which is the question during an incident.

=head2 Two metrics, and a label for the third answer

    punk.health.ok    value 1|0   by target, check
    punk.health.ms    value ms    by target, check

The target-level answer is the same metric with B<no> C<check> label, which is
how this language already spells an ungrouped series - so C<| by check> puts it
in the group with the empty key rather than needing a check name invented for
it to hang on. A reader that wants only the per-check series asks for the ones
that have a check:

    metric punk.health.ok | where check != ""

A target can be B<ready>, B<unready> or B<unreachable>, and collapsing the last
two is the tempting simplification: "the database check failed" and "we could
not ask" lead to different actions. All three are C<ok = 0> or C<1> and carry a
C<state> label saying which - so an alert can ignore the distinction
(C<punk.health.ok> below 1 for five minutes is the rule either way) and an
operator looking at the page can see it.

A fourth, C<unknown>, is a target that answered something that is not JSON - a
proxy error page, most often. It is not the service reporting itself unhealthy,
and it is not a pass.

=head1 FUNCTIONS

=head2 points

    my ($recs, $state) = points($target, $http_status, $body, $now_ns);

An HTTP answer as metric records. Pure: no I/O, so every failure mode is a
fixture rather than a network condition to reproduce. A false or zero
C<$http_status> means the request never completed.

=head2 poll

    my $recs = poll(\%target, ua => $ua, allow => \@allowlist, now => $ns);

One poll. The SSRF policy is re-checked here rather than trusted from save
time, because a row can be edited by anything holding the database and an
allowlist can be narrowed after a target was stored.

B<Pass C<ua>, or C<loop>.> Awaiting a L<Fetch::Future> runs the loop the agent
was built on. Omitting both gives L<Fetch::Loop::Standalone>, and awaiting
that inside a Hyperman worker drives a loop which is not the worker's - so the
request being served waits on a health poll of an unrelated service. The cron
task builds one agent on the worker's loop and passes it down; a caller with
no loop at all still works, which is what the hand-runnable binary and the
tests rely on.

C<ua> also takes anything with a C<get> returning a future, which is how the
tests avoid a network.

=head2 run / run_and_store

    my $recs = run(db => $db, tenant => 'default', loop => $loop);
    my $n    = run_and_store(db => $db, store => $store, loop => $loop);

Every enabled target, once. C<run> returns the records so a caller decides
where they go; C<run_and_store> appends them and seals if the log is full.

B<Never on the request that draws the screen.> A poll is outbound network I/O
with a timeout, so putting it in the request makes the status page as slow as
the slowest target and hangs it when one blackholes packets. It belongs in a
cron task under the leader lease - and the lease matters for the same reason
it matters for compaction: four workers must not all poll the same target, or
the history is four times the traffic and the C<ms> series is meaningless.

One agent is built for the whole pass rather than one per target, and a target
that throws does not take the pass down: the next one still needs polling.

=head2 uptime_events

    my $events = Punk::Observe::Health::uptime_events(
        store => $store, from => $ns, to => $ns);

The up-and-down bands the health chart draws, one series per target and per
check, in the shape L<Punk::Observe::Plot/alert_timeline> takes.

Derived from the polls, B<not> from a transitions table - health has none, and
adding one would put the same truth in two places that can disagree. The
window is bucketed into about a hundred and twenty bands, never finer than
thirty seconds, and a band is emitted only where the state B<changed>: a
target that never failed is one band rather than one per poll.

C<min> over the bucket, deliberately. A bucket in which B<any> poll failed is
a bucket the service was down in; an average would render a minute with one
failure in five as mostly up, which is the reading that loses the incident.
A bucket holding no poll at all is not drawn as down - nobody looked - so the
bands either side of it simply meet.

What this replaced was a bar per target of its most recent poll latency: a
number the table already prints, beside which a service that had been down
for forty minutes drew the same bar as a healthy one.

=head2 cron_task

    my $code = Punk::Observe::Health::cron_task(
        db => $db, store => $store, loop => $loop, owner => $$);
    # register with whatever schedules work in your application:
    $q->enqueue('observe.health' => ...);   # or a cron entry calling $code

Returns a coderef that takes a L<Punk::Queue> and runs one pass B<under the
leader lease>. C<owner> must be an B<integer> - the queue's own is an IV, and
a string numifies to zero, which would give every worker in the pool the same
owner and let one renew another's lease. It defaults to the pid. The lease is the point rather than the schedule: four workers
must not all poll the same target, or the history is four times the traffic
and the C<ms> series is meaningless.

Losing the race is the normal case on a pool and returns 0 without polling -
another worker is doing the pass. That is not an error.

This is the shape the rest of the periodic work takes: compaction, retention
and alert evaluation are cron tasks under the same lease, so all four inherit
election, restart, backoff and the admin UI rather than reinventing them four
times.

Register it with the C<cron> keyword L<Punk::Plugin::Queue> installs:

    plugin 'Queue' => { dsn => ... };
    cron '*/1 * * * *' => Punk::Observe::Health::cron_task(
        db => $db, store => $store), { name => 'observe-health' };

The lease is still taken inside the task rather than assumed from the
scheduler: the scheduler runs B<in the pool>, so without it four workers can
each fire the same minute. F<bin/punk-observe-health> runs the same pass by
hand for a host that would rather drive it from system cron, and for the
question this is usually run to settle at 3am.

=head1 SEE ALSO

L<Punk::Plugin::Health>, L<Punk::Observe::Target>, L<Punk::Observe::Config>

=cut

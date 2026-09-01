#!perl
# Health polling: an HTTP answer becomes metric points.
#
# FIXTURE BODIES, NO NETWORK. The parse is a pure function precisely so that
# every failure mode here is a string rather than a network condition somebody
# has to reproduce - a target that blackholes packets is not something a test
# suite can arrange, and the interesting cases are all about what came back.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);

BEGIN {
    eval { require File::Raw::JSON; 1 }
        or plan skip_all => 'File::Raw::JSON not installed';
}
use Punk::Observe;
use Punk::Observe::Health;
use Punk::Observe::Target;

my $H  = 'Punk::Observe::Health';
my $NS = '1774224000000000000';

# The points as a lookup: "metric{label=value,...}" => value.
sub pts {
    my ($status, $body) = @_;
    my ($recs, $state) = $H->can('points')->('shop', $status, $body, $NS);
    my %by;
    for my $r (@$recs) {
        my $a = $r->{attrs} || {};
        my $k = $r->{body} . '{'
              . join(',', map { "$_=$a->{$_}" } sort keys %$a) . '}';
        $by{$k} = $r->{value};
    }
    return (\%by, $state, scalar @$recs);
}

# --- unreachable is not unready ---------------------------------------------
#
# Collapsing the two is the tempting simplification and it is wrong: "the
# database check failed" and "we could not ask" lead to different actions.
{
    my ($p, $state, $n) = pts(0, '');
    is($p->{'punk.health.ok{state=unreachable,target=shop}'}, 0,
       'an unreachable target is a zero labelled unreachable');
    is($n, 1, '  and nothing else is recorded');
    ok(!exists $p->{'punk.health.ok{state=unready,target=shop}'},
       '  NOT unready: we could not ask, which is a different action');
    is($state, 'error', '  the poll is an error');
}

# --- a 200 carrying "unready" is unready, not unreachable -------------------
#
# Two different fields. The HTTP status says whether the poll worked; the body
# says whether the service is ready.
{
    my ($p) = pts(200, '{"status":"unready","checks":{"db":{"ok":false,"ms":9}}}');
    is($p->{'punk.health.ok{state=unready,target=shop}'}, 0,
       'a 200 saying unready is unready');
    ok(!exists $p->{'punk.health.ok{state=unreachable,target=shop}'},
       '  and not unreachable - the poll worked');
    is($p->{'punk.health.ok{check=db,target=shop}'}, 0, '  the db check failed');
}

# --- the passing case ------------------------------------------------------
{
    my ($p, $state) = pts(200,
        '{"status":"ok","checks":{"cache":{"ok":true,"ms":0.04}}}');
    is($p->{'punk.health.ok{state=ready,target=shop}'}, 1, 'a ready target is ready');
    is($p->{'punk.health.ok{check=cache,target=shop}'}, 1, '  its check passed');
    # A check's own ms is carried through from the body as the float64 it was
    # parsed as, never re-rounded - rounding a service's own number would
    # invent precision it did not claim. So on a perl whose NV is wider than a
    # double this keeps the tail of the float64, and the comparison is against
    # the 15 digits a float64 is unambiguous at. The poll's own round trip
    # below goes through sprintf, so that one does compare against a literal.
    is(sprintf('%.15g', $p->{'punk.health.ms{check=cache,target=shop}'}),
       '0.04', '  and took 0.04ms');
    is($state, 'ok', '  and the poll is ok');
}

# --- the poll's own round trip is a point ------------------------------------
#
# The target row's latency is the poll round trip, held against the timeout.
# Recorded only when an answer arrived: an unreachable target has no duration,
# and the timeout written as one makes a dead service look merely slow.
{
    my ($recs) = Punk::Observe::Health->can('points')->(
        'shop', 200, '{"status":"ok"}', $NS, 12.3456);
    my ($ms) = grep { $_->{body} eq 'punk.health.ms'
                   && !exists $_->{attrs}{check} } @$recs;
    ok($ms, 'a reached target records its round trip');
    is($ms->{value}, 12.346, '  to the millisecond precision the wire needs');
    is_deeply($ms->{attrs}, { target => 'shop' },
              '  with no check label, so it reads back as the target series');

    my ($recs2) = Punk::Observe::Health->can('points')->(
        'shop', 0, '', $NS, 5000.1);
    ok(!(grep { $_->{body} eq 'punk.health.ms' } @$recs2),
       'an unreachable target records no duration, even though one elapsed');
}

# --- detail off is a degraded answer, not an error --------------------------
#
# Per-check output is gated behind `detail => 1` because probe endpoints are
# unauthenticated. A target with it off yields a status and no breakdown, and
# the page has to render that rather than treating it as a failure.
{
    my ($p, $state, $n) = pts(200, '{"status":"ok"}');
    is($p->{'punk.health.ok{state=ready,target=shop}'}, 1,
       'detail off: the target answers ready');
    is($n, 1, '  with no per-check series at all');
    is($state, 'ok', '  and it is not an error');
}

# --- a skipped check is not a passing one, and not a failing one either -----
#
# The budget refuses to START a check once the time is spent and marks it
# skipped. Those carry ok:false, but they never ran - so recording them as a
# plain failure would report an outage the service never had.
{
    my ($p) = pts(503,
        '{"status":"unready","checks":{"a":{"ok":true,"ms":1},'
      . '"b_next":{"ok":false,"skipped":true}}}');

    is($p->{'punk.health.ok{check=a,target=shop}'}, 1, 'the check that ran passed');
    is($p->{'punk.health.ok{check=b_next,skipped=true,target=shop}'}, 0,
       'a skipped check is not recorded as passing');
    ok(!exists $p->{'punk.health.ok{check=b_next,target=shop}'},
       '  and is labelled, so it is not read as a failure that happened');
    ok(!exists $p->{'punk.health.ms{check=b_next,skipped=true,target=shop}'},
       '  with no duration, because it has none');
}

# --- a non-JSON body is a reached target that answered something else -------
#
# A proxy returning an HTML error page is the common case, and it is not the
# service saying it is unhealthy.
{
    my ($p, $state, $n) = pts(200, '<html><body>502 Bad Gateway</body></html>');
    is($p->{'punk.health.ok{state=unknown,target=shop}'}, 0,
       'a non-JSON body is unknown, not unready');
    ok(!exists $p->{'punk.health.ok{state=unready,target=shop}'},
       '  because a proxy error page is not the service reporting itself');
    is($state, 'error', '  and the poll did not get an answer it understands');
}

# --- checks come back in name order ----------------------------------------
# The health plugin reports them sorted so two answers can be diffed. The
# points keep that, or a diff shows what moved rather than what changed.
{
    my ($recs) = $H->can('points')->('shop', 200,
        '{"status":"ok","checks":{"zeta":{"ok":true},"alpha":{"ok":true},'
      . '"mid":{"ok":true}}}', $NS);
    my @names = map { $_->{attrs}{check} }
                grep { $_->{body} eq 'punk.health.ok'
                       && exists $_->{attrs}{check} } @$recs;
    is_deeply(\@names, [qw(alpha mid zeta)], 'checks are in name order');
}

# --- the SSRF policy is the one that already exists ------------------------
#
# Asserted by agreement rather than by restating the list: a second copy of
# the rules is a second thing to keep correct, and the one that drifts is the
# one nobody is looking at.
{
    my @cases = (
        'http://169.254.169.254/readyz',     # cloud metadata
        'http://127.0.0.1:5000/readyz',      # loopback
        'http://10.0.0.5/readyz',            # private range
        'ftp://example.com/readyz',          # not http
        'http://metadata.google.internal/',  # by name
    );
    for my $u (@cases) {
        my $t = Punk::Observe::Target::check($u, undef);
        ok(!$t->{ok}, "Target refuses $u") or next;

        # And a poll of it records an unreachable rather than making the
        # request. The policy is re-checked at poll time, not trusted from
        # save time, because a row can be edited by anything with the
        # database and an allowlist can be narrowed after the fact.
        my $recs = $H->can('poll')->({ name => 'x', url => $u, timeout_ms => 100 },
                                     now => $NS);
        is(scalar @$recs, 1, "  polling it records only that it is down");
        is($recs->[0]{body}, 'punk.health.ok', '  as punk.health.ok');
        is($recs->[0]{attrs}{state}, 'unreachable', '  labelled unreachable');
        is($recs->[0]{value}, 0, '  with value 0');
    }

    # The allowlist is the answer for a self-hosted install watching private
    # services, and the refusal has to say so or nobody finds it.
    my $t = Punk::Observe::Target::check('http://127.0.0.1:5000/readyz',
                                         ['127.0.0.1']);
    ok($t->{ok}, 'an allowlist admits the host it names');
}

# --- the points are storable, and queryable in OQL --------------------------
#
# THE GATE, in miniature. If these are ordinary metric points then the history
# is queryable with no new code, which is the whole argument for storing them
# rather than showing a live poll.
{
    require Punk::Observe::Store;
    require Punk::Observe::WAL;

    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);

    my @all;
    for my $i (0 .. 4) {
        my $t = Punk::Observe::Store::nadd($NS, $i * 1_000_000_000);
        # The db check fails for the last two polls.
        my $ok = $i < 3 ? 'true' : 'false';
        my ($recs) = $H->can('points')->('shop', 200,
            qq({"status":"ok","checks":{"db":{"ok":$ok,"ms":12.5}}}), $t);
        push @all, @$recs;
    }
    Punk::Observe::WAL::append($store->wal_path, \@all, 0, 0);
    ok($store->seal, 'health points reach the store');

    my %W = (from => $NS,
             to => Punk::Observe::Store::nadd($NS, 60_000_000_000));

    my $r = $store->query('metric punk.health.ok', %W);
    ok($r->{ok}, 'punk.health.ok is queryable in OQL');
    is(scalar @{ $r->{rows} || [] }, 10,
       '  a target-level point and a per-check point per poll');

    # THE PER-CHECK SERIES ON ITS OWN, which is what the target-level rows
    # sharing the metric name costs and what the `check` label buys back.
    my $only = $store->query('metric punk.health.ok | where check != ""', %W);
    ok($only->{ok}, 'the per-check series is selectable');
    is(scalar @{ $only->{rows} || [] }, 5, '  five polls of one check');

    # The alert this feature exists for, expressible in the language today
    # with no new rule type: the check has been failing.
    my $g = $store->query('metric punk.health.ok | where check != "" | by check | min', %W);
    ok($g->{ok}, 'and aggregatable by check');
    is($g->{groups}[0]{key}, 'db', '  grouped by the check label');
    is($g->{groups}[0]{value}, 0, '  whose minimum is a failure');
}

# --- the agent is injectable, which is how this is tested at all -----------
#
# `poll` takes a `ua`, so a fake with a `get` returning a future stands in for
# the network. That is also the seam the cron task uses for the real reason:
# awaiting a Fetch::Future runs the loop the agent was built on, and the
# worker's loop is the only correct one to run inside a worker.
{
    package T::Res;
    sub new { my ($c,%a)=@_; bless {%a}, $c }
    sub status  { $_[0]{status} }
    sub content { $_[0]{content} }

    package T::Fut;
    sub new { my ($c,$v)=@_; bless { v => $v }, $c }
    sub get { $_[0]{v} }

    package T::UA;
    sub new { my ($c,%a)=@_; bless {%a}, $c }
    sub get {
        my ($self, $url) = @_;
        $self->{seen} = $url;
        die "boom\n" if $self->{die};
        return T::Fut->new(T::Res->new(status => $self->{status},
                                       content => $self->{content}));
    }
}

{
    my $ua = T::UA->new(status => 200,
                        content => '{"status":"ok","checks":{"db":{"ok":true,"ms":2}}}');
    my $recs = $H->can('poll')->(
        { name => 'shop', url => 'https://shop.example.com/readyz',
          timeout_ms => 500 }, ua => $ua, now => $NS);
    is($ua->{seen}, 'https://shop.example.com/readyz', 'the agent is given the URL');
    my ($tgt) = grep { $_->{body} eq 'punk.health.ok'
                       && !exists $_->{attrs}{check} } @$recs;
    is($tgt->{attrs}{state}, 'ready', '  and its answer becomes points');
    my ($rtt) = grep { $_->{body} eq 'punk.health.ms'
                       && !exists $_->{attrs}{check} } @$recs;
    ok($rtt && $rtt->{value} >= 0,
       '  and the poll timed its own round trip onto the target series');
    my ($chk) = grep { ($_->{attrs}{check} || '') eq 'db'
                       && $_->{body} eq 'punk.health.ok' } @$recs;
    is($chk->{value}, 1, '  including the check');

    # AN EXCEPTION IS UNREACHABLE. Whatever went wrong, no answer arrived -
    # and a poller that let it propagate would take the whole pass down with
    # one bad target.
    my $bad = T::UA->new(die => 1);
    my $r2 = $H->can('poll')->(
        { name => 'shop', url => 'https://shop.example.com/readyz' },
        ua => $bad, now => $NS);
    is(scalar @$r2, 1, 'an agent that dies records only that the target is down');
    is($r2->[0]{attrs}{state}, 'unreachable', '  as unreachable');
    is($r2->[0]{value}, 0, '  with value 0');
}

# --- the pass runs under the leader lease -----------------------------------
#
# FOUR WORKERS MUST NOT ALL POLL THE SAME TARGET, or the check history is four
# times the traffic and the `ms` series is meaningless. Losing the race is the
# normal case on a pool, not an error.
{
    package T::Q;
    sub new { my ($c,%a)=@_; bless { %a, renewed => 0 }, $c }
    sub lock { my $s=shift; $s->{tried}++; return $s->{grant} }
    sub renew_lock { $_[0]{renewed}++; return 1 }
}

{
    require File::Temp;
    require Punk::Observe::Backend;
    require Punk::Observe::Config;
    require Punk::Observe::Store;
    require File::Path;

    my $d = File::Temp::tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$d/c.db");
    $db->migrate;
    Punk::Observe::Config::save_health_target($db, 'default',
        { name => 'shop', url => 'https://shop.example.com/readyz' }, undef);
    File::Path::make_path("$d/store");
    my $store = Punk::Observe::Store->new(dir => "$d/store");

    my $ua = T::UA->new(status => 200,
                        content => '{"status":"ok","checks":{"db":{"ok":true,"ms":3}}}');
    my $task = Punk::Observe::Health::cron_task(
        db => $db, store => $store, owner => 'w1', ua => $ua);

    # The worker that wins the lease does the pass.
    my $won = T::Q->new(grant => 1);
    my $n = $task->($won);
    cmp_ok($n, '>', 0, 'the leader polls and stores');
    is($won->{renewed}, 1, '  and renews the lease afterwards');

    # The ones that lose it do not, and that is not an error.
    my $lost = T::Q->new(grant => 0);
    is($task->($lost), 0, 'a worker without the lease does not poll');
    is($lost->{renewed}, 0, '  and does not touch the lease');

    # What it stored is queryable, which is the whole argument for storing.
    my $r = $store->query('metric punk.health.ok',
                          from => '0', to => Punk::Observe::now_ns());
    ok($r->{ok} && @{ $r->{rows} || [] }, 'the pass left a queryable history');
}

# --- a disabled target is not polled ---------------------------------------
{
    require File::Temp;
    my $d = File::Temp::tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$d/c.db");
    $db->migrate;
    Punk::Observe::Config::save_health_target($db, 'default',
        { name => 'off', url => 'https://off.example.com/readyz', enabled => 0 },
        undef);
    my $ua = T::UA->new(status => 200, content => '{"status":"ok"}');
    my $recs = Punk::Observe::Health::run(db => $db, ua => $ua, now => $NS);
    is(scalar @$recs, 0, 'a disabled target is not polled');
    ok(!$ua->{seen}, '  the agent is never asked for it');
}

# --- the page renders before any poll has happened --------------------------
#
# A fresh install with targets configured and no data yet is the FIRST thing
# anybody sees. A screen that needs data to render is a screen that is broken
# exactly then.
{
    require File::Temp; require File::Path;
    require Punk::Observe::Backend; require Punk::Observe::Config;
    require Punk::Observe::Store;   require Punk::Observe::WAL;

    my $d = File::Temp::tempdir(CLEANUP => 1);
    File::Path::make_path("$d/store");
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$d/c.db");
    $db->migrate;
    Punk::Observe::Config::save_health_target($db, 'default',
        { name => $_, url => "https://$_.example.com/readyz" }, undef)
        for qw(cards shop);
    my $store = Punk::Observe::Store->new(dir => "$d/store");
    my $now = Punk::Observe::now_ns();

    my $v = Punk::Observe::Health::page_vars(db => $db, store => $store,
                                             now => $now);
    is(scalar @$v, 2, 'both targets are listed with no data at all');
    is($v->[0]{state}, 'never polled',
       '  and say so, rather than reading as healthy');
    is($v->[0]{ok}, 0, '  never polled is not ok');
    is(scalar @{ $v->[0]{checks} }, 0, '  with no checks yet');

    # ...and with data, the state and the duration are both real.
    my @recs;
    for my $i (0 .. 9) {
        my $t = Punk::Observe::Store::nsub($now, (10 - $i) * 60_000_000_000);
        my ($a) = $H->can('points')->('shop', 200,
            '{"status":"ok","checks":{"db":{"ok":true,"ms":2}}}', $t);
        my $bad = $i >= 7 ? 'false' : 'true';
        my ($b) = $H->can('points')->('cards', 200,
            qq({"status":"ok","checks":{"db":{"ok":$bad,"ms":9},)
          . qq("cache":{"ok":true,"ms":1}}}), $t);
        push @recs, @$a, @$b;
    }
    Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0);
    $store->seal;

    $v = Punk::Observe::Health::page_vars(db => $db, store => $store,
                                          now => $now);
    my %by = map { $_->{name} => $_ } @$v;

    is($by{shop}{state}, 'ready', 'a healthy target reads ready');
    my ($shop_db) = @{ $by{shop}{checks} };
    is($shop_db->{state}, 'ok', '  and its check is ok');

    my %ck = map { $_->{name} => $_ } @{ $by{cards}{checks} };
    is($ck{db}{state}, 'failing', 'a failing check reads failing');
    is($ck{cache}{state}, 'ok', '  while its neighbour does not');

    # HOW LONG, which is the question during an incident and the one a live
    # poll cannot answer at all. Three polls failing, ten passing.
    cmp_ok($ck{db}{held}, '<', $ck{cache}{held},
           'the failing check has held for less time than the passing one')
        or diag('the run that reaches the present is what counts, not every '
              . 'earlier spell of the same value');
    cmp_ok($ck{db}{held} / 1e9, '>=', 120,
           '  roughly the three polls it has been failing for');
    cmp_ok($ck{db}{held} / 1e9, '<', 600, '  and not the whole window');
}

# --- the lease owner is an integer -----------------------------------------
#
# Punk::Queue's `owner` is an IV. A string numifies to zero WITH A WARNING,
# and then every worker in the pool holds the lease under owner 0 - so
# `renew_lock` renews somebody else's, which is the one thing an owned lease
# exists to prevent. The warning is the visible half; the shared owner is the
# half that matters.
{
    package T::Q2;
    sub new { bless { owners => [] }, $_[0] }
    sub lock {
        my ($s, $name, $ttl, %o) = @_;
        push @{ $s->{owners} }, $o{owner};
        return 1;
    }
    sub renew_lock { my ($s,$n,$owner)=@_; push @{$s->{renewed}}, $owner; 1 }
}

{
    require File::Temp; require File::Path;
    require Punk::Observe::Backend; require Punk::Observe::Store;

    my $d = File::Temp::tempdir(CLEANUP => 1);
    File::Path::make_path("$d/store");
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$d/c.db");
    $db->migrate;
    my $store = Punk::Observe::Store->new(dir => "$d/store");

    for my $given (undef, 'worker-123', 42) {
        my $q = T::Q2->new;
        my $task = Punk::Observe::Health::cron_task(
            db => $db, store => $store,
            (defined $given ? (owner => $given) : ()));
        $task->($q);
        my $used = $q->{owners}[0];
        like($used, qr/\A[0-9]+\z/,
             'the lease owner is an integer'
             . (defined $given ? " (given '$given')" : ' (defaulted)'))
            or diag('a string owner numifies to 0 and every worker shares it');
        is($q->{renewed}[0], $used, '  and the renewal uses the same one');
    }

    # A named integer is kept; a name that is not one is replaced rather than
    # silently numified.
    my $q = T::Q2->new;
    Punk::Observe::Health::cron_task(db => $db, store => $store, owner => 42)
        ->($q);
    is($q->{owners}[0], 42, 'an integer owner is used as given');
}

# --- a duration the window cannot see past is a LOWER BOUND -----------------
#
# The walk back cannot see outside the window it queried. A check healthy for
# three hours, read over a one-hour window, reaches the oldest bucket with the
# value still agreeing - and reporting "59.8 minutes" then says it CHANGED an
# hour ago, which is false and is the kind of false that looks like an answer.
#
# Found by staring at a demo that had been up for three hours and reading
# "3587s" against every check.
{
    require File::Temp; require File::Path;
    require Punk::Observe::Backend; require Punk::Observe::Config;
    require Punk::Observe::Store;   require Punk::Observe::WAL;

    my $d = File::Temp::tempdir(CLEANUP => 1);
    File::Path::make_path("$d/store");
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$d/c.db");
    $db->migrate;
    my $store = Punk::Observe::Store->new(dir => "$d/store");
    my $now = Punk::Observe::now_ns();

    my $seed = sub {
        my ($name, $polls, $fail_from) = @_;
        Punk::Observe::Config::save_health_target($db, 'default',
            { name => $name, url => "https://$name.example.com/readyz",
              every_ns => 60_000_000_000 }, undef);
        my @r;
        for my $i (0 .. $polls - 1) {
            my $t = Punk::Observe::Store::nsub($now,
                        ($polls - $i) * 60_000_000_000);
            my $ok = (defined $fail_from && $i >= $fail_from) ? 'false' : 'true';
            my ($p) = $H->can('points')->($name, 200,
                qq({"status":"ok","checks":{"db":{"ok":$ok,"ms":1}}}), $t);
            push @r, @$p;
        }
        Punk::Observe::WAL::append($store->wal_path, \@r, 0, 0);
        $store->seal;
    };

    # Two hours of health, read over a one-hour window.
    $seed->('steady', 120);
    # Ten polls, the last three failing: a change the window CAN see.
    $seed->('recent', 10, 7);

    my $v = Punk::Observe::Health::page_vars(db => $db, store => $store,
                                             now => $now);
    my %by = map { $_->{name} => $_ } @$v;

    my ($sc) = @{ $by{steady}{checks} };
    is($sc->{held_min}, 1,
       'a run reaching the edge of the window is flagged as a lower bound')
        or diag('without this the page says the state changed when the window '
              . 'began, which is the one thing it does not know');

    my ($rc) = @{ $by{recent}{checks} };
    is($rc->{held_min}, 0, 'a change inside the window is not a lower bound');
    cmp_ok($rc->{held} / 1e9, '<', 600, '  and its duration is the real one');
}

# --- the uptime bands: was it up, and when was it not -----------------------
#
# The chart on this page used to be a bar per target of its most recent poll
# latency - a number the table already prints, and one that says nothing at
# all about whether the service has been up. A target down for forty minutes
# drew the same bar as a healthy one. These pin the replacement: bands
# derived from the polls themselves, since health keeps no transitions table
# and inventing one would be a second place for the same truth to live.

{
    require File::Path;
    require Punk::Observe::Store;
    require Punk::Observe::WAL;

    my $d = tempdir(CLEANUP => 1);
    File::Path::make_path("$d/store");
    my $store = Punk::Observe::Store->new(dir => "$d/store");

    # Ten minutes of polls a minute apart. `cards` fails for minutes 3 and 4
    # and recovers; `shop` never fails. One check under cards stays up
    # throughout, so a check and its target are separate bands.
    my $T = '1774224000000000000';
    my $at = sub { Punk::Observe::Store::nadd($T, $_[0] * 60_000_000_000) };
    my @recs;
    for my $m (0 .. 9) {
        my $cards_ok = ($m == 3 || $m == 4) ? 0 : 1;
        push @recs,
            { t => $at->($m), kind => 1, body => 'punk.health.ok',
              value => $cards_ok, severity => 0, span_kind => 0, status => 0,
              duration => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
              parent_id => 0, attrs => { target => 'cards' } },
            { t => $at->($m), kind => 1, body => 'punk.health.ok',
              value => 1, severity => 0, span_kind => 0, status => 0,
              duration => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
              parent_id => 0, attrs => { target => 'shop' } },
            { t => $at->($m), kind => 1, body => 'punk.health.ok',
              value => 1, severity => 0, span_kind => 0, status => 0,
              duration => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
              parent_id => 0,
              attrs => { target => 'cards', check => 'ledger' } };
    }
    ok(Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0)->{ok},
       'the uptime fixture reaches the log');
    $store->seal;

    my $ev = Punk::Observe::Health::uptime_events(
        store => $store, from => $T, to => $at->(10));
    ok(@$ev, 'polls become bands');

    my %by;
    push @{ $by{ $_->{series} } }, $_ for @$ev;

    is_deeply([ map { $_->{to} } @{ $by{cards} || [] } ],
              [ 'up', 'down', 'up' ],
              'a target that failed and recovered is three bands');
    is_deeply([ map { $_->{to} } @{ $by{shop} || [] } ], [ 'up' ],
              'one that never failed is a single band, not one per poll');

    # A CHECK IS ITS OWN BAND, and belongs to its target by name - rendered
    # as one series they would read as a single service failing.
    my ($ck) = grep { /ledger/ } keys %by;
    ok($ck, 'a check gets a band of its own');
    like($ck, qr/cards/, '  named for the target it belongs to');
    is_deeply([ map { $_->{to} } @{ $by{$ck} } ], [ 'up' ],
              '  and its own state, not its target\'s');

    # The band starts WHERE THE STATE CHANGED, which is what makes the chart
    # readable as an incident rather than as a row of polls.
    my ($down) = grep { $_->{to} eq 'down' } @{ $by{cards} };
    cmp_ok($down->{at}, 'ge', $at->(3), 'the down band starts at the failure');
    cmp_ok($down->{at}, 'lt', $at->(5), '  and not after the recovery');

    # ANY failure in a bucket makes the bucket down. Averaging would paint a
    # bucket with one failure in five as mostly-up, which is the reading that
    # loses the incident entirely.
    my $wide = Punk::Observe::Health::uptime_events(
        store => $store, from => $T, to => $at->(600));
    my %w; push @{ $w{ $_->{series} } }, $_ for @$wide;
    ok(scalar(grep { $_->{to} eq 'down' } @{ $w{cards} || [] }),
       'over a window whose buckets are wider than the outage, it is still '
     . 'drawn as down');

    # No store, or no window, is an empty list rather than a die: the page
    # renders without the chart.
    is_deeply(Punk::Observe::Health::uptime_events(store => $store), [],
              'no window gives no bands rather than dying');
    is_deeply(Punk::Observe::Health::uptime_events(from => $T, to => $at->(1)),
              [], 'and no store likewise');
}

done_testing();

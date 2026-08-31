#!perl
# The warmer: the settled chunks, computed where nobody is waiting.
#
# `query` fills the cache as a side effect of answering, so the first person to
# open a dashboard after a restart pays for the whole window. This is the same
# walk with the answer thrown away - and the assertion that matters is that the
# request which follows finds the entries already there, with the store never
# asked to scan.
#
# The bounds are the other half. A pass over a busy store is unbounded work,
# and a job that can run for ever can hold a queue worker for ever, so a pass
# stops on a count or on a clock - and stops without leaving the cache colder
# than it found it.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);

BEGIN {
    eval { require Punk::Cache; 1 }
        or plan skip_all => 'Punk::Cache not installed';
    eval { require DBD::SQLite; 1 }
        or plan skip_all => 'DBD::SQLite not installed';
}
use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;
use Punk::Observe::Cache;
use Punk::Observe::Config ();
use Punk::Observe::Backend ();
use Punk::Observe::Warm;

my $W = 'Punk::Observe::Warm';
my $C = 'Punk::Observe::Cache';

# --- the fixture ------------------------------------------------------------

my $dir  = tempdir(CLEANUP => 1);
my $B    = 1800 * 1_000_000_000;                  # 30m buckets
my $BASE = '1774224000000000000';
my $to   = Punk::Observe::Store::nadd($BASE, 12 * $B);   # six hours
my $NOW  = Punk::Observe::Store::nadd($to, 3600 * 1_000_000_000);
my $Q    = 'spans | bucket(30m) count by service';

{
    my $seed = Punk::Observe::Store->new(dir => $dir);
    my @recs;
    for my $m (0 .. 359) {
        push @recs, {
            kind => 3, t => Punk::Observe::Store::nadd($BASE, $m * 60_000_000_000),
            body => 'GET /', duration => 1_000_000, severity => 0,
            span_kind => 2, status => 0, trace_hi => 1, trace_lo => $m,
            span_id => $m, parent_id => 0,
            attrs => { 'service.name' => ($m % 2 ? 'cards' : 'shop') } };
    }
    ok(Punk::Observe::WAL::append($seed->wal_path, \@recs, 0, 0)->{ok},
       'the fixture reaches the log');
    ok($seed->seal, '  and seals');
}

sub fresh_cache {
    return Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                            max_bytes => '64M');
}

sub flat {
    my ($r) = @_;
    my %h;
    for my $s (@{ $r->{series} || [] }) {
        $h{ ($s->{key} // '') . '|' . $_->[0] } = $_->[1]
            for @{ $s->{points} || [] };
    }
    return \%h;
}

# The depth is measured back from `now`, so it has to reach the fixture.
my $DEPTH = 12 * 3600 * 1_000_000_000;

# --- a warmed window is a window nobody has to scan --------------------------
#
# The headline. A store that refuses to answer proves it: with every settled
# chunk already in the cache, the only thing left to compute is the live tail.

{
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);

    my $r = $C->can('warm')->($store, $Q, from => $BASE, to => $NOW,
                              now => $NOW, cache => $cache, ttl => 86_400);
    ok($r->{computed} > 1, 'a first pass computes the settled chunks');
    is($r->{hits}, 0, '  none of which were there already');
    is($r->{stopped}, '', '  and it finishes');

    my $want = flat($store->cached_query($Q, from => $BASE, to => $to,
                                         now => $NOW));

    my $blocked = Blocked::Store->new($store, $cache);
    is_deeply(flat($C->can('query')->($blocked, $Q, from => $BASE, to => $to,
                                      cache => $cache, now => $NOW)),
              $want,
              'THE REQUEST AFTER A WARM PASS SCANS NOTHING SETTLED');
    ok($blocked->{calls} <= 1,
       '  one call for the live tail and no more')
        or diag "store was asked $blocked->{calls} times";
}

# --- a second pass is nearly free -------------------------------------------

{
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);
    my %arg = (from => $BASE, to => $NOW, now => $NOW,
               cache => $cache, ttl => 86_400);

    my $first  = $C->can('warm')->($store, $Q, %arg);
    my $second = $C->can('warm')->($store, $Q, %arg);
    is($second->{computed}, 0, 'a second pass computes nothing');
    is($second->{hits}, $first->{computed} + $first->{hits},
       '  every chunk it walked was already warm');
}

# --- the newest hours are recomputed, the older ones left -------------------
#
# Telemetry arrives late, so a chunk that has only just settled can still gain
# records. Everything older is filled only where it is missing.

{
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);
    my %arg = (from => $BASE, to => $NOW, now => $NOW,
               cache => $cache, ttl => 86_400);

    my $all = $C->can('warm')->($store, $Q, %arg);
    my $r   = $C->can('warm')->($store, $Q, %arg,
                                refresh_ns => 2 * 3600 * 1_000_000_000);
    is($r->{computed}, 2, 'the two newest settled chunks are recomputed');
    is($r->{hits}, $all->{computed} - 2, '  and the rest are left alone');
}

# --- the bounds -------------------------------------------------------------

{
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);

    my $r = $C->can('warm')->($store, $Q, from => $BASE, to => $NOW,
                              now => $NOW, cache => $cache, budget => 2);
    is($r->{computed}, 2, 'a budget stops the pass at what it was given');
    is($r->{stopped}, 'budget', '  and says which bound it hit');

    # NEWEST FIRST. A pass that runs out should have spent what it had on the
    # hours somebody is about to ask for.
    my $width = $C->can('chunk_ns')->($B);
    # The newest SETTLED chunk starts one width below the settled edge, which
    # is `now` less the lag rounded down.
    my $last  = Punk::Observe::Store::nsub(
                    Punk::Observe::Store::nfloor(
                        Punk::Observe::Store::nsub($NOW, 120 * 1_000_000_000),
                        $width),
                    $width);
    ok(defined $cache->get(_key($last, $width, $Q)),
       '  spending it on the newest chunk');
    ok(!defined $cache->get(_key(Punk::Observe::Store::nfloor($BASE, $width),
                                 $width, $Q)),
       '  and not on the oldest');
}

{
    # A deadline already past stops before the first scan rather than after it.
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);
    my $r = $C->can('warm')->($store, $Q, from => $BASE, to => $NOW,
                              now => $NOW, cache => $cache,
                              deadline => 0.000_000_1);
    is($r->{computed}, 0, 'a deadline already spent computes nothing');
    is($r->{stopped}, 'deadline', '  and says so');
}

# --- stopping never leaves a chunk colder than it was found -----------------
#
# The trap: delete the entry to force a refresh, then run out of budget before
# replacing it. A warmer that kept stopping on the same chunk would keep
# emptying it, and the request path would pay for it every time.

{
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);
    my %arg = (from => $BASE, to => $NOW, now => $NOW, cache => $cache);

    $C->can('warm')->($store, $Q, %arg, ttl => 86_400);
    my $width = $C->can('chunk_ns')->($B);
    # The newest SETTLED chunk starts one width below the settled edge, which
    # is `now` less the lag rounded down.
    my $last  = Punk::Observe::Store::nsub(
                    Punk::Observe::Store::nfloor(
                        Punk::Observe::Store::nsub($NOW, 120 * 1_000_000_000),
                        $width),
                    $width);
    ok(defined $cache->get(_key($last, $width, $Q)), 'the newest chunk is warm');

    # Everything forced, and no time to do any of it.
    my $r = $C->can('warm')->($store, $Q, %arg,
                              refresh_ns => '999999999999999999',
                              deadline   => 0.000_000_1);
    is($r->{stopped}, 'deadline', 'a forced pass that runs out of time stops');
    ok(defined $cache->get(_key($last, $width, $Q)),
       '  with the entry it was about to replace still there');
}

# --- what cannot be warmed says so ------------------------------------------

{
    my $cache = fresh_cache();
    my $store = Punk::Observe::Store->new(dir => $dir, cache => $cache);
    my %arg = (from => $BASE, to => $NOW, now => $NOW, cache => $cache);

    is($C->can('warm')->($store, 'spans | count', %arg)->{stopped},
       'unbucketed', 'a query with no bucket cannot be warmed');
    is($C->can('warm')->($store, "$Q | limit 3", %arg)->{stopped},
       'unbucketed', 'nor can one that ranks rows against each other');
    is($C->can('warm')->($store, $Q, from => $BASE, to => $NOW, now => $NOW)
         ->{stopped},
       'no cache', 'and with no cache there is nowhere to put anything');
    is($C->can('warm')->($store, $Q, %arg, now => $BASE)->{stopped},
       'nothing settled', 'a window with nothing settled in it warms nothing');
}

# --- the pass over a configuration --------------------------------------------

{
    my $cdir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$cdir/c.db");
    $db->migrate;

    Punk::Observe::Config::save_dashboard($db, 'default',
        { slug => 'main', title => 'Main' });
    Punk::Observe::Config::save_panel($db, 'default', 'main',
        { title => 'by service', query => $Q });
    # A duplicate of the same query, and one that cannot be split.
    Punk::Observe::Config::save_panel($db, 'default', 'main',
        { title => 'again', query => $Q });
    Punk::Observe::Config::save_panel($db, 'default', 'main',
        { title => 'slowest', query => 'trace | slowest 5' });

    is_deeply($W->can('tenants')->($db), ['default'],
              'the tenants are the ones with dashboards');
    is_deeply($W->can('queries')->($db, 'default'), [ $Q, 'trace | slowest 5' ],
              '  and a query used by two panels is listed once');

    my $cache = fresh_cache();
    my %stores = (default => Punk::Observe::Store->new(dir => $dir,
                                                       cache => $cache));
    my $out = $W->can('run')->(db => $db, store => sub { $stores{ $_[0] } },
                               now => $NOW, depth_ns => $DEPTH, ttl => 86_400);

    is($out->{tenants}, 1, 'the pass covered the tenant');
    is($out->{queries}, 1, '  warming the one query that can be split');
    is($out->{skipped}, 1, '  and skipping the one that cannot');
    ok($out->{computed} > 1, '  computing its settled chunks');
    is($out->{unstorable}, 0, '  all of which the cache accepted');
    is($out->{failed}, 0, '  and none of which failed');

    my $again = $W->can('run')->(db => $db, store => sub { $stores{ $_[0] } },
                                 now => $NOW, depth_ns => $DEPTH,
                                 ttl => 86_400, refresh_ns => 0);
    is($again->{computed}, 0, 'a second pass over the same configuration '
                            . 'computes nothing');

    # A budget is the PASS's, not each query's - or it would be multiplied by
    # the number of panels, which is the opposite of a bound.
    my $bounded = $W->can('run')->(
        db => $db, store => sub { $stores{ $_[0] } }, now => $NOW,
        depth_ns => $DEPTH, ttl => 86_400,
        refresh_ns => '999999999999999999', budget => 1);
    is($bounded->{computed}, 1, 'a budget bounds the pass');
    is($bounded->{stopped}, 'budget', '  and names itself');

    # A store nobody configured a cache for has nothing to warm into, and that
    # is a quiet no-op rather than a failure.
    my %bare = (default => Punk::Observe::Store->new(dir => $dir));
    my $none = $W->can('run')->(db => $db, store => sub { $bare{ $_[0] } },
                                now => $NOW, depth_ns => $DEPTH);
    is($none->{computed}, 0, 'a store with no cache warms nothing');
}

# --- an empty configuration is a no-op --------------------------------------

{
    my $cdir = tempdir(CLEANUP => 1);
    my $db = Punk::Observe::Backend->new(dsn => "dbi:SQLite:dbname=$cdir/c.db");
    $db->migrate;
    my $out = $W->can('run')->(db => $db, store => sub { undef }, now => $NOW);
    is($out->{tenants}, 0, 'a configuration with no dashboards warms nothing');
    is($out->{computed}, 0, '  and computes nothing');
}

# --- the job body -----------------------------------------------------------

{
    require Punk::Plugin::Observe;
    my $cdir = tempdir(CLEANUP => 1);
    my $class = 'Warm::Job::Test::App';

    my $st = Punk::Plugin::Observe->register($class, {
        guard  => sub { 1 },
        store  => $dir,
        db     => { dsn => "dbi:SQLite:dbname=$cdir/c.db" },
        alerts => sub { {} },       # our own evaluator, so no queue is needed
    });
    $st->{db}->migrate;
    Punk::Observe::Config::save_dashboard($st->{db}, 'default',
        { slug => 'main', title => 'Main' });
    Punk::Observe::Config::save_panel($st->{db}, 'default', 'main',
        { title => 'by service', query => $Q });
    $st->{warm_opts} = { depth_ns => $DEPTH, ttl => 86_400, now => $NOW };

    my $q = Fake::Queue->new;
    my $out = Punk::Observe::Warm::warm_job(Fake::Job->new($q), $class);
    is(ref $out, 'HASH', 'warm_job returns what the pass did');
    ok($out->{computed} > 1, '  having computed the settled chunks');
    is($q->{calls}[0][1], 'observe.warm',
       '  under its own named lease, not the leader one');
    ok($q->did('unlock'), '  which it releases');

    my $refused = Punk::Observe::Warm::warm_job(
        Fake::Job->new(Fake::Queue->new(grant => 0)), $class);
    is($refused->{skipped}, 'lock',
       'a worker that loses the lease says so rather than running twice');

    eval { Punk::Observe::Warm::warm_job(Fake::Job->new($q), 'No::Such') };
    like($@, qr/no Observe plugin state/,
         'an unknown application class croaks with what to check');
}

done_testing();

sub _key {
    my ($start, $width, $q) = @_;
    return join("\0", 'po.chunk2', 'default', $start, $width, $q);
}

# A store that answers once and then refuses, so a result that came from the
# cache cannot be confused with one that came from a scan nobody noticed.
{
    package Blocked::Store;
    sub new {
        my ($c, $real, $cache) = @_;
        return bless { real => $real, cache => $cache, calls => 0 }, $c;
    }
    sub query {
        my $self = shift;
        $self->{calls}++;
        die "Blocked::Store: the store was asked to scan\n"
            if $self->{calls} > 1;
        return $self->{real}->query(@_);
    }
    sub AUTOLOAD {
        my $self = shift;
        our $AUTOLOAD;
        (my $m = $AUTOLOAD) =~ s/.*:://;
        return if $m eq 'DESTROY';
        return $self->{real}->$m(@_);
    }
}

{
    package Fake::Job;
    sub new { my ($c, $q) = @_; bless { q => $q }, $c }
    sub queue_object { $_[0]{q} }
    sub retries { 0 }
}

{
    package Fake::Queue;
    sub new {
        my ($c, %o) = @_;
        return bless { grant => (exists $o{grant} ? $o{grant} : 1),
                       calls => [] }, $c;
    }
    sub lock {
        my ($s, $name, $lease, %o) = @_;
        push @{ $s->{calls} }, [ 'lock', $name, $lease, $o{owner} ];
        return $s->{grant};
    }
    sub renew_lock { my ($s, @a) = @_; push @{ $s->{calls} }, ['renew_lock', @a]; 1 }
    sub unlock     { my ($s, @a) = @_; push @{ $s->{calls} }, ['unlock', @a]; 1 }
    sub did { my ($s, $m) = @_; scalar grep { $_->[0] eq $m } @{ $s->{calls} } }
}

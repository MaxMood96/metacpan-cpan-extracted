#!perl
# The ingest rate limit, end to end through the arena the mount creates.
#
# THE PROPERTY THAT MATTERS IS NOT THAT A NUMBER GOES UP.
#
# A partial success means "I did not keep these". If the limit decided AFTER
# the append and reported the overflow anyway, it would be saying that about
# records already on the disk - and an exporter doing the correct thing with
# that answer, resending what it was told was rejected, would duplicate every
# one of them. So the assertion below is not that `rejected` is 3: it is that
# the store holds twelve records and not fifteen.
#
# The second property is that the counters are SHARED. A counter mapped after
# the fork is private per worker, and the symptom is not a crash - it is a
# rate limit N times what was configured and a status page showing whichever
# shard of the traffic answered the request.
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
use Punk::Observe::Store;
use Punk::Observe::Ingest;
use Punk::Observe::Segment;
use Punk::Plugin::Observe;

my $A = 'Punk::Observe::Segment';

# --- the arena the mount creates --------------------------------------------

{
    my $st = { limits => { series => 25 } };
    my $a = Punk::Plugin::Observe::_arena($st);
    ok($a, 'the mount maps a counter arena at registration');
    ok($a->{handle}, '  and keeps the handle where the read path can reach it');

    my $s = $A->can('shm_stats')->($a->{handle});
    is($s->{series_cap}, 25, '  carrying the configured cardinality cap');
    is($s->{records}, 0, '  and starting at nothing');

  SKIP: {
        skip 'no shared memory on this platform', 1 unless $s->{shared};
        is($s->{shared}, 1, '  mapped SHARED, so a fork sees one counter');
    }
    $A->can('shm_free')->($a->{handle});
}

# --- one OTLP/JSON batch, as the exporter sends it --------------------------

sub logs_json {
    my ($n, $from) = @_;
    $from ||= 1;
    return File::Raw::JSON::file_json_encode({
        resourceLogs => [ {
            resource => { attributes => [
                { key => 'service.name', value => { stringValue => 'api' } } ] },
            scopeLogs => [ { logRecords => [ map {
                { timeUnixNano  => '1774224000000000000',
                  severityNumber => 9,
                  body => { stringValue => "line $_" } }
            } $from .. $from + $n - 1 ] } ],
        } ],
    });
}

# --- the limit truncates the batch BEFORE it reaches the log ----------------

{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $st = { limits => { series => 0, rate_records => 12, rate_bytes => 0 } };
    my $a = Punk::Plugin::Observe::_arena($st);

    my @seen;
    for my $round (1 .. 3) {
        my $doc = File::Raw::JSON::file_json_decode(logs_json(5, $round * 100));
        my $r = Punk::Observe::Ingest::decode_append(
            $store->wal_path, $doc, 'logs', 'json', 1, '200000000', 0,
            $a->{handle}, 12, 0);
        push @seen, { n => $r->{n} + 0, rejected => ($r->{rejected} || 0) + 0 };
    }

    is_deeply(\@seen,
              [ { n => 5, rejected => 0 },
                { n => 5, rejected => 0 },
                { n => 2, rejected => 3 } ],
              'the third batch is truncated to what the window had room for');

    # THE ASSERTION THE WHOLE FILE IS FOR.
    my $s = $store->stats;
    is($s->{records}, 12,
       'the rejected records were never written, so an exporter that resends '
     . 'them cannot duplicate them');

    my $c = $A->can('shm_stats')->($a->{handle});
    is($c->{records}, 12, 'the arena counted what was accepted');
    is($c->{rate_rejected}, 3, '  and what the window refused');
    cmp_ok($c->{bytes}, '>', 0, '  and the bytes behind it');
    $A->can('shm_free')->($a->{handle});
}

# --- unconfigured, nothing is refused ---------------------------------------

{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $st = { limits => { series => 0, rate_records => 0, rate_bytes => 0 } };
    my $a = Punk::Plugin::Observe::_arena($st);

    my $total = 0;
    for my $round (1 .. 4) {
        my $doc = File::Raw::JSON::file_json_decode(logs_json(5, $round * 100));
        my $r = Punk::Observe::Ingest::decode_append(
            $store->wal_path, $doc, 'logs', 'json', 1, '200000000', 0,
            $a->{handle}, 0, 0);
        $total += $r->{n};
        is(($r->{rejected} || 0), 0, "round $round is not throttled");
    }
    is($total, 20, 'an unconfigured rate limit refuses nothing');

    # The counters still move, because "what arrived" is worth knowing whether
    # or not anything is capped.
    my $c = $A->can('shm_stats')->($a->{handle});
    is($c->{records}, 20, '  and the arena counts it anyway');
    $A->can('shm_free')->($a->{handle});
}

# --- with no arena at all, decode_append is unchanged -----------------------
# The limits are an argument rather than a requirement, so every existing
# caller - and every test that predates them - still works.

{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $doc = File::Raw::JSON::file_json_decode(logs_json(7));
    my $r = Punk::Observe::Ingest::decode_append(
        $store->wal_path, $doc, 'logs', 'json', 1, '200000000', 0);
    is($r->{n}, 7, 'no arena, no truncation');
    ok(!$r->{rejected}, '  and nothing reported as rejected');
    is($store->stats->{records}, 7, '  all seven stored');
}



# --- `max_body` reaches the receiver ----------------------------------------
#
# `_ingest` returned three keys and dropped the rest, and `_register_ingest`
# then read `max_body` off that hashref - so it was always undef and the
# receiver fell back to its own 16MB. Somebody raising the limit for a large
# batch exporter got no error and no effect, which is the failure this whole
# file is about wearing a different hat.
{
    my $st = eval {
        Punk::Plugin::Observe::_ingest({ ingest => { max_body => 4096 } })
    };
    is($st->{max_body}, 4096, 'max_body survives _ingest');
    ok(!exists $st->{scope}, '  and the key nobody read is gone');

    # THE RECEIVER HONOURS IT. A body over the limit is a 413, not a 200 that
    # stored a truncated batch.
    my $recv = Punk::Observe::Ingest->new(
        max_body => 128,
        auth     => sub { 'default' },
        on_batch => sub { 1 },
    );
    my $app = $recv->to_app;

    my $post = sub {
        my ($bytes) = @_;
        open my $in, '<', \$bytes or die $!;
        my $res = $app->({
            REQUEST_METHOD => 'POST', PATH_INFO => '/v1/logs',
            CONTENT_TYPE   => 'application/x-protobuf',
            CONTENT_LENGTH => length $bytes,
            'psgi.input'   => $in,
        });
        return $res->[0];
    };

    is($post->('x' x 4096), 413,
       'a body over max_body is refused with 413')
        or diag('the limit was configured and not applied - the exporter is '
              . 'told its batch was accepted');
}

# An unknown ingest option is an ERROR. The common case is a typo, and a typo
# is exactly the case that must not look like it worked.
{
    my $ok = eval { Punk::Plugin::Observe::_ingest({ ingest => { max_bytes => 1 } }); 1 };
    ok(!$ok, 'a misspelled ingest option is refused');
    like($@ || '', qr/max_bytes/, '  naming the key that was not understood');
    like($@ || '', qr/max_body/,  '  and the ones that are');
}

# --- the series counter is fed by ingest, and counts DISTINCT ---------------
#
# The status page read this counter for months while nothing incremented it,
# and showed `0 of 100,000` over a third of a gigabyte of stored telemetry:
# an all-clear nobody checked, on the exact figure whose job is warning that
# a cap is near.
#
# A series id is derived - H128 of the canonical label block - so there is no
# admission event; knowing one is NEW needs the set already seen. The set
# lives as a bloom filter in the pre-fork shared arena, and the identity
# counted here is the same bytes and same hash the segment writer interns at
# seal, so what ingest counts is what the store calls a series.
{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $a = Punk::Plugin::Observe::_arena({ limits => { series => 1000 } });

    # Metric payloads, because the gate is METRIC-scoped: only metrics have
    # per-series ongoing state for the cap to bound. Logs pass ungated - the
    # dedicated block below pins that.
    my $body = sub {
        my (@svc) = @_;
        return File::Raw::JSON::file_json_decode(
            File::Raw::JSON::file_json_encode({ resourceMetrics => [ map { {
                resource => { attributes => [ { key => 'service.name',
                                                value => { stringValue => $_ } } ] },
                scopeMetrics => [ { metrics => [ { name => 'demo.gauge',
                    gauge => { dataPoints => [
                        { timeUnixNano => '1774224000000000000',
                          asDouble => 1 } ] } } ] } ],
            } } @svc ] }));
    };
    my $series = sub {
        Punk::Observe::Segment::shm_stats($a->{handle})->{series} };

    Punk::Observe::Ingest::decode_append($store->wal_path, $body->(qw(shop cards)),
        'metrics', 'json', 1, '200000000', 0, $a->{handle}, 0, 0);
    is($series->(), 2, 'two label sets are two series');

    Punk::Observe::Ingest::decode_append($store->wal_path, $body->(qw(shop cards)),
        'metrics', 'json', 1, '200000000', 0, $a->{handle}, 0, 0);
    is($series->(), 2, '  polling the same two again counts nothing')
        or diag('the bloom is not remembering - every batch recounts');

    Punk::Observe::Ingest::decode_append($store->wal_path, $body->(qw(shop api ledger)),
        'metrics', 'json', 1, '200000000', 0, $a->{handle}, 0, 0);
    is($series->(), 4, '  and only the genuinely new ones move it');

    Punk::Observe::Segment->can('shm_free')->($a->{handle});
}

# --- THE GATE: past the cap, a new series overflows and nothing is lost -----
#
# The display existed before the enforcement: the page showed `86,900 of
# 100,000` while nothing would have happened at 100,000. Now something does,
# and it is the documented something:
#
#   - an EXISTING series is never touched, and never evicted to make room
#   - a NEW series past the cap is not stored as itself and not dropped:
#     its records are rewritten onto the named overflow series, so the
#     volume survives and the data says "you exceeded the cap"
#   - `rejected` counts refused SERIES once each; `overflow` counts their
#     RECORDS, every one
#   - the exporter is NOT told these were rejected: they were kept, and a
#     partial success naming them would invite a duplicating resend
{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $h = Punk::Observe::Segment::shm_new(3);          # a cap of THREE

    my $body = sub {
        my (@svc) = @_;
        return File::Raw::JSON::file_json_decode(
            File::Raw::JSON::file_json_encode({ resourceMetrics => [ map { {
                resource => { attributes => [ { key => 'service.name',
                                                value => { stringValue => $_ } } ] },
                scopeMetrics => [ { metrics => [ { name => 'demo.gauge',
                    gauge => { dataPoints => [
                        { timeUnixNano => '1774224000000000000',
                          asDouble => 1 } ] } } ] } ],
            } } @svc ] }));
    };
    my $send = sub {
        Punk::Observe::Ingest::decode_append($store->wal_path, $body->(@_),
            'metrics', 'json', 1, '200000000', 0, $h, 0, 0);
    };
    my $stats = sub { Punk::Observe::Segment::shm_stats($h) };

    my $r1 = $send->(qw(a b c));
    ok(!$r1->{overflowed}, 'three series under a cap of three all admit');
    is($stats->()->{series}, 3, '  and are counted');

    my $r2 = $send->(qw(d e));
    is($r2->{overflowed}, 2, 'two new series past the cap overflow');
    ok(!exists $r2->{rejected},
       '  and are NOT reported as rejected to the exporter - they were kept, '
     . 'and a partial success would invite a duplicating resend');
    is($stats->()->{rejected}, 2, '  two refused series');
    is($stats->()->{overflow}, 2, '  two records attributed');

    my $r3 = $send->(qw(a d f));
    is($r3->{overflowed}, 2, 'a refused series overflows again; an existing one passes');
    is($stats->()->{rejected}, 3,
       '  but only the genuinely new refusal counts a series')
        or diag('d was already refused - recounting it makes rejected a '
              . 'record count wearing a series label');
    is($stats->()->{overflow}, 4, '  while its records all count');

    # WHAT THE STORE HOLDS. Volume preserved, cardinality stopped.
    $store->seal;
    my %W = (from => '1774224000000000000', to => '1774224060000000000');
    my $rows = sub {
        my $r = $store->query($_[0], %W);
        return $r && $r->{ok} ? scalar @{ $r->{rows} || [] } : -1;
    };
    is($rows->('metric demo.gauge'), 8,
       'every record sent was stored - the cap loses nothing');
    is($rows->('metric demo.gauge | where otel.overflow = "cap"'), 4,
       '  four of them on the named overflow series, queryable as such');
    is($rows->('metric demo.gauge | where service = "a"'), 2,
       '  and an existing series keeps working, both before and after the cap');

    Punk::Observe::Segment->can('shm_free')->($h);
}

# --- logs and spans are NOT gated -------------------------------------------
#
# The cap bounds per-series ONGOING state - rollups, exemplar sidecars,
# compression streams - and only metrics have any. A log line with a unique
# attribute block is bytes in a sealed segment, paid once and aged out by
# retention; its bound is the rate limiter. The requirement is blunt: you can
# log ANY data, payment ids included, without minting a series per checkout -
# so a full cap must not touch a log record, and its attributes must survive.
{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $h = Punk::Observe::Segment::shm_new(2);          # a cap of TWO

    my $logs = sub {
        my (@id) = @_;
        return File::Raw::JSON::file_json_decode(
            File::Raw::JSON::file_json_encode({ resourceLogs => [ map { {
                resource => { attributes => [ { key => 'service.name',
                                                value => { stringValue => 'shop' } } ] },
                scopeLogs => [ { logRecords => [
                    { timeUnixNano => '1774224000000000000',
                      severityNumber => 9,
                      body => { stringValue => "checkout $_" },
                      attributes => [ { key => 'payment.id',
                                        value => { stringValue => $_ } } ] } ] } ],
            } } @id ] }));
    };
    my $r = Punk::Observe::Ingest::decode_append($store->wal_path,
        $logs->(map { sprintf 'PAY-%06d', $_ } 1 .. 20),
        'logs', 'json', 1, '200000000', 0, $h, 0, 0);
    ok($r->{ok}, 'twenty log lines with twenty distinct payment ids ingest');
    ok(!$r->{overflowed}, '  none overflow, against a cap of two');

    my $st = Punk::Observe::Segment::shm_stats($h);
    is("$st->{series}", '0', '  and none consumed a series slot');
    is("$st->{rejected}", '0', '  nor was any refused');

    $store->seal;
    my $q = $store->query(
        'log | where payment.id = "PAY-000007" | count',
        from => '1774224000000000000', to => '1774224060000000000');
    is($q->{groups}[0]{value}, 1,
       'and the unbounded field survives, filterable by exact value');

    Punk::Observe::Segment->can('shm_free')->($h);
}

# --- retention is a plugin option, validated at boot ------------------------
#
# `retain => { keep => '7d' }` schedules deletion on the host's queue. There
# is NO default window - a retention job with a silently defaulted window is
# a deletion job - and a window that does not parse is a boot failure,
# because the alternative is an operator who believes deletion is running
# when nothing is.
{
    my $P = 'Punk::Plugin::Observe';

    eval { $P->register(undef, { guard => sub { 1 },
                                 retain => { keep => '7 fortnights' } }) };
    like($@, qr/not a window/, 'a keep that does not parse croaks at boot');

    eval { $P->register(undef, { guard => sub { 1 }, retain => {} }) };
    like($@, qr/retain needs keep/, 'an absent keep croaks - no silent default');

    # A WINDOW MEASURED IN YEARS, which is what a production store keeps and
    # what the demo's own `1y` asked for before the unit existed.
    my $yr = eval { $P->register(undef, { guard => sub { 1 },
                                          retain => { keep => '7y' } }) };
    is($yr->{retain_opts}{keep_ns}, '220752000000000000',
       'a keep in years parses - 365 days to the year');

    # AND ONE TOO LARGE TO REPRESENT IS REFUSED, NOT WRAPPED. The cutoff is
    # `now - keep` in unsigned nanoseconds: a keep past the top comes back
    # round as a cutoff of now, which marks every segment in the store for
    # deletion. Refusing is a typo caught at boot; wrapping is an empty
    # store.
    eval { $P->register(undef, { guard => sub { 1 },
                                 retain => { keep => '1000y' } }) };
    like($@, qr/not a window/,
         'a window past the last representable instant croaks at boot');

    my $st = eval { $P->register(undef, { guard => sub { 1 },
                                          retain => { keep => '7d' } }) };
    ok($st, 'a real window registers');
    is($st->{retain_opts}{keep_ns}, 7 * 86_400 * 1_000_000_000,
       '  parsed to nanoseconds once, at boot');
    is($st->{retain_opts}{at}, '17 * * * *',
       '  hourly at :17 by default - an off-minute, so it does not stampede '
     . 'with anything that fires on the hour');

    eval { $P->register(undef, { guard => sub { 1 },
                                 retain => { keep => '7d',
                                             at => 'every tuesday' } }) };
    like($@, qr/not a cron expression/,
         'a schedule that does not parse croaks as hard as the window - a '
       . 'cron that never fires is deletion an operator believes is running');

    my $at = eval { $P->register(undef, { guard => sub { 1 },
        retain => { keep => '30d', at => '40 2 * * *' } }) };
    is($at->{retain_opts}{at}, '40 2 * * *', 'and a real one is kept as given');

    my $st2 = eval { $P->register(undef, { guard => sub { 1 } }) };
    ok($st2 && !$st2->{retain_opts},
       'and absent the option, nothing is ever scheduled or deleted');
}

# --- retain_job deletes what has aged out and nothing else ------------------
{
    require File::Temp; require File::Path; require Punk::Observe::Retain;
    require Punk::Observe::WAL;

    my $d = File::Temp::tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $d);
    my $now = Punk::Observe::now_ns();

    my $seed_seg = sub {
        my ($age_ns) = @_;
        my $t = Punk::Observe::Store::nsub($now, $age_ns);
        Punk::Observe::WAL::append($store->wal_path,
            [ { kind => 2, t => $t, body => 'old', severity => 9,
                attrs => { 'service.name' => 'a' } } ], 0, 0);
        $store->seal;
    };
    $seed_seg->(9 * 86_400 * 1_000_000_000);    # nine days old
    $seed_seg->(3_600 * 1_000_000_000);         # an hour old

    my $out = Punk::Observe::Retain::pass(store => $store,
                                          keep_ns => 7 * 86_400 * 1_000_000_000);
    is($out->{unlinked}, 1, 'the nine-day segment is unlinked');
    is($out->{kept}, 1, '  and the one inside the window is kept whole');
    is($out->{truncate_calls} || 0, 0,
       '  with no truncate anywhere, because that is SIGBUS for a reader');
}

# --- THE WINDOW: what clears the old so the new can load --------------------
#
# A bloom can only add, so before this the admitted set was append-only for
# the life of the process: a series dead for weeks - its data long since
# retained away - still held a cap slot until restart. Eviction is still
# never the answer; LIVENESS is. The admitted set rotates on a window, an
# active series re-registers itself with its next record, and a dead one
# simply never does - so its slot frees, and a series the cap refused last
# window gets a fresh chance against the room the dead left behind.
{
    my $dir = tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $h = Punk::Observe::Segment::shm_new(3);          # a cap of THREE

    my $body = sub {
        my (@svc) = @_;
        return File::Raw::JSON::file_json_decode(
            File::Raw::JSON::file_json_encode({ resourceMetrics => [ map { {
                resource => { attributes => [ { key => 'service.name',
                                                value => { stringValue => $_ } } ] },
                scopeMetrics => [ { metrics => [ { name => 'demo.gauge',
                    gauge => { dataPoints => [
                        { timeUnixNano => '1774224000000000000',
                          asDouble => 1 } ] } } ] } ],
            } } @svc ] }));
    };
    my $send = sub {
        Punk::Observe::Ingest::decode_append($store->wal_path, $body->(@_),
            'metrics', 'json', 1, '200000000', 0, $h, 0, 0);
    };
    my $stats = sub { Punk::Observe::Segment::shm_stats($h) };

    $send->(qw(a b c));                        # the cap is full
    my $r = $send->(qw(d));
    is($r->{overflowed}, 1, 'd is refused against a full cap');
    is($stats->()->{series}, 4,
       '  four active: three admitted, and the overflow series the refusal '
     . 'just created is itself a series');

    # THE WINDOW TURNS. b and c have died; a is still reporting.
    Punk::Observe::Segment::shm_rotate($h);
    is($stats->()->{series}, 0, 'a fresh window counts nothing yet');

    my $r2 = $send->(qw(a d));
    ok(!$r2->{overflowed},
       'a re-registers as an established series, and d LOADS - the slots b '
     . 'and c stopped defending are free')
        or diag('the rotation is not clearing the refused set, or carry-over '
              . 'is being cap-checked');
    is($stats->()->{series}, 2, '  two active: the survivor and the newcomer');

    # And the monotonic ledgers stay monotonic: what was refused was refused.
    is($stats->()->{rejected}, 1, 'rejected is history, not a gauge');

    # An established series is NEVER refused by the new window, even when
    # newcomers filled it first - that would be the eviction this design
    # refuses, upside down.
    Punk::Observe::Segment::shm_rotate($h);
    $send->(qw(x y z));                        # newcomers take the window
    my $r3 = $send->(qw(a));
    ok(!$r3->{overflowed},
       'a was admitted last window and still reports: it is not squeezed out');
    is($stats->()->{series}, 4, '  even past the cap, bounded by last window');

    Punk::Observe::Segment->can('shm_free')->($h);
}

done_testing();

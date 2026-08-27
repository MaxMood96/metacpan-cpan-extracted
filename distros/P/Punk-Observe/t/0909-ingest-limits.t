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

done_testing();

#!perl
# The store: sealing, the summary beside a segment, and the read path.
#
# The assertion that matters is that a record survives the whole way round -
# ingest to WAL to seal to query - with the fields a query filters on still in
# it. The store was lossless in the decoder and lossy in the log, and the
# symptom was a UI whose columns were empty rather than an error anywhere.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;

my $S = 'Punk::Observe::Store';

# A span, a log line and a metric point, with everything a query reads.
my $T0 = '1774224000000000000';
sub ns { my $n = $_[0]; my $s = $T0; $s + 0 == $s + 0 ? () : (); return _add($T0, $n) }
sub _add {
    my ($a, $b) = @_;
    my @a = reverse split //, "$a";
    my @b = reverse split //, "$b";
    my ($carry, @out) = (0);
    for my $i (0 .. (@a > @b ? $#a : $#b)) {
        my $d = ($a[$i] || 0) + ($b[$i] || 0) + $carry;
        $carry = $d >= 10 ? 1 : 0;
        push @out, $d % 10;
    }
    push @out, $carry if $carry;
    return join '', reverse @out;
}

sub span {
    my (%o) = @_;
    return {
        kind => 3, t => $o{t}, duration => $o{dur} || '1000000',
        body => $o{name}, severity => 0, status => $o{status} || 0,
        span_kind => $o{span_kind} || 2,
        trace_hi => $o{hi}, trace_lo => $o{lo},
        span_id => $o{id}, parent_id => $o{parent} || 0,
        attrs => { 'service.name' => $o{service},
                   ($o{route} ? ('http.route' => $o{route}) : ()) },
    };
}

sub logline {
    my (%o) = @_;
    return {
        kind => 2, t => $o{t}, body => $o{body},
        severity => $o{severity} || 9, duration => 0,
        trace_hi => $o{hi} || 0, trace_lo => $o{lo} || 0,
        span_id => $o{span} || 0, parent_id => 0,
        attrs => { 'service.name' => $o{service} },
    };
}

# --- seal, summarise, read back ---------------------------------------------

my $dir = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');

is($store->tenant, 'acme', 'the tenant is the subtree, not a label');
is_deeply($store->segments, [], 'a new store has no segments');
is_deeply($store->stats->{segments}, 0, '  and says so');

my $wal = $store->wal_path;
ok(-d File::Spec->catdir($dir, 'acme', 'wal'), 'the log directory is created');

# One trace: shop -> cards, the second one failing.
my @recs = (
    span(t => _add($T0, 0), dur => '5000000', name => 'GET /checkout',
         service => 'shop',  hi => 111, lo => 222, id => 1, route => '/checkout'),
    span(t => _add($T0, 1000000), dur => '3000000', name => 'POST /authorize',
         service => 'cards', hi => 111, lo => 222, id => 2, parent => 1,
         status => 2, span_kind => 3),
    logline(t => _add($T0, 2000000), body => 'card refused: insufficient funds',
            severity => 17, service => 'cards', hi => 111, lo => 222, span => 2),
    logline(t => _add($T0, 2500000), body => 'checkout complete',
            severity => 9, service => 'shop', hi => 111, lo => 222, span => 1),
);

my $r = Punk::Observe::WAL::append($wal, \@recs, 0, 0);
ok($r->{ok}, 'records reach the log');

# Unsealed, the live log is still readable.
{
    my ($rows, $meta) = $store->rows;
    is(scalar @$rows, 4, 'a live log is read without being sealed');
    is($meta->{files}, 1, '  from one file');
    is($meta->{skipped}, 0, '  with nothing skipped');
    is($rows->[0]{kind}, 'log', 'newest first');
}

my $seg = $store->seal;
ok($seg, 'the log seals');
ok(-f $seg, '  to a segment file');
ok(!-e $wal, '  and the live log is gone');
(my $idx = $seg) =~ s/\.seg\z/.idx/;
ok(-f $idx, '  with a summary beside it');

# --- the summary is the index ------------------------------------------------

{
    my $segs = $store->segments;
    is(scalar @$segs, 1, 'one segment');
    my $ix = $segs->[0]{index};
    ok($ix, '  with its summary read back');
    is($ix->{records}, 4, '  four records');
    is($ix->{spans},   2, '  two spans');
    is($ix->{logs},    2, '  two log lines');
    is($ix->{errors},  1, '  one span in error');
    is($ix->{traces},  1, '  one trace');
    is($ix->{severity}{17}, 1, '  the severity histogram counts the error');
    is($ix->{service}{cards}, 2, '  and the services');
    is($ix->{t_min}, $recs[0]{t}, '  the time span starts at the first record');
    is($ix->{t_max}, $recs[3]{t}, '  and ends at the last');
}

# --- a record survives the whole way round -----------------------------------

{
    my ($rows) = $store->rows;
    is(scalar @$rows, 4, 'four rows come back out of the segment');

    my ($err) = grep { $_->{severity} == 17 } @$rows;
    ok($err, 'the error log line is there');
    is($err->{body}, 'card refused: insufficient funds', '  with its body');
    is($err->{service}, 'cards', '  its service lifted out of the attributes');
    is("$err->{trace_hi}", '111', '  and its trace id, so the join is possible');
    is($err->{kind}, 'log', '  as a log row');

    my ($sp) = grep { $_->{kind} eq 'span' && $_->{status} == 2 } @$rows;
    ok($sp, 'the failed span is there');
    is($sp->{duration}, '3000000', '  with its duration');
    is($sp->{attrs}{'service.name'}, 'cards', '  and its attributes');
}

# --- the range skips a segment from its summary ------------------------------

{
    my ($rows, $meta) = $store->rows(from => _add($T0, '999999999999'));
    is(scalar @$rows, 0, 'a range past the segment returns nothing');
    is($meta->{skipped}, 1, '  having skipped it without opening it');
    is($meta->{files}, 0, '  so no file was read');
}

# --- the service graph -------------------------------------------------------

{
    my $g = $store->graph;
    my @e = @{ $g->{edges} };
    is(scalar @e, 2, 'two edges: the root into shop, and shop into cards');

    my ($root) = grep { $_->{caller} eq '*' } @e;
    ok($root, 'traffic from outside arrives at the synthetic root');
    is($root->{callee}, 'shop', '  into the service that was called');

    my ($hop) = grep { $_->{caller} eq 'shop' } @e;
    ok($hop, 'shop calls cards');
    is($hop->{callee}, 'cards', '  and the callee is named, not numbered');
    is($hop->{errors}, 1, '  with the error attributed to the edge');

    is($g->{services}{shop}, 2, 'the services carry their record counts');
    is($g->{services}{cards}, 2, '  once each, not once per span as well');
}

# --- an edge survives its two halves landing in different segments -----------
#
# THE GRAPH CANNOT BE MERGED FROM PER-SEGMENT SUMMARIES.
#
# A graph derived from one file can only see the parents that are IN that
# file, and a span whose parent is absent is attributed to the SYNTHETIC ROOT.
# A trace whose caller and callee were received by different workers - or
# landed either side of a seal - therefore has each half summarised alone, and
# the map draws every service as if traffic arrived at it from outside, which
# is precisely the topology it exists to disprove.
#
# It looks like it is working. In the demo it turned ninety-six `shop -> cards`
# calls into six.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = $S->new(dir => $d);

    # The caller, sealed on its own.
    Punk::Observe::WAL::append($st->wal_path, [
        span(t => $T0, dur => '5000000', name => 'POST /checkout',
             service => 'shop', hi => 77, lo => 88, id => 1),
    ], 0, 0);
    ok($st->seal, 'the caller is sealed into one segment');

    # The callee, sealed into a different one.
    Punk::Observe::WAL::append($st->wal_path, [
        span(t => _add($T0, 1_000_000), dur => '3000000',
             name => 'POST /authorize', service => 'cards',
             hi => 77, lo => 88, id => 2, parent => 1, span_kind => 3),
    ], 0, 0);
    ok($st->seal, '  and the callee into another');
    is(scalar @{ $st->segments }, 2, '  two segments');

    my $g = $st->graph;
    my ($hop) = grep { $_->{caller} eq 'shop' } @{ $g->{edges} };
    ok($hop, 'the edge is still shop -> cards')
        or diag 'edges: ' . join(', ', map { "$_->{caller}->$_->{callee}" }
                                       @{ $g->{edges} });
    is($hop->{callee}, 'cards', '  and not shop -> nothing');

    my ($root) = grep { $_->{caller} eq '*' && $_->{callee} eq 'cards' }
                 @{ $g->{edges} };
    ok(!$root, 'and cards is NOT attributed to the synthetic root');

    is($g->{services}{shop}, 1, 'services are still counted once');
    is($g->{services}{cards}, 1, '  from both segments');
}

# --- one trace, assembled ----------------------------------------------------

{
    my $t = $store->trace(111, 222);
    ok($t, 'the trace assembles');
    is($t->{span_count}, 2, '  two spans');
    is($t->{spans}[0]{depth}, 0, '  the root at depth 0');
    is($t->{spans}[0]{name}, 'GET /checkout', '  named');
    is($t->{spans}[0]{service}, 'shop', '  and attributed');
    is($t->{spans}[1]{depth}, 1, '  the child a level down');
    is($t->{spans}[1]{service}, 'cards', '  in the other service');
    is($t->{spans}[0]{offset}, 0, '  the root starts at zero');
    is($t->{spans}[1]{offset}, '1000000', '  the child at its real offset');
    is($t->{cycles}, 0, '  no cycles');

    ok(!defined $store->trace(999, 999), 'a trace that is not there is undef');
}

# --- the trace search --------------------------------------------------------

{
    my $r = $store->traces;
    is(scalar @{ $r->{traces} }, 1, 'the search finds the trace');
    is($r->{traces}[0]{spans}, 2, '  with its span count');
    is($r->{traces}[0]{errors}, 1, '  and its errors');

    my $slow = $store->traces(min_duration => '999999999999');
    is(scalar @{ $slow->{traces} }, 0, 'a duration floor excludes it');

    my $errs = $store->traces(errors_only => 1);
    is(scalar @{ $errs->{traces} }, 1, 'errors_only keeps a failing trace');
}

# --- queries -----------------------------------------------------------------

{
    my $r = $store->query('log | where severity >= error');
    ok($r->{ok}, 'a query runs') or diag($r->{error} || '');
    is(scalar @{ $r->{rows} || [] }, 1, '  matching one row');
    is($r->{rows}[0]{body}, 'card refused: insufficient funds',
       '  and it is the error, not the info line');
    ok($r->{store}, '  the answer says what was read');

    my $all = $store->query('log');
    is(scalar @{ $all->{rows} || [] }, 2, 'an unfiltered log query sees both');

    my $bad = $store->query('log | where severity >>> error');
    ok(!$bad->{ok}, 'a query that will not parse fails');
    is($bad->{stage}, 'parse', '  at the parse stage');
    ok(length($bad->{error} || ''), '  with a message to show');
}

# --- retention ---------------------------------------------------------------

{
    # A second segment, so there is something to delete.
    my $w2 = $store->wal_path;
    Punk::Observe::WAL::append($w2, [ $recs[0] ], 0, 0);
    $store->seal;
    is(scalar @{ $store->segments }, 2, 'two segments');

    my $r = $store->retain(bytes => 1);
    cmp_ok($r->{deleted}, '>', 0, 'retention deletes whole segments');
    cmp_ok(scalar @{ $store->segments }, '<', 2, '  and the store shrinks');
}

# --- a log this build cannot read is reported, not guessed at ----------------

{
    my $d2 = tempdir(CLEANUP => 1);
    my $s2 = $S->new(dir => $d2);
    my $p  = $s2->wal_path;
    Punk::Observe::WAL::append($p, [ $recs[0] ], 0, 0);

    open my $fh, '+<:raw', $p or die $!;
    seek $fh, 38, 0;
    print $fh pack('v', 1);          # a version this build does not know
    close $fh;

    my ($rows, $meta) = $s2->rows;
    is(scalar @$rows, 0, 'an unreadable log yields no records');
    is($meta->{degraded}, 1, '  and the answer says it was degraded');
}

# --- THE GRAPH FROM A LIVE LOG ---------------------------------------------
#
# A sealed segment answers from its sidecar; an UNSEALED one has no sidecar
# and has to be summarised on the spot. That is a different code path, and it
# had no test - which is how it survived a refactor that deleted the function
# it called. It only fails once there is an unsealed log with spans in it,
# which no other assertion here produces.

{
    my $dir2 = tempdir(CLEANUP => 1);
    my $live = Punk::Observe::Store->new(dir => $dir2);

    # Two services, one calling the other, in a log that is NEVER sealed.
    my $t = $T0;
    Punk::Observe::WAL::append($live->wal_path, [
        { t => $t, kind => 3, body => 'GET /pay',
          attrs => { 'service.name' => 'gateway' },
          trace_hi => '7', trace_lo => '7', span_id => '1', parent_id => '0',
          duration => '5000', span_kind => 2 },
        { t => _add($t, '100'), kind => 3, body => 'POST /authorize',
          attrs => { 'service.name' => 'cards' },
          trace_hi => '7', trace_lo => '7', span_id => '2', parent_id => '1',
          duration => '3000', span_kind => 3 },
    ], 1, '0');

    my $segs = $live->segments;
    is(scalar(grep { !$_->{sealed} } @$segs), 1, 'the log is still unsealed');

    my $g = $live->graph;
    ok($g, 'a graph comes back from a live log') or diag 'graph died';
    cmp_ok(scalar @{ $g->{edges} || [] }, '>=', 1,
           '  with at least one edge in it');
    ok($g->{services}{gateway}, '  and the caller among the services');
    ok($g->{services}{cards},   '  and the callee');
}

# --- the fast attribute walk agrees with the encoder -------------------------
#
# `service` is lifted out of the attribute block by a walk that decodes ONE
# key and skips the rest. Skipping requires knowing how wide each value is,
# and an int is eight fixed bytes rather than a varint - so a walk that
# guessed varint consumed one byte where eight were written, lost its place
# inside the value, and read every subsequent key out of the middle of
# something.
#
# The failure is not a wrong number. It is that `service.name` stops matching
# and EVERY ROW IN THE STORE renders as "unknown", which is what a real
# `process.pid` attribute did to every service name in the demo.
{
    my $d = tempdir(CLEANUP => 1);
    my $s = $S->new(dir => $d);

    # The attribute block is sorted, so these land BEFORE service.name and
    # every one of them has to be skipped correctly to reach it.
    my $rec = {
        kind => 2, t => $T0, body => 'hello', severity => 9,
        duration => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
        parent_id => 0,
        attrs => {
            'aaa.int'    => 7,              # an integer, eight bytes
            'bbb.double' => 1.5,            # a double, eight bytes
            'ccc.string' => 'x' x 200,      # a two-byte length varint
            'ddd.big'    => 2_147_483_648,  # past 32 bits
            'eee.zero'   => 0,
            'service.name' => 'cards',      # sorts last, so nothing may drift
        },
    };
    ok(Punk::Observe::WAL::append($s->wal_path, [ $rec ], 0, 0)->{ok},
       'a record with mixed attribute types is stored');

    my ($rows) = $s->rows;
    is(scalar @$rows, 1, 'and comes back');
    is($rows->[0]{service}, 'cards',
       'the fast walk finds service.name past an int, a double and a string');

    # The slow decoder and the fast walk must agree, or one of them is wrong
    # and only the other one is tested.
    my ($recs) = $s->records;
    is($recs->[0]{attrs}{'service.name'}, $rows->[0]{service},
       '  and agrees with the full attribute decode');
    is($recs->[0]{attrs}{'aaa.int'}, 7, '  which reads the integer correctly');
    is($recs->[0]{attrs}{'ddd.big'}, 2_147_483_648, '  past 32 bits too');

    # And the summary written at seal reads the same block through the same
    # walk, so a drift there is a status page that reports every service as
    # unknown while the map draws them by name.
    $s->seal;
    my $ix = $s->segments->[0]{index};
    is($ix->{service}{cards}, 1, 'the sidecar attributes the record too');
}

# --- retention and status, now that both are C ------------------------------
#
# Three assertions covered these before the port, which is not enough to have
# rewritten them behind. Each branch the C has is one the Perl had.

{
    my $d3 = tempdir(CLEANUP => 1);
    my $s3 = Punk::Observe::Store->new(dir => $d3);

    # Four sealed segments, one record each.
    for my $i (1 .. 4) {
        Punk::Observe::WAL::append($s3->wal_path,
            [ { t => _add($T0, $i * 1000), kind => 2, body => "line $i",
                attrs => { 'service.name' => "svc$i" } } ], 1, '0');
        $s3->seal;
    }

    my $st = $s3->stats;
    is($st->{segments}, 4, 'four sealed segments are counted');
    is($st->{wal_depth}, 0, '  with no live log yet');
    is($st->{records}, 4, '  and their records add up from the sidecars');
    is($st->{logs}, 4, '  by kind');
    is($st->{services}, 4, '  four distinct services');
    is($st->{service}{svc1}, 1, '  each counted by name');
    is($st->{unindexed}, 0, '  none unindexed');
    is($st->{orphan_index}, 0, '  and no orphan sidecar');
    cmp_ok($st->{bytes}, '>', 0, '  with a byte total');

    # KEEP IS A FLOOR. A budget of one byte would delete everything; `keep`
    # is what stops a misconfigured budget emptying the store.
    my $r = $s3->retain(bytes => 1, keep => 2);
    is($r->{kept}, 2, 'retention stops at the keep floor');
    is($r->{deleted}, 2, '  having deleted the rest');
    cmp_ok($r->{freed}, '>', 0, '  and reports what it freed');
    is(scalar @{ $s3->segments }, 2, '  the store really shrank');

    # Oldest first: the two that survive are the NEWEST two.
    my ($rows) = $s3->rows;
    my %left = map { $_->{body} => 1 } @$rows;
    ok($left{'line 4'}, 'the newest record survived');
    ok(!$left{'line 1'}, '  and the oldest was the one deleted');

    # The sidecar goes with the segment. An index left behind is the other
    # half of an interrupted pass.
    my $after = $s3->stats;
    is($after->{orphan_index}, 0, 'retention removes the sidecar too');
    is($after->{segments}, 2, '  and the count follows');
}

{
    # A budget that is already satisfied deletes nothing.
    my $d4 = tempdir(CLEANUP => 1);
    my $s4 = Punk::Observe::Store->new(dir => $d4);
    Punk::Observe::WAL::append($s4->wal_path,
        [ { t => $T0, kind => 2, body => 'x' } ], 1, '0');
    $s4->seal;

    my $r = $s4->retain(bytes => 1_000_000_000);
    is($r->{deleted}, 0, 'a budget the store is under deletes nothing');
    is($r->{kept}, 1, '  and keeps what is there');

    $r = $s4->retain();
    is($r->{deleted}, 0, 'no budget at all deletes nothing');
}

{
    # An UNINDEXED segment is a seal that was interrupted. It is still
    # readable and still counted, and saying so is the difference between a
    # number that is low and a number that is wrong.
    my $d5 = tempdir(CLEANUP => 1);
    my $s5 = Punk::Observe::Store->new(dir => $d5);
    Punk::Observe::WAL::append($s5->wal_path,
        [ { t => $T0, kind => 2, body => 'x' } ], 1, '0');
    $s5->seal;

    my ($idx) = glob("$d5/default/wal/*.idx");
    ok($idx, 'a sidecar was written');
    unlink $idx;

    my $st = $s5->stats;
    is($st->{segments}, 1, 'a segment with no sidecar is still counted');
    is($st->{unindexed}, 1, '  and reported as unindexed');
    is($st->{records}, 0, '  contributing no figures it cannot read');

    # And the reverse: a sidecar whose segment is gone.
    my ($seg) = glob("$d5/default/wal/*.seg");
    open my $fh, '>', $idx or die $!;
    print $fh "records\t1\n";
    close $fh;
    unlink $seg;
    is($s5->stats->{orphan_index}, 1, 'an orphan sidecar is counted');
}

{
    # A live log counts towards wal_depth and not towards segments.
    my $d6 = tempdir(CLEANUP => 1);
    my $s6 = Punk::Observe::Store->new(dir => $d6);
    Punk::Observe::WAL::append($s6->wal_path,
        [ { t => $T0, kind => 2, body => 'x' } ], 1, '0');
    my $st = $s6->stats;
    is($st->{wal_depth}, 1, 'an unsealed log is wal_depth');
    is($st->{segments}, 0, '  and not a segment');
    cmp_ok($st->{bytes}, '>', 0, '  but its bytes still count');
}

{
    # An empty store answers rather than dying.
    my $d7 = tempdir(CLEANUP => 1);
    my $s7 = Punk::Observe::Store->new(dir => $d7);
    my $st = $s7->stats;
    is($st->{segments}, 0, 'an empty store reports zero segments');
    is($st->{records}, 0, '  and zero records');
    is_deeply($st->{service}, {}, '  with no services');
    my $r = $s7->retain(bytes => 1);
    is($r->{deleted}, 0, '  and retention on it deletes nothing');
}

# --- the seal trailer is not a frame of records ------------------------------
#
# THIS ONE CRASHED THE PROCESS.
#
# The trailer is the one frame allowed to hold no records, and it carries the
# FILE'S TOTAL RECORD COUNT in the header field every other frame uses for its
# own count, with frame_len zero. A walker that does not check the sealed flag
# reads that many po_rec - 88 bytes each - past the end of the buffer.
#
# It survives on a small store, because the overread lands in heap slack. On a
# real one the trace screen took SIGBUS, and the reason a unit test had not
# caught it is that a unit test seals a segment holding four records rather
# than four thousand.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = $S->new(dir => $d);

    # Enough records that the trailer's count, walked as data, reaches well
    # past anything the allocator might have left lying around.
    my @many;
    for my $i (0 .. 1999) {
        push @many, span(t => _add($T0, $i * 1_000_000),
                         name => "GET /item/$i", service => 'shop',
                         hi => 900 + ($i % 50), lo => 1, id => $i + 1);
    }
    ok(Punk::Observe::WAL::append($st->wal_path, \@many, 0, 0)->{ok},
       'two thousand spans reach the log');
    ok($st->seal, '  and the log seals, writing the trailer');

    # Every reader that walks frames. Each of these read the trailer as
    # records before the flag was checked.
    my $tr = $st->traces(limit => 10);
    cmp_ok(scalar @{ $tr->{traces} }, '>', 0,
           'the trace search survives a sealed segment');

    my $one = $st->trace(900, 1);
    ok($one, '  and so does assembling one trace');

    my $g = $st->graph;
    ok(ref $g->{edges} eq 'ARRAY', '  and the service graph');

    my $ix = $st->segments->[0]{index};
    is($ix->{spans}, 2000, 'the summary counts the records and not the trailer')
        or diag 'the trailer was counted as records';
    is($ix->{records}, 2000, '  every one of them, once');
}

# --- `slowest` and `sort` ORDER, they do not merely limit --------------------
#
# Both stages were recorded by the planner and used by nobody: `slowest N`
# acted as a bare limit and `sort` did nothing at all.
#
# THE FAILURE HAS THE RIGHT SHAPE, which is what makes it bad. `slowest 20`
# returned twenty rows, of the right kind, with durations on them - and they
# were whichever twenty the scan reached first. The store hands rows over
# newest first, so it returned the NEWEST twenty while looking exactly like it
# had worked, to a reader who is on that screen precisely because they want
# the extreme.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = $S->new(dir => $d);

    # Durations DESCENDING with time, so "newest first" and "slowest first"
    # are opposite orders and taking the first N cannot accidentally pass.
    my @recs;
    for my $i (0 .. 19) {
        push @recs, span(t => _add($T0, $i * 1_000_000_000),
                         dur => (20 - $i) * 1_000_000,
                         name => "op$i", service => "svc" . ($i % 3),
                         hi => 500 + $i, lo => 7, id => $i + 1);
    }
    ok(Punk::Observe::WAL::append($st->wal_path, \@recs, 0, 0)->{ok},
       'twenty spans, slowest oldest');

    my $r = $st->query('trace | slowest 5');
    ok($r->{ok}, 'slowest runs') or diag $r->{error};
    is(scalar @{ $r->{rows} }, 5, '  returning five rows');
    is($r->{rows}[0]{duration}, '20000000',
       '  and the FIRST is the slowest, not the newest');
    my @d = map { $_->{duration} + 0 } @{ $r->{rows} };
    is_deeply(\@d, [ sort { $b <=> $a } @d ], '  in descending order');

    my $asc = $st->query('spans | sort duration | limit 5');
    ok($asc->{ok}, 'sort runs') or diag $asc->{error};
    my @a = map { $_->{duration} + 0 } @{ $asc->{rows} };
    is_deeply(\@a, [ sort { $a <=> $b } @a ], 'ascending by default');
    is($asc->{rows}[0]{duration}, '1000000', '  starting at the fastest');

    my $desc = $st->query('spans | sort duration desc | limit 5');
    my @z = map { $_->{duration} + 0 } @{ $desc->{rows} };
    is_deeply(\@z, [ sort { $b <=> $a } @z ], 'desc reverses it');

    # A string field sorts by bytes.
    my $svc = $st->query('spans | sort service | limit 20');
    my @s = map { $_->{service} } @{ $svc->{rows} };
    is_deeply(\@s, [ sort @s ], 'a string field sorts by bytes');

    # The same query twice must agree, or a reader comparing two screens is
    # comparing the tie-break.
    my $again = $st->query('trace | slowest 5');
    is_deeply([ map { $_->{duration} } @{ $again->{rows} } ],
              [ map { $_->{duration} } @{ $r->{rows} } ],
              'the order is stable across runs');
}

# A row with no duration is not "the slowest" - it sorts to the bottom rather
# than being read as a zero-length span.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = $S->new(dir => $d);
    Punk::Observe::WAL::append($st->wal_path, [
        logline(t => _add($T0, 5_000_000_000), body => 'a log line',
                severity => 9, service => 'shop'),
        span(t => $T0, dur => '900000', name => 'quick', service => 'shop',
             hi => 1, lo => 1, id => 1),
    ], 0, 0);

    my $r = $st->query('spans | slowest 5');
    is(scalar @{ $r->{rows} }, 1,
       'a log line is not a candidate for the slowest SPAN');
}

# --- `by` GROUPS, and every declared column can be reached -------------------
#
# THREE FAULTS OF THE SAME SHAPE, all of which answered rather than refused.
#
# `by` is its own stage, and the planner only collected group fields off the
# AGGREGATE stage - so `| by service | count` planned to no grouping at all
# and returned one group with an empty key: the right total, presented as
# though it had been split and everything had landed in one bucket.
#
# `status` and `kind` are declared columns for spans, and the row could not
# answer either - so `where status == 2` compared against a field that did not
# exist, which is false for every row. A filter for the failures matched none
# of them and reported zero.
#
# A column the language admits and the row cannot answer is worse than one it
# rejects: a rejection is a message, an unanswerable column is an empty result
# that looks like an answer.
{
    my $d = tempdir(CLEANUP => 1);
    my $st = $S->new(dir => $d);

    my @recs;
    for my $i (0 .. 9) {
        push @recs, span(
            t => _add($T0, $i * 1_000_000),
            dur => (($i % 2) ? '900000000' : '1000000'),   # half of them slow
            name => "op$i",
            service => ($i < 6 ? 'shop' : 'cards'),
            hi => 300 + $i, lo => 5, id => $i + 1,
            status => ($i < 3 ? 2 : 0),                    # three in error
            span_kind => ($i % 3 == 0 ? 3 : 2),            # some client spans
        );
    }
    ok(Punk::Observe::WAL::append($st->wal_path, \@recs, 0, 0)->{ok},
       'ten spans, mixed service, status and kind');

    my %count;
    for my $g (@{ $st->query('spans | by service | count')->{groups} }) {
        $count{ $g->{key} } = $g->{value};
    }
    is($count{shop},  6, '`| by service | count` groups by service');
    is($count{cards}, 4, '  every group, not one bucket');

    # The trailing spelling of the same thing must agree exactly.
    my %trail;
    for my $g (@{ $st->query('spans | count by service')->{groups} }) {
        $trail{ $g->{key} } = $g->{value};
    }
    is_deeply(\%trail, \%count,
              '`count by service` and `| by service | count` are one query');

    # A grouping stage before a filter still applies to the filtered rows.
    my %slow;
    for my $g (@{ $st->query(
        'spans | where duration > 500ms | by service | count')->{groups} }) {
        $slow{ $g->{key} } = $g->{value};
    }
    is($slow{shop} + $slow{cards}, 5, 'the filter runs before the grouping');

    # THE DECLARED COLUMNS. Each of these is in the language's own column
    # table for this source.
    my $err = $st->query('spans | where status == 2 | count');
    is($err->{groups}[0]{value}, 3, '`where status` reaches the row');

    my $client = $st->query('spans | where kind == 3 | count');
    is($client->{groups}[0]{value}, 4, '  and so does `where kind`');

    # Grouping on a NUMERIC column is a key, not an empty string. `severity`,
    # `status` and `kind` are numbers on the row, and the key builder only
    # knew how to read strings - so every row keyed as "" and the answer was
    # one bucket labelled with nothing.
    my %bystatus;
    for my $g (@{ $st->query('spans | by status | count')->{groups} }) {
        $bystatus{ $g->{key} } = $g->{value};
    }
    is($bystatus{2}, 3, 'a numeric column groups by its value');
    is($bystatus{0}, 7, '  on both sides of it');
    ok(!exists $bystatus{''}, '  and never under an empty key');

    # And on the log side, where the numeric column is severity.
    Punk::Observe::WAL::append($st->wal_path, [
        logline(t => _add($T0, 20_000_000), body => 'a', severity => 17,
                service => 'shop'),
        logline(t => _add($T0, 21_000_000), body => 'b', severity => 9,
                service => 'shop'),
        logline(t => _add($T0, 22_000_000), body => 'c', severity => 9,
                service => 'shop'),
    ], 0, 0);
    my %sev;
    for my $g (@{ $st->query('log | by severity | count')->{groups} }) {
        $sev{ $g->{key} } = $g->{value};
    }
    is($sev{17}, 1, 'severity groups by its number');
    is($sev{9},  2, '  on the twenty-four point scale, not by name');
}

done_testing();

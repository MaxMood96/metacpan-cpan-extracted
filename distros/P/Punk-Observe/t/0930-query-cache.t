#!perl
# The chunk cache: the settled part of a window, computed once.
#
# THE HEADLINE ASSERTION IS EQUIVALENCE. Everything else this does is an
# optimisation, and an optimisation that changes the answer is not one - so
# the cached result is compared against the plain one bucket by bucket, on a
# window where the plain query is complete enough to be the reference.
#
# The property it rests on: a bucket is computed from the records inside it
# and nothing else, and bucket indices are ABSOLUTE (t / bucket_ns), not an
# offset from the query's start. That is asserted here directly rather than
# assumed, because every other claim in this file follows from it.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);

BEGIN {
    eval { require Punk::Cache; 1 }
        or plan skip_all => 'Punk::Cache not installed';
}
use Punk::Observe;
use Punk::Observe::Store;
use Punk::Observe::WAL;
use Punk::Observe::Cache;

my $C = 'Punk::Observe::Cache';

# --- what may be split ------------------------------------------------------

{
    is($C->can('bucket_ns')->('spans | bucket(30m) count'), 1800 * 1e9,
       'a bucketed query reports its width');
    is($C->can('bucket_ns')->('metric m | rate(5m) by service'), 300 * 1e9,
       'so does a rate, which is bucketed too');
    is($C->can('bucket_ns')->('log | count'), undef,
       'an unbucketed query cannot be split');
    is($C->can('bucket_ns')->('not a query at all'), undef,
       'nor can one that will not parse');

    # A STAGE THAT RANKS ROWS AGAINST EACH OTHER CANNOT BE SPLIT: the top five
    # of each half is not the top five of the whole. Refusing to chunk is the
    # only correct answer, and it must not depend on the bucket being absent.
    for my $stage ('| limit 5', '| top 5 by count', '| slowest 5',
                   '| sort service') {
        is($C->can('bucket_ns')->("spans | bucket(30m) count $stage"), undef,
           "`$stage` turns chunking off, even with a bucket present");
    }
    # The cross-signal stages re-key against a set gathered across the whole
    # pipeline, so a chunk of one is not a chunk of the answer.
    for my $stage ('| exemplars', '| exemplars | traces', '| exemplars | logs') {
        is($C->can('bucket_ns')->("metric m | bucket(5m) count $stage"), undef,
           "`$stage` turns chunking off");
    }
}

# --- a chunk is a whole number of buckets -----------------------------------
#
# Or a bucket is split across two cache entries and each half is a count of
# part of it - which renders as a real dip in the chart at every chunk edge.

{
    for my $b (map { $_ * 1e9 } 30, 60, 300, 1800, 3600, 21600) {
        my $c = $C->can('chunk_ns')->($b);
        is($c % $b, 0, "a chunk for a ${\ ($b/1e9) }s bucket is whole buckets");
        cmp_ok($c, '>=', $b, '  and never smaller than one');
    }
}

# --- the store, and the equivalence -----------------------------------------

my $dir   = tempdir(CLEANUP => 1);
my $store = Punk::Observe::Store->new(dir => $dir);
my $cache = Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                             max_bytes => '64M');

# Six hours of spans, one a minute, alternating service so there are two
# series to merge rather than one.
my $B    = 1800 * 1_000_000_000;                  # 30m buckets
my $BASE = '1774224000000000000';                 # already a bucket edge
my $to   = Punk::Observe::Store::nadd($BASE, 12 * $B);   # six hours on

{
    my @recs;
    for my $m (0 .. 359) {
        push @recs, {
            kind => 3, t => Punk::Observe::Store::nadd($BASE, $m * 60_000_000_000),
            body => 'GET /', duration => 1_000_000, severity => 0,
            span_kind => 2, status => 0, trace_hi => 1, trace_lo => $m,
            span_id => $m, parent_id => 0,
            attrs => { 'service.name' => ($m % 2 ? 'cards' : 'shop') } };
    }
    ok(Punk::Observe::WAL::append($store->wal_path, \@recs, 0, 0)->{ok},
       'the fixture reaches the log');
    ok($store->seal, '  and seals');
}

my $Q = 'spans | bucket(30m) count by service';

# Flatten to series|instant => value, which is the only thing a chart draws.
sub flat {
    my ($r) = @_;
    my %h;
    for my $s (@{ $r->{series} || [] }) {
        $h{ ($s->{key} // '') . '|' . $_->[0] } = $_->[1]
            for @{ $s->{points} || [] };
    }
    return \%h;
}

# `now` is injected far past the window so every chunk has settled - the lag
# is about live data, and this fixture is all history.
my $NOW = Punk::Observe::Store::nadd($to, 86_400 * 1_000_000_000);

{
    my $plain = $store->query($Q, from => $BASE, to => $to);
    ok($plain->{ok}, 'the plain query answers') or diag $plain->{error};
    ok(!$plain->{meta}{truncated},
       '  completely, so it is a fair reference');

    my $cold = $C->can('query')->($store, $Q, from => $BASE, to => $to,
                                  cache => $cache, now => $NOW);
    my $warm = $C->can('query')->($store, $Q, from => $BASE, to => $to,
                                  cache => $cache, now => $NOW);

    is_deeply(flat($cold), flat($plain),
              'THE CACHED ANSWER IS THE PLAIN ANSWER, bucket for bucket');
    is_deeply(flat($warm), flat($cold),
              '  and a second call agrees with the first');
    ok($cold->{cached_chunks} > 1, '  over more than one chunk');
    is($cold->{shape}, 'buckets', '  keeping the shape a chart can draw');

    # Both series survive the merge. Merging on instant alone would collapse
    # them into one line whose values are whichever series was seen last.
    my %keys = map { ($_->{key} // '') => 1 } @{ $cold->{series} };
    is_deeply([ sort keys %keys ], [ 'cards', 'shop' ],
              '  with every series kept apart');
}

# --- the cache is actually used ---------------------------------------------
#
# Equivalence is worth nothing if it was achieved by never reading the cache.
# A store that refuses to answer proves the settled chunks came from the
# cache: the only part that still needs the store is the live tail, which is
# empty here.

{
    my $fresh = Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                                 max_bytes => '64M');
    my $want = flat($C->can('query')->($store, $Q, from => $BASE, to => $to,
                                       cache => $fresh, now => $NOW));

    my $blocked = Blocked::Store->new($store);
    my $second = $C->can('query')->($blocked, $Q, from => $BASE, to => $to,
                                    cache => $fresh, now => $NOW);
    is_deeply(flat($second), $want,
              'the settled chunks come back with the store refusing to scan');
    ok($blocked->{calls} <= 1,
       '  which is one call for the live tail and no more')
        or diag "store was asked $blocked->{calls} times";
}

# --- the live tail is never cached ------------------------------------------
#
# Telemetry arrives late, so a bucket that has only just closed can still
# gain records. Freezing it would show a number that was about to change.

{
    my $fresh = Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                                 max_bytes => '64M');
    # `now` inside the window: everything after now-lag must be recomputed.
    my $mid = Punk::Observe::Store::nadd($BASE, 6 * $B);
    my $a = $C->can('query')->($store, $Q, from => $BASE, to => $to,
                               cache => $fresh, now => $mid);

    # More data arrives in the tail, and the answer has to change.
    my @late;
    for my $i (0 .. 9) {
        push @late, {
            kind => 3, t => Punk::Observe::Store::nadd($mid, $i * 1_000_000),
            body => 'late', duration => 1, severity => 0, span_kind => 2,
            status => 0, trace_hi => 2, trace_lo => $i, span_id => $i,
            parent_id => 0, attrs => { 'service.name' => 'shop' } };
    }
    Punk::Observe::WAL::append($store->wal_path, \@late, 0, 0);
    $store->seal;

    my $b = $C->can('query')->($store, $Q, from => $BASE, to => $to,
                               cache => $fresh, now => $mid);
    isnt(flat($a)->{ 'shop|' . Punk::Observe::Store::nfloor($mid, $B) },
         flat($b)->{ 'shop|' . Punk::Observe::Store::nfloor($mid, $B) },
         'a bucket in the live tail picks up records that arrived after the '
       . 'first call - it is never served from the cache');
}

# --- degrading is never failing ---------------------------------------------

{
    my $plain = flat($store->query($Q, from => $BASE, to => $to));

    is_deeply(flat($C->can('query')->($store, $Q, from => $BASE, to => $to)),
              $plain, 'with no cache at all the answer is the plain one');

    # A cache that throws on every call is a slow query, not a broken panel.
    my $broken = Broken::Cache->new;
    is_deeply(flat($C->can('query')->($store, $Q, from => $BASE, to => $to,
                                      cache => $broken, now => $NOW)),
              $plain, 'a cache that dies on every call still answers');

    # An unsplittable query goes through whole, cache or no cache.
    my $unsplit = 'spans | bucket(30m) count by service | limit 3';
    my $u = $C->can('query')->($store, $unsplit, from => $BASE, to => $to,
                               cache => $cache, now => $NOW);
    is_deeply(flat($u), flat($store->query($unsplit, from => $BASE, to => $to)),
              'a query that cannot be split is run whole');
    ok(!exists $u->{cached_chunks}, '  and says so by not reporting chunks');
}

# --- cached_query is the seam the renderer calls ----------------------------

{
    my $s2 = Punk::Observe::Store->new(dir => $dir);
    is_deeply(flat($s2->cached_query($Q, from => $BASE, to => $to)),
              flat($s2->query($Q, from => $BASE, to => $to)),
              'cached_query with no cache configured is query');

    # A FRESH cache, deliberately. The shared one above holds chunks from
    # before the late-data block wrote into an already-settled chunk, and
    # serving those is the documented limitation rather than a disagreement:
    # a chunk cached once does not learn about records backfilled into it
    # until its entry expires. Reusing it here would assert a guarantee this
    # does not make.
    my $s3 = Punk::Observe::Store->new(dir => $dir,
        cache => Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                                  max_bytes => '64M'));
    is_deeply(flat($s3->cached_query($Q, from => $BASE, to => $to)),
              flat($s3->query($Q, from => $BASE, to => $to)),
              '  and with one it is still the same answer');

    # And that limitation itself, asserted rather than left as prose: a chunk
    # already cached keeps its answer when records are backfilled into it.
    my $stale = Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                                 max_bytes => '64M');
    my $before = flat($C->can('query')->($store, $Q, from => $BASE, to => $to,
                                         cache => $stale, now => $NOW));
    Punk::Observe::WAL::append($store->wal_path, [ {
        kind => 3, t => Punk::Observe::Store::nadd($BASE, 60_000_000_000),
        body => 'backfilled', duration => 1, severity => 0, span_kind => 2,
        status => 0, trace_hi => 3, trace_lo => 1, span_id => 1,
        parent_id => 0, attrs => { 'service.name' => 'shop' } } ], 0, 0);
    $store->seal;
    is_deeply(flat($C->can('query')->($store, $Q, from => $BASE, to => $to,
                                      cache => $stale, now => $NOW)),
              $before,
              'a settled chunk does not learn about a record backfilled into '
            . 'it - the limitation the TTL bounds, not a disagreement');
}

done_testing();

# A store that answers once and then refuses. Proves a result came from the
# cache rather than from a scan nobody noticed.
{
    package Blocked::Store;
    sub new { my ($c, $real) = @_; bless { real => $real, calls => 0 }, $c }
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
    package Broken::Cache;
    sub new { bless {}, shift }
    sub compute { die "Broken::Cache: no\n" }
    sub get { die "Broken::Cache: no\n" }
    sub set { die "Broken::Cache: no\n" }
}

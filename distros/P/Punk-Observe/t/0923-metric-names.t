#!perl
# metric_names: the metrics landing page's question - which names exist in
# this window, how often - answered during the scan, with no record hash
# built per point.
#
# The reference implementation is the records() derivation it replaced, so
# the first assertion IS that derivation, element for element. Any tally
# mutant - wrong kind, wrong field, dropped count - diverges from it.
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

my $S  = 'Punk::Observe::Store';
my $T0 = '1774224000000000000';

sub nadd {
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

sub metric {
    my ($name, $t) = @_;
    return { kind => 1, t => $t || $T0, body => $name, severity => 0,
             duration => 0, value => 1, trace_hi => 0, trace_lo => 0,
             span_id => 0, parent_id => 0,
             attrs => { 'service.name' => 'svc' } };
}
sub logline {
    my ($t) = @_;
    return { kind => 2, t => $t || $T0, body => 'not a metric name',
             severity => 9, duration => 0, trace_hi => 0, trace_lo => 0,
             span_id => 0, parent_id => 0,
             attrs => { 'service.name' => 'svc' } };
}

my $dir   = tempdir(CLEANUP => 1);
my $store = $S->new(dir => $dir, tenant => 'acme');
my $wdir  = File::Spec->catdir($dir, 'acme', 'wal');

# Segment 0: metrics, two names with different counts, plus a log whose BODY
# must never be tallied, plus a STRADDLER - a point past the window's end in
# a segment whose span overlaps it, so only the record-level time filter can
# exclude it. Without the straddler, every out-of-window point sat in a
# segment the span skip already prunes, and the mutant that drops the
# record-level filter survived - the one-branch hole, again.
# Segment 1: logs only - prunable by kind. Segment 2: metrics far outside
# the window - prunable by span. Live wal: one more point of an existing
# name.
Punk::Observe::WAL::append($store->wal_path,
    [ metric('http.server.duration'), metric('http.server.duration'),
      metric('queue.depth'), logline(),
      metric('straddler', nadd($T0, 70_000_000_000)) ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path, [ logline() ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ metric('old.metric', nadd($T0, 900_000_000_000)) ], 0, 0);
$store->seal;
Punk::Observe::WAL::append($store->wal_path,
    [ metric('http.server.duration') ], 0, 0);
utime(time - 60, time - 60, $wdir) or die "utime: $!";

my ($FROM, $TO) = ($T0, nadd($T0, 60_000_000_000));

# --- equality with the records() derivation ----------------------------------
{
    my ($names, $meta) = $store->metric_names(from => $FROM, to => $TO);

    my ($recs) = $store->records(from => $FROM, to => $TO, kind => 1);
    my %derived;
    $derived{ $_->{body} }++ for @$recs;

    is_deeply($names, \%derived,
              'metric_names IS the records(kind=>1) derivation');
    is($names->{'http.server.duration'}, 3,
       '  counts cross the seal boundary into the live log');
    is($names->{'queue.depth'}, 1, '  and count per point');
    ok(!exists $names->{'not a metric name'},
       'a log body is never tallied as a metric name');
    ok(!exists $names->{'old.metric'}, 'the out-of-window name is absent');
    ok(!exists $names->{straddler},
       'a point past the window in an overlapping segment is absent too');

    # The pruning happened, and the metadata proves it: the logs-only
    # segment and the out-of-window segment were never opened.
    is($meta->{skipped}, 2, 'two segments pruned');
    is($meta->{files}, 2, '  two read (one sealed, one live)');
    is($meta->{truncated}, 0, 'nothing was cut');
    is($meta->{scanned}, 4, 'four points tallied');
}

# --- the cap says so ---------------------------------------------------------
{
    my $capped = $S->new(dir => $dir, tenant => 'acme', max_rows => 2);
    my ($names, $meta) = $capped->metric_names(from => $FROM, to => $TO);
    is($meta->{truncated}, 1, 'a capped tally admits it stopped');
    cmp_ok($meta->{scanned}, '<=', 4, '  short of the full four');
}

done_testing();

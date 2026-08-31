#!perl
# The chunk cache and the caller's row budget.
#
# SPLITTING A WINDOW MUST NOT NARROW THE ANSWER. A panel asks for no row
# ceiling, because an aggregate that stops mid-window draws some other window
# and labels it with this one. When the split dropped those options and ran
# every chunk at the store's own default, a busy hour truncated at that default
# and the panel reported the sum of a dozen capped scans as though it were a
# figure somebody had chosen - which is how a cache turned a complete graph
# into a partial one.
#
# So: what the caller passed reaches every chunk, and a chunk that truncated
# anyway is never stored.
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
use Punk::Observe::Health ();

my $C = 'Punk::Observe::Cache';

# --- the fixture ------------------------------------------------------------
#
# Six hours of spans at one a minute: sixty to a one-hour chunk, so a ceiling
# below sixty truncates inside every chunk rather than only in one of them.

my $dir  = tempdir(CLEANUP => 1);
my $B    = 1800 * 1_000_000_000;                  # 30m buckets
my $BASE = '1774224000000000000';                 # already a bucket edge
my $to   = Punk::Observe::Store::nadd($BASE, 12 * $B);
my $NOW  = Punk::Observe::Store::nadd($to, 86_400 * 1_000_000_000);
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

sub flat {
    my ($r) = @_;
    my %h;
    for my $s (@{ $r->{series} || [] }) {
        $h{ ($s->{key} // '') . '|' . $_->[0] } = $_->[1]
            for @{ $s->{points} || [] };
    }
    return \%h;
}

sub fresh_cache {
    return Punk::Cache->new('file', dir => tempdir(CLEANUP => 1),
                            max_bytes => '64M');
}

# The ceiling a panel asks for, which is the spelling of "no ceiling".
my $NONE = 1 << 62;
my %UNCAPPED = (limit => $NONE, hard_max => $NONE, max_rows => $NONE);

# --- the reference: a low ceiling really does truncate ----------------------
#
# Without this the rest proves nothing - a budget that was never binding
# cannot demonstrate having been carried.

my $tight = Punk::Observe::Store->new(dir => $dir, max_rows => 50);
my $whole = Punk::Observe::Store->new(dir => $dir);

{
    my $capped = $tight->query($Q, from => $BASE, to => $to);
    ok($capped->{meta}{truncated},
       'a store ceiling of fifty rows truncates this fixture');

    my $full = $tight->query($Q, from => $BASE, to => $to, %UNCAPPED);
    ok(!$full->{meta}{truncated},
       '  and asking for no ceiling lifts it on the plain path');
    is_deeply(flat($full), flat($whole->query($Q, from => $BASE, to => $to)),
              '  giving the answer an unbounded store gives');
}

# --- the budget travels through the split -----------------------------------

{
    my $cached = $C->can('query')->($tight, $Q, from => $BASE, to => $to,
                                    cache => fresh_cache(), now => $NOW,
                                    %UNCAPPED);
    ok(!$cached->{meta}{truncated},
       'A CHUNKED PANEL QUERY IS NOT PARTIAL: the no-ceiling request reaches '
     . 'every chunk');
    is_deeply(flat($cached), flat($whole->query($Q, from => $BASE, to => $to)),
              '  and the answer is the complete one, bucket for bucket');
    ok($cached->{cached_chunks} > 1, '  over more than one chunk');
}

# --- what each chunk was actually asked ------------------------------------

{
    my $rec = Recording::Store->new($tight);
    $C->can('query')->($rec, $Q, from => $BASE, to => $to,
                       cache => fresh_cache(), now => $NOW, %UNCAPPED);

    ok(@{ $rec->{calls} } > 1, 'the split asked the store once per chunk');
    my $bad = 0;
    for my $o (@{ $rec->{calls} }) {
        $bad++ unless ($o->{limit} || 0) == $NONE
                   && ($o->{hard_max} || 0) == $NONE
                   && ($o->{max_rows} || 0) == $NONE;
    }
    is($bad, 0, '  each carrying the budget the caller passed');

    # The window is the one thing the split owns. A chunk given the caller's
    # own from/to would scan the whole range once per chunk.
    my %windows = map { ($_->{from} // '') . '-' . ($_->{to} // '') => 1 }
                  @{ $rec->{calls} };
    ok(scalar(keys %windows) == scalar @{ $rec->{calls} },
       '  and its own window, not the caller`s repeated');

    # The cache controls describe the cache, and a store has no use for them.
    my $leaked = grep { exists $_->{cache} || exists $_->{now}
                     || exists $_->{ttl} || exists $_->{lag_ns} }
                 @{ $rec->{calls} };
    is($leaked, 0, '  with nothing of the cache`s own leaking into the scan');
}

# --- an option nobody here has heard of still arrives -----------------------
#
# The forwarding is a rule rather than a list of three names, so an option
# added to `query` tomorrow reaches a chunk without anybody editing this seam.

{
    my $rec = Recording::Store->new($tight);
    $C->can('query')->($rec, $Q, from => $BASE, to => $to,
                       cache => fresh_cache(), now => $NOW,
                       some_future_option => 'kept');
    my $seen = grep { ($_->{some_future_option} // '') eq 'kept' }
               @{ $rec->{calls} };
    is($seen, scalar @{ $rec->{calls} },
       'an option this seam does not know about reaches every chunk anyway');
}

# --- what ends up in the cache ----------------------------------------------
#
# Asserted against the entry itself rather than against a count of method
# calls: whether the bytes arrived through `set` or through `compute` is this
# seam's business, and whether they arrived at all is not.

# The key this seam builds, rebuilt here so the entry can be looked at. Proved
# below by finding something under it rather than assumed.
my $WIDTH = $C->can('chunk_ns')->($B);
my $KEY   = join("\0", 'po.chunk2', 'default',
                 Punk::Observe::Store::nfloor($BASE, $WIDTH), $WIDTH, $Q);

{
    my $ok = fresh_cache();
    $C->can('query')->($tight, $Q, from => $BASE, to => $to,
                       cache => $ok, now => $NOW, %UNCAPPED);
    my $stored = $ok->get($KEY);
    ok(defined $stored && length $stored, 'a complete chunk is stored');
    is(substr($stored // '', 0, 4), 'POC2',
       '  in the current format, under the key this seam builds');

    my $short = fresh_cache();
    my $r = $C->can('query')->($tight, $Q, from => $BASE, to => $to,
                               cache => $short, now => $NOW);
    ok($r->{meta}{truncated},
       'with the store ceiling left in place the chunks do truncate');
    is($short->get($KEY), undef,
       '  and nothing is written: a short answer stored is a short answer '
     . 'frozen for the life of the entry');
}

# --- entries from before the budget was carried are not read ----------------
#
# They may hold a count that stopped short, and a truncation flag that outlives
# the reason for it. The namespace moved with the format so they are never
# reached; a blob in the old format landing under the new namespace is refused
# rather than half-read.

{
    my $cache = fresh_cache();

    # Deliberately the OLD magic, with a body that is otherwise plausible.
    $cache->set($KEY, 'POC1' . ("\0" x 32), 3600);

    my $r = $C->can('query')->($whole, $Q, from => $BASE, to => $to,
                               cache => $cache, now => $NOW);
    is_deeply(flat($r), flat($whole->query($Q, from => $BASE, to => $to)),
              'a blob in the superseded format is refused and the chunk '
            . 'recomputed, not half-read');
    is(substr($cache->get($KEY) // '', 0, 4), 'POC2',
       '  and the entry is replaced with one in the current format');
}

# --- the pool computes a cold chunk once ------------------------------------
#
# `get` and `set` leave a gap for every other worker to arrive in. `compute`
# does not: it locks beside the entry, so the workers that lose the race take
# the winner's answer rather than repeating a scan of the same day.

{
    my $counted = Counting::Store->new($whole);
    my $cache   = Locked::Cache->new(fresh_cache());
    $C->can('query')->($counted, $Q, from => $BASE, to => $to,
                       cache => $cache, now => $NOW);
    ok($cache->{computes} > 1,
       'a cold chunk is filled through compute, not through a bare set');
    is($cache->{sets}, 0, '  which is where the single-flight lives');

    # A cache without `compute` still gets its entries - a host may bring its
    # own, and needing the newer method to be cached at all would be a poor
    # trade.
    my $plain = Setting::Cache->new(fresh_cache());
    my $r = $C->can('query')->($whole, $Q, from => $BASE, to => $to,
                               cache => $plain, now => $NOW);
    is_deeply(flat($r), flat($whole->query($Q, from => $BASE, to => $to)),
              'a cache offering only get and set still answers correctly');
    ok($plain->{sets} > 1, '  and is still written to');
}

# --- an undefined window is not an option ----------------------------------
#
# `from => undef` means the caller did not bound the window. Forwarding it as
# an option would hand every chunk an explicit undef `from` and overrule the
# window the split had just worked out.

{
    my $rec = Recording::Store->new($whole);
    my $r = $C->can('query')->($rec, $Q, from => undef, to => $to,
                               cache => fresh_cache(), now => $NOW);
    ok($r->{ok}, 'an unbounded window answers');
    my $bad = grep { exists $_->{from} && !defined $_->{from} }
              @{ $rec->{calls} };
    is($bad, 0, '  without an undefined `from` reaching the store as an option');
}

# --- an aggregate the code wrote asks for no ceiling ------------------------
#
# THE SECOND REASON, which is not the obvious one. A chart that stops scanning
# mid-window is wrong, and that is reason enough - but a chunk that truncates
# is also never cached, so a figure left on the store's default has its busiest
# chunk rescanned on every single request, for ever. On a 10GB store exactly
# one chunk of twenty-four hit the 500,000 default, and the status page never
# got faster than its cold cost until these were passed.

{
    my $rec = Recording::Store->new($whole);
    Punk::Observe::Health::uptime_events(
        store => $rec, from => $BASE, to => $to);

    ok(@{ $rec->{calls} } >= 1, 'the uptime bands ask the store something');
    my $o = $rec->{calls}[0];
    for my $k (qw(limit hard_max max_rows)) {
        ok(defined $o->{$k} && $o->{$k} > 500_000,
           "  with $k above the store default, so the window is not cut short");
    }
}

done_testing();

# A store that remembers what it was asked, and answers.
{
    package Recording::Store;
    sub new { my ($c, $real) = @_; bless { real => $real, calls => [] }, $c }
    sub query {
        my ($self, $q, %opt) = @_;
        push @{ $self->{calls} }, \%opt;
        return $self->{real}->query($q, %opt);
    }
    sub AUTOLOAD {
        my $self = shift;
        our $AUTOLOAD;
        (my $m = $AUTOLOAD) =~ s/.*:://;
        return if $m eq 'DESTROY';
        return $self->{real}->$m(@_);
    }
}

# A store that only counts.
{
    package Counting::Store;
    sub new { my ($c, $real) = @_; bless { real => $real, calls => 0 }, $c }
    sub query { my $self = shift; $self->{calls}++; return $self->{real}->query(@_) }
    sub AUTOLOAD {
        my $self = shift;
        our $AUTOLOAD;
        (my $m = $AUTOLOAD) =~ s/.*:://;
        return if $m eq 'DESTROY';
        return $self->{real}->$m(@_);
    }
}

# A cache with the single-flight, counting which way an entry was written.
{
    package Locked::Cache;
    sub new { my ($c, $real) = @_;
              bless { real => $real, sets => 0, computes => 0 }, $c }
    sub get { my $self = shift; return $self->{real}->get(@_) }
    sub set { my $self = shift; $self->{sets}++; return $self->{real}->set(@_) }
    sub compute {
        my $self = shift;
        $self->{computes}++;
        return $self->{real}->compute(@_);
    }
}

# A cache from before `compute` existed. Deliberately has no such method, so
# `can` says no and the seam falls back.
{
    package Setting::Cache;
    sub new { my ($c, $real) = @_; bless { real => $real, sets => 0 }, $c }
    sub get { my $self = shift; return $self->{real}->get(@_) }
    sub set { my $self = shift; $self->{sets}++; return $self->{real}->set(@_) }
}

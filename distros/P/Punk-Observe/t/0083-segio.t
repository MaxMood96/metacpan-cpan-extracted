#!perl
# The join phases 5, 6 and 7 each deferred: their structures reach a disk.
#
# Metric chunks, log blocks and span arrays are written into one segment as
# regions, the segment is closed, reopened, and every signal read back out of
# the mapping.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Punk::Observe;

my $IO = 'Punk::Observe::SegIO';
my $S  = 'Punk::Observe::Segment';
my $dir = tempdir(CLEANUP => 1);
sub path { File::Spec->catfile($dir, $_[0]) }
sub slurp { open my $fh, '<', $_[0] or return ''; binmode $fh; local $/; <$fh> }

# --- all three signals in one segment --------------------------------------

my $spec = {
    metrics => [
        { series => '1001',
          points => [ map { ("" . (1_000_000_000 * $_), $_ * 1.5) } 1 .. 20 ] },
        { series => '1002',
          points => [ map { ("" . (1_000_000_000 * $_), 42) } 1 .. 10 ] },
    ],
    logs => [
        [ 'connection refused', 'retrying now', 'connection refused again' ],
        [ 'request completed', 'cache miss' ],
    ],
    spans => [
        { trace_hi => '7', trace_lo => '7', span_id => '1', parent => '0',
          start => '1000', end => '5000', service => 1 },
        { trace_hi => '7', trace_lo => '7', span_id => '2', parent => '1',
          start => '1100', end => '4000', service => 2 },
        { trace_hi => '8', trace_lo => '8', span_id => '3', parent => '0',
          start => '2000', end => '2500', service => 1 },
    ],
};

my $p = path('all.seg');
ok($IO->can('write_all')->($p, $spec), 'a segment with all three signals writes');
ok(-f $p, '  and exists on disk');

my $r = $IO->can('read_all')->($p);
ok($r, 'it reopens') or BAIL_OUT('cannot reopen the segment');
cmp_ok($r->{regions}, '>=', 4, 'it carries at least four regions');

# --- metrics round-trip -----------------------------------------------------

{
    ok($r->{metrics_ok}, 'the metric region parses');
    is(scalar @{ $r->{metrics} }, 2, 'two metric chunks');
    is("$r->{metrics}[0]{series}", '1001', '  the first series id survives');
    is($r->{metrics}[0]{count}, 20, '  with its 20 points');
    is($r->{metrics}[1]{count}, 10, '  and the second with 10');

    # The points themselves, through Gorilla, through a disk, back.
    my @pts = @{ $r->{metrics}[0]{points} };
    is(scalar @pts, 40, '20 points come back as 20 (t, v) pairs');
    is("$pts[0]", '1000000000', '  the first timestamp exact');
    is($pts[1], 1.5, '  the first value exact');
    is("$pts[38]", '20000000000', '  the last timestamp exact');
    is($pts[39], 30, '  and the last value');

    my @const = @{ $r->{metrics}[1]{points} };
    my $bad = grep { $const[$_ * 2 + 1] != 42 } 0 .. 9;
    is($bad, 0, 'a constant series comes back constant');
}

# --- logs round-trip --------------------------------------------------------

{
    ok($r->{logs_ok}, 'the log region parses');
    is(scalar @{ $r->{logs} }, 2, 'two log blocks');
    is_deeply($r->{logs}[0],
              [ 'connection refused', 'retrying now', 'connection refused again' ],
              '  the first block deflates back to its exact lines');
    is_deeply($r->{logs}[1], [ 'request completed', 'cache miss' ],
              '  and the second');
}

# --- spans round-trip -------------------------------------------------------

{
    ok($r->{spans_ok}, 'the span region parses');
    is(scalar @{ $r->{spans} }, 3, 'three spans');
    # Sorted at seal by (trace, start), so trace 7 comes before trace 8.
    is("$r->{spans}[0]{trace_hi}", '7', '  sorted by trace');
    is("$r->{spans}[0]{start}", '1000', '  then by start');
    is("$r->{spans}[1]{start}", '1100', '  within a trace');
    is("$r->{spans}[2]{trace_hi}", '8', '  the other trace last');
    is("$r->{spans}[0]{duration}", '4000', '  durations survive');
}

# The span array is read STRAIGHT OUT of the mapping, so it must be exactly
# the right size - that is the payoff for po_span being a flat struct.
{
    is(scalar @{ $r->{spans} }, 3,
       'the span array length is derived from the region size alone');
}

# --- trace summaries --------------------------------------------------------

{
    is(scalar @{ $r->{summaries} }, 2, 'two trace summaries, one per trace');
    my ($t7) = grep { "$_->{trace_hi}" eq '7' } @{ $r->{summaries} };
    is($t7->{spans}, 2, '  trace 7 has two spans');
    is("$t7->{duration}", '4000', '  and the ROOT duration, not the max span');
}

# --- the region table is extensible ----------------------------------------

# A reader that does not know a kind skips it rather than misreading it, which
# is the point of a table over fixed offsets.
{
    my $only_spans = path('spans-only.seg');
    ok($IO->can('write_all')->($only_spans, { spans => $spec->{spans} }),
       'a segment with only one signal writes');
    my $s = $IO->can('read_all')->($only_spans);
    is(scalar @{ $s->{spans} }, 3, '  and its spans read back');
    ok(!exists $s->{metrics}, '  with no metric region present');
    ok(!exists $s->{logs},    '  and no log region');
}

{
    my $empty = path('none.seg');
    ok($IO->can('write_all')->($empty, {}), 'a segment with no signal regions writes');
    my $s = $IO->can('read_all')->($empty);
    ok($s, '  and reopens');
    ok(!exists $s->{spans}, '  carrying no signal regions');
}

# --- corruption is still caught --------------------------------------------

# Adding regions must not weaken the whole-file guarantee.
{
    my $full = slurp($p);
    ok(defined $S->can('parse')->($full), 'the whole image parses');

    my $accepted = 0;
    for my $n (0 .. length($full) - 1) {
        $accepted++ if defined $S->can('parse')->(substr($full, 0, $n));
    }
    is($accepted, 0,
       'not one of ' . length($full) . ' truncations is accepted');
}

{
    # A byte flipped inside a REGION must fail the CRC, which means regions
    # are covered by it rather than merely appended after it.
    my $full = slurp($p);
    my $rgn_area = int(length($full) * 0.7);
    my $bad = $full;
    substr($bad, $rgn_area, 1) = chr(ord(substr($bad, $rgn_area, 1)) ^ 0xFF);
    ok(!defined $S->can('parse')->($bad),
       'a corrupted region byte is caught by the segment CRC');
}

# --- THE OVERFLOW REGRESSION ------------------------------------------------
#
# The first region table checked bounds as `off + len > file_len`, which
# OVERFLOWS in a uint64_t: a corrupt footer claiming an offset near 2^64 wraps
# the sum to something small, the check passes, and the read runs off the
# mapping. That is a SIGBUS, not an error return - and it crashed this very
# suite before the check was rewritten as a subtraction.
{
    my $full = slurp($p);
    my $foot = length($full) - 96;
    my $crashed = 0;
    # Corrupt each 8-byte offset field in the footer with a huge value.
    for my $off (4, 12, 20, 28, 36, 44, 56) {
        my $bad = $full;
        substr($bad, $foot + $off, 8) = pack('a8', "\xff" x 8);
        my $r = eval { $S->can('parse')->($bad) };
        $crashed++ unless defined $r || !$@;
        ok(!defined $r, "a footer offset of ~2^64 at +$off is refused");
    }
    is($crashed, 0, 'and none of them crashed the process');
}

done_testing();

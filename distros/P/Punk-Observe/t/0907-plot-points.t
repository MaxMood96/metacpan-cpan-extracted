#!perl
# How many points a line is drawn with, and which ones.
#
# A metric series in a six-hour window is six figures of points and the chart
# is 720 pixels wide. Sending all of them cost a three-megabyte page and a
# browser that stopped responding, and the fix is only a fix if the line still
# has the same SHAPE afterwards - a chart that drops the spike it exists to
# show is worse than a slow one.
use 5.010;
use strict;
use warnings;
use Test::More;

use Punk::Observe::View ();

my $T0 = '1787000000000000000';

# A series of `$n` points, flat at 1, with whatever extremes are asked for
# planted at known offsets.
sub series {
    my ($n, %spike) = @_;
    my @rows;
    for my $i (0 .. $n - 1) {
        push @rows, {
            t       => _ns($i),
            value   => (exists $spike{$i} ? $spike{$i} : 1),
            service => 'api',
        };
    }
    return \@rows;
}

# Nanosecond instants as strings: they do not fit a double, and a test that
# built them with arithmetic would be testing the wrong thing.
sub _ns { my ($i) = @_; return '17870000' . sprintf('%011d', $i * 1000) . '00'; }

sub trace_of {
    my ($rows) = @_;
    my $s = Punk::Observe::View::_rows_as_series($rows, {});
    return (undef, $s) unless $s->{figure} && @{ $s->{figure}{data} || [] };
    return ($s->{figure}{data}[0], $s);
}

# --- a small series is drawn exactly ----------------------------------------
{
    my ($d) = trace_of(series(100));
    is(scalar @{ $d->{x} }, 100, 'a series under the budget keeps every point');
    is(scalar @{ $d->{y} }, 100, '  with x and y the same length');
}

# --- a large one is bounded -------------------------------------------------
{
    my $n = 20_000;
    my ($d, $s) = trace_of(series($n, 9_000 => 999, 15_000 => -5));

    cmp_ok(scalar @{ $d->{x} }, '<=', 2002,
           'a large series is decimated to something a chart can draw');
    cmp_ok(scalar @{ $d->{x} }, '>', 100, '  but is still a line, not a summary');
    is(scalar @{ $d->{x} }, scalar @{ $d->{y} }, '  x and y stay in step');

    # THE EXTREMES SURVIVE. Taking every nth point would drop whichever spike
    # fell between two samples, so the chart that exists to show a spike would
    # be the one that hides it. Min and max per bucket cannot.
    my ($min, $max) = ($d->{y}[0], $d->{y}[0]);
    for my $v (@{ $d->{y} }) { $min = $v if $v < $min; $max = $v if $v > $max }
    is($max, 999, '  the spike is still on the line');
    is($min, -5,  '  and so is the dip');

    # A line that doubles back is not a line. x must be non-decreasing.
    my $ok = 1;
    for my $i (1 .. $#{ $d->{x} }) {
        $ok = 0, last if $d->{x}[$i] < $d->{x}[$i - 1];
    }
    ok($ok, '  and x never goes backwards');

    # It has to span the window it claims to, rather than starting at
    # whichever extreme the first bucket happened to hold.
    my ($full) = trace_of(series(3));       # same clock, known ends
    is($d->{x}[0], $full->{x}[0], '  the line starts where the data starts');
    my ($tail) = trace_of([ @{ series($n) }[ $n - 1 ] ]);
    is($d->{x}[-1], $tail->{x}[0], '  and ends where it ends');

    # The legend describes the SERIES, not the drawing: the point count is
    # what the store returned, because that is what the reader is asking about.
    is($s->{legend}[0]{points}, $n,
       'the legend reports the points the query found, not the ones drawn');
}

# --- the shape is preserved, not just the extremes --------------------------
#
# A ramp decimated by min/max should still read as a ramp: every kept point
# has to sit between its neighbours' values in the original.
{
    my @rows = map { { t => _ns($_), value => $_, service => 'api' } } 0 .. 19_999;
    my ($d) = trace_of(\@rows);
    my $monotonic = 1;
    for my $i (1 .. $#{ $d->{y} }) {
        $monotonic = 0, last if $d->{y}[$i] < $d->{y}[$i - 1];
    }
    ok($monotonic, 'a ramp is still a ramp after decimation');
    is($d->{y}[0], 0, '  from the first value');
    is($d->{y}[-1], 19_999, '  to the last');
}

# --- the points come back in time order -------------------------------------
#
# The store hands rows over in whatever order it read them, and the sort that
# fixes that used to be an insertion sort with a hash lookup inside the
# comparison: quadratic, on input whose order has nothing to do with the key,
# with the slowest possible comparison. On a real series it did not render
# slowly, it never returned.
#
# This checks the ORDER rather than the clock. A timing assertion would fail
# on a loaded smoker and pass on a fast one that had the bug.
{
    my $n = 5_000;
    my @rows = map { { t => _ns($_), value => $_, service => 'api' } } 0 .. $n - 1;

    for my $case (['reversed',  [ reverse @rows ]],
                  ['shuffled',  [ sort { ($a->{value} * 7919) % 104729
                                     <=> ($b->{value} * 7919) % 104729 } @rows ]]) {
        my ($name, $in) = @$case;
        my ($d) = trace_of($in);
        my $sorted = 1;
        for my $i (1 .. $#{ $d->{x} }) {
            $sorted = 0, last if $d->{x}[$i] < $d->{x}[$i - 1];
        }
        ok($sorted, "$name input comes back in time order");
        # And the value that travelled with each instant travelled with it:
        # sorting the x array alone would pass the check above and draw
        # nonsense.
        my $paired = 1;
        for my $i (0 .. $#{ $d->{y} } - 1) {
            $paired = 0, last if $d->{y}[$i] > $d->{y}[$i + 1];
        }
        ok($paired, "  with each value still beside its own instant");
    }
}

# --- exemplars are never dropped --------------------------------------------
#
# Each one is a link into a trace, so losing one removes a way into the data.
# There are a handful of them and six figures of line points; only the line is
# worth decimating.
{
    my @rows = map {
        my %r = (t => _ns($_), value => 1, service => 'api');
        if ($_ % 2_000 == 0) {
            $r{trace_hi} = '123'; $r{trace_lo} = "$_";
        }
        \%r;
    } 0 .. 19_999;

    my ($d, $s) = trace_of(\@rows);
    my ($ex) = grep { ($_->{mode} || '') eq 'markers' } @{ $s->{figure}{data} };
    ok($ex, 'the exemplars are their own trace');
    is(scalar @{ $ex->{x} }, 10, '  and every one of them is on it');
    is($s->{legend}[0]{exemplars}, 10, '  and counted in the legend');
}



# --- a window with one bucket in it still draws the window ------------------
#
# THE FAILURE WAS A CHART THAT RENDERED NOTHING, and the reason it rendered
# nothing was not the data. A window whose traffic all lands in one bucket
# gives a series of ONE POINT; a one-point line is a moveto with nothing after
# it, so the panel drew an empty box. Plotly then had no range to work with
# and auto-scaled the time axis to that single instant, so a panel titled "the
# last hour" showed a millisecond either side of it.
#
# This is the state a freshly started receiver is in for its first minute,
# which is exactly when somebody is looking at the page to see whether it
# works.
{
    require Punk::Observe;
    require Punk::Observe::Store;
    require Punk::Observe::Plot;
    require File::Temp;
    require File::Raw::JSON;

    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $store = Punk::Observe::Store->new(dir => $dir);
    my $now = Punk::Observe::now_ns();

    # Ten seconds of traffic, five seconds ago. One bucket of an hour.
    my @recs;
    for my $i (0 .. 9) {
        my $t = Punk::Observe::Store::nsub($now, 5_000_000_000 - $i * 100_000_000);
        push @recs,
            { t => $t, kind => 2, body => "l$i", severity => 9,
              attrs => { 'service.name' => 'api' } },
            { t => $t, kind => 3, body => "GET /$i", duration => 1_000_000,
              span_kind => 2, status => 0, trace_hi => 7, trace_lo => $i,
              span_id => $i + 1, parent_id => 0,
              attrs => { 'service.name' => 'api' } };
    }
    Punk::Observe::WAL::append($store->wal_path, \@recs, 1, '0');
    $store->seal;

    my $from = Punk::Observe::Store::nsub($now, 3_600 * 1_000_000_000);
    my $json = Punk::Observe::Plot::ingest_figure($store, $from, $now);
    ok($json, 'a one-bucket window still produces a figure');

    my $fig = File::Raw::JSON::file_json_decode($json);
    is(scalar @{ $fig->{data} }, 2, '  with both signals on it');

    my $r = $fig->{layout}{xaxis}{range};
    ok($r, 'the axis carries an explicit range');
    # The window that was ASKED for, not the extent of what came back.
    cmp_ok(($r->[1] - $r->[0]) / 60_000, '>', 59,
           '  spanning the hour the panel claims');
    cmp_ok(($r->[1] - $r->[0]) / 60_000, '<', 61, '  and not more');

    for my $t (@{ $fig->{data} }) {
        cmp_ok(scalar @{ $t->{x} }, '>', 2,
               "$t->{name}: more than two points, so a LINE is drawn");
        is(scalar(grep { $_ } @{ $t->{y} }), 1,
           "  and exactly one of them carries the traffic");
        cmp_ok($t->{x}[0], '>=', $r->[0], '  the first point is inside the axis');
        cmp_ok($t->{x}[-1], '<=', $r->[1], '  and so is the last');
    }
}

done_testing();

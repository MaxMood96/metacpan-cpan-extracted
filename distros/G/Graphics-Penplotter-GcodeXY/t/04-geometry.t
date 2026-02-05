#!/usr/bin/perl

use strict;
use warnings;
use Graphics::Penplotter::GcodeXY;
use Test::More;

# Helper to inspect last segment
sub last_segment_is {
    my ($g, $expected, $test_name) = @_;
    my @segs = $g->getsegpath();
    my $last = $segs[-1];
    if (!$last) {
        fail($test_name . " (no segments found)");
        return;
    }
    
    my $matches = 1;
    foreach my $k (keys %$expected) {
        # Float comparison with tolerance
        if ($expected->{$k} =~ /^[\d\.\-]+$/ && $last->{$k} =~ /^[\d\.\-]+$/) {
            if (abs($expected->{$k} - $last->{$k}) > 0.001) {
                $matches = 0;
                diag("Key '$k': expected $expected->{$k}, got $last->{$k}");
            }
        } elsif ($expected->{$k} ne $last->{$k}) {
            $matches = 0;
            diag("Key '$k': expected '$expected->{$k}', got '$last->{$k}'");
        }
    }
    ok($matches, $test_name);
}

my $g = Graphics::Penplotter::GcodeXY->new(
    papersize => 'A4',
    units     => 'in', # simple units
    check     => 0,
);

my @box_segs;

# 1. Line (absolute)
# line(x1, y1, x2, y2) -> moves to x1,y1 (fast), then lines to x2,y2 (slow)
$g->newpath();
$g->line(10, 10, 20, 20);
last_segment_is($g, { key => 'l', sx => 10, sy => 10, dx => 20, dy => 20 }, "line(10,10, 20,20) creates linear segment");

# 2. Line (relative)
# line(dx, dy) -> assumes current pos.
$g->moveto(50, 50);
$g->line(10, 10); # absolute to 10,10 from 50,50
last_segment_is($g, { key => 'l', sx => 50, sy => 50, dx => 10, dy => 10 }, "line(10,10) relative creates linear segment");

# 3. LineR (explicit relative)
$g->moveto(100, 100);
$g->lineR(5, 5); # -> 105, 105
last_segment_is($g, { key => 'l', sx => 100, sy => 100, dx => 105, dy => 105 }, "lineR(5,5) creates linear segment");

# 4. Box (rectangular polygon)
# box(x1, y1, x2, y2)
$g->newpath();
$g->box(0, 0, 10, 10);
# Should create 4 segments (polygon). Last one should return to start.
# polygon logic: moveto(0,0), line(0,0->10,0), line(10,0->10,10), line(10,10->0,10), line(0,10->0,0)
last_segment_is($g, { key => 'l', sx => 0, sy => 10, dx => 0, dy => 0 }, "box(0,0,10,10) closes path correctly");

# 5. BoxR
$g->newpath();
$g->moveto(10,10);
$g->boxR(10, 10); # box 10x10 relative to 10,10
last_segment_is($g, { key => 'l', sx => 10, sy => 20, dx => 10, dy => 10 }, "boxR creates closed path");

# 6. Polygon
$g->newpath();
$g->polygon(0,0, 10,0, 5,10); # Triangle
@box_segs = $g->getsegpath();
# moveto(0,0), line(0,0->10,0), line(10,0->5,10) -> Total 3 segments.
#is(scalar @box_segs, 3, "polygon(3 pts) creates 3 segments");
last_segment_is($g, { key => 'l', sx => 10, sy => 0, dx => 5, dy => 10 }, "last segment of polygon correct");

# 7. Circle
# circle(x, y, r)
$g->newpath();
$g->circle(100, 100, 50);
# Circle generates many small linear segments (approximated) because 'curve' ultimately calls polygon?
# Wait, 'curve' calls 'polygon' in the implementation if it's high order, but 'circle' usually calls '_a2c' -> 'curve'.
# 'curve' (cubic) calls '_curve4' -> '_recbezier4' -> 'polygon'.
# So yes, lots of 'l' segments.
my @circle_segs = $g->getsegpath();
cmp_ok(scalar @circle_segs, '>', 10, "circle creates many segments");
last_segment_is($g, { key => 'l' }, "circle consists of line segments");

# 8. Arc
$g->newpath();
$g->moveto(0,0);
# arc(x, y, r, start_ang, end_ang)
$g->arc(0, 0, 10, 0, 90);
my @arc_segs = $g->getsegpath();
cmp_ok(scalar @arc_segs, '>', 2, "arc creates segments");

# 9. Ellipse
$g->newpath();
$g->ellipse(50, 50, 20, 10);
my @ell_segs = $g->getsegpath();
cmp_ok(scalar @ell_segs, '>', 10, "ellipse creates segments");

# 10. Arrowhead
$g->newpath();
$g->line(0,0, 10,0); # Horizontal line to right
$g->arrowhead(2, 2, 'open');
# Arrowhead draws lines relative to last segment.
# Last segment was 0,0 -> 10,0. Angle 0.
# Arrowhead should draw lines at the tip (10,0).
last_segment_is($g, { key => 'l' }, "arrowhead adds lines");

done_testing();

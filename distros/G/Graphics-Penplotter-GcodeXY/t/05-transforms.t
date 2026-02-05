#!/usr/bin/perl

use strict;
use warnings;
use Graphics::Penplotter::GcodeXY;
use Test::More 'no_plan';
use Math::Trig;

my $g = Graphics::Penplotter::GcodeXY->new(
    papersize => 'A4',
    units     => 'pt',
    check     => 0,
);

# Helper to check point transformation
sub check_transform {
    my ($g, $x, $y, $ex, $ey, $name) = @_;
    # _u_to_p transforms user coords to paper coords using CTM
    my ($px, $py) = $g->_u_to_p($x, $y);
    my $ok = 1;
    if (abs($px - $ex) > 0.001) { $ok = 0; diag("X: got $px, expected $ex"); }
    if (abs($py - $ey) > 0.001) { $ok = 0; diag("Y: got $py, expected $ey"); }
    ok($ok, $name);
}

# 1. Identity
check_transform($g, 10, 20, 10, 20, "Identity transform");

# 2. Translation
$g->translate(100, 50);
# User (0,0) -> Paper (100, 50)
check_transform($g, 0, 0, 100, 50, "Translate(100,50)");
check_transform($g, 10, 10, 110, 60, "Translate preserves relative");

# 3. Accumulated Translation
$g->translate(10, 10);
check_transform($g, 0, 0, 110, 60, "Accumulated translate");

# Reset
$g->initmatrix();
check_transform($g, 10, 20, 10, 20, "Reset matrix");

# 4. Rotation
# rotate(90) -> x becomes -y, y becomes x (counter-clockwise)
$g->rotate(90);
# (10, 0) -> (0, 10)
check_transform($g, 10, 0, 0, 10, "Rotate 90deg");
# (0, 10) -> (-10, 0)
check_transform($g, 0, 10, -10, 0, "Rotate 90deg (2)");

# Reset
$g->initmatrix();

# 5. Scale
$g->scale(2, 0.5);
check_transform($g, 10, 20, 20, 10, "Scale(2, 0.5)");

# 6. GSave/GRestore
$g->gsave();
$g->translate(100, 100);
check_transform($g, 0, 0, 200, 50, "Inside gsave");
$g->grestore();
check_transform($g, 10, 20, 20, 10, "After grestore (reverted to scaled)");

# 7. SkewX
$g->initmatrix();
$g->skewX(45); # Skew X by Y. x' = x + y*tan(45). y' = y.
# (10, 10) -> (10 + 10*1, 10) = (20, 10)
check_transform($g, 10, 10, 20, 10, "SkewX 45deg");

# 8. TranslateC (Translate to current point)
$g->initmatrix();
$g->moveto(50, 50);
$g->translateC();
# Origin should now be at 50,50
check_transform($g, 0, 0, 50, 50, "TranslateC");

done_testing();

#!/usr/bin/perl

use strict;
use warnings;
use Graphics::Penplotter::GcodeXY;
use Test::More 'no_plan';
use File::Temp qw(tempfile);

my $g = Graphics::Penplotter::GcodeXY->new(
    papersize => 'A4',
    units     => 'pt',
);

# Draw something to export
$g->box(0,0, 100,100);

# 1. Export SVG
my ($fh_svg, $filename_svg) = tempfile(SUFFIX => '.svg', UNLINK => 1);
close $fh_svg;

eval { $g->exportsvg($filename_svg) };
is($@, '', "exportsvg does not die");
ok(-s $filename_svg > 0, "SVG file created and not empty");

# Verify content vaguely
open my $in, '<', $filename_svg or die $!;
my $content = do { local $/; <$in> };
close $in;
like($content, qr/<svg/, "SVG contains svg tag");
like($content, qr/path/, "SVG contains path tag");

# 2. Export EPS
my ($fh_eps, $filename_eps) = tempfile(SUFFIX => '.eps', UNLINK => 1);
close $fh_eps;
eval { $g->exporteps($filename_eps) };
is($@, '', "exporteps does not die");
# EPS check might be similar

done_testing();

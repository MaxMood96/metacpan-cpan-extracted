#!/usr/bin/perl

use strict;
use warnings;
use Graphics::Penplotter::GcodeXY;
use Test::More tests => 4;

my $g = Graphics::Penplotter::GcodeXY->new(
    papersize => 'A4',
    units     => 'px',
    optimize  => 1,
    opt_debug => 0,
);

# 1. Hatching Separation
eval { $g->sethatchsep(5) };
is($@, '', "sethatchsep does not die");
is($g->{hatchsep}, 5, "hatchsep value set correctly");

# 2. Optimization
# Create a sequence that should be optimized.
# Pattern 5: PU / PD -> Delete both.
# $g->penup(); $g->pendown();
# But `penup` checks penlocked. And adds to path.
$g->penup();
$g->pendown();
# Checking if optimization actually runs might be hard without inspecting output or hooking internals.
# But we can check that it doesn't crash during `_optimize` call (which happens implicitly or explicitly?).
# `output` calls `_optimize`. 
# Or we can call it manually? `sub _optimize` is internal but accessible.

my $res = eval { $g->_optimize() };
is($@, '', "_optimize runs without error");

# 3. AddFontPath
eval { $g->addfontpath('/tmp') };
is($@, '', "addfontpath does not die");

done_testing();

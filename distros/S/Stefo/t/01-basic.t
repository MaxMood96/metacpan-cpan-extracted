#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 20;

use Stefo;

# Test 1: Basic loading
ok(1, "Stefo module loaded");

# Test 2-6: Compile and check $_ > 0
{
    my $gt = Stefo::compile(sub { $_ > 0 });
    ok(defined $gt, "compiled \$_ > 0");
    ok(Stefo::is_optimized($gt), "sub was optimized");
    
    ok(Stefo::check($gt, 5), "5 > 0 is true");
    ok(!Stefo::check($gt, -5), "-5 > 0 is false");
    ok(!Stefo::check($gt, 0), "0 > 0 is false");
}

# Test 7-9: Less than
{
    my $lt = Stefo::compile(sub { $_ < 10 });
    ok(Stefo::is_optimized($lt), "\$_ < 10 optimized");
    ok(Stefo::check($lt, 5), "5 < 10 is true");
    ok(!Stefo::check($lt, 15), "15 < 10 is false");
}

# Test 10-11: Defined check
{
    my $def = Stefo::compile(sub { defined $_ });
    ok(Stefo::is_optimized($def), "defined \$_ optimized");
    ok(Stefo::check($def, "hello"), "defined 'hello' is true");
}

# Test 12-14: Negation
{
    my $not = Stefo::compile(sub { ! $_ });
    ok(Stefo::is_optimized($not), "! \$_ optimized");
    ok(Stefo::check($not, 0), "!0 is true");
    ok(!Stefo::check($not, 1), "!1 is false");
}

# Test 15-18: Combined AND
{
    my $range = Stefo::compile(sub { $_ > 0 && $_ < 100 });
    ok(Stefo::is_optimized($range), "\$_ > 0 && \$_ < 100 optimized");
    ok(Stefo::check($range, 50), "50 in range");
    ok(!Stefo::check($range, 150), "150 out of range");
    ok(!Stefo::check($range, -5), "-5 out of range");
}

# Test 19-20: Instruction count and fallback
{
    my $simple = Stefo::compile(sub { $_ > 0 });
    my $count = Stefo::instruction_count($simple);
    ok($count > 0, "instruction count: $count");
    ok($count <= 10, "reasonable instruction count for simple sub");
}

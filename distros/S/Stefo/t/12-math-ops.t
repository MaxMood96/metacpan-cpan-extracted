#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 56;

use Stefo;

# =============================================================================
# Division and Power
# =============================================================================

# Division (/)
{
    my $div = Stefo::compile(sub { $_ / 2 > 5 });
    ok(Stefo::is_optimized($div), "\$_ / 2 > 5 optimized");
    ok(Stefo::check($div, 12), "12 / 2 > 5");
    ok(Stefo::check($div, 100), "100 / 2 > 5");
    ok(!Stefo::check($div, 10), "10 / 2 == 5, not > 5");
    ok(!Stefo::check($div, 8), "8 / 2 < 5");
}

# Power (**)
{
    my $pow = Stefo::compile(sub { $_ ** 2 > 50 });
    ok(Stefo::is_optimized($pow), "\$_ ** 2 > 50 optimized");
    ok(Stefo::check($pow, 8), "8 ** 2 = 64 > 50");
    ok(Stefo::check($pow, 10), "10 ** 2 = 100 > 50");
    ok(!Stefo::check($pow, 7), "7 ** 2 = 49 < 50");
    ok(!Stefo::check($pow, 5), "5 ** 2 = 25 < 50");
}

# Negation (unary -)
{
    my $neg = Stefo::compile(sub { -$_ > 0 });
    ok(Stefo::is_optimized($neg), "-\$_ > 0 optimized");
    ok(Stefo::check($neg, -5), "-(-5) = 5 > 0");
    ok(Stefo::check($neg, -100), "-(-100) = 100 > 0");
    ok(!Stefo::check($neg, 5), "-(5) = -5 < 0");
    ok(!Stefo::check($neg, 0), "-(0) = 0, not > 0");
}

# =============================================================================
# Math Functions
# =============================================================================

# sqrt()
{
    my $sqrt = Stefo::compile(sub { sqrt($_) > 5 });
    ok(Stefo::is_optimized($sqrt), "sqrt(\$_) > 5 optimized");
    ok(Stefo::check($sqrt, 36), "sqrt(36) = 6 > 5");
    ok(Stefo::check($sqrt, 100), "sqrt(100) = 10 > 5");
    ok(!Stefo::check($sqrt, 25), "sqrt(25) = 5, not > 5");
    ok(!Stefo::check($sqrt, 16), "sqrt(16) = 4 < 5");
}

# sin()
{
    my $sin = Stefo::compile(sub { sin($_) > 0 });
    ok(Stefo::is_optimized($sin), "sin(\$_) > 0 optimized");
    ok(Stefo::check($sin, 1), "sin(1) > 0");
    ok(Stefo::check($sin, 3), "sin(3) > 0");
    ok(!Stefo::check($sin, 0), "sin(0) = 0, not > 0");
    ok(!Stefo::check($sin, -1), "sin(-1) < 0");
}

# cos()
{
    my $cos = Stefo::compile(sub { cos($_) > 0 });
    ok(Stefo::is_optimized($cos), "cos(\$_) > 0 optimized");
    ok(Stefo::check($cos, 0), "cos(0) = 1 > 0");
    ok(Stefo::check($cos, 1), "cos(1) > 0");
    ok(!Stefo::check($cos, 3.14159), "cos(pi) ~ -1 < 0");
}

# exp()
{
    my $exp = Stefo::compile(sub { exp($_) > 10 });
    ok(Stefo::is_optimized($exp), "exp(\$_) > 10 optimized");
    ok(Stefo::check($exp, 3), "exp(3) ~ 20 > 10");
    ok(Stefo::check($exp, 5), "exp(5) > 10");
    ok(!Stefo::check($exp, 2), "exp(2) ~ 7 < 10");
    ok(!Stefo::check($exp, 0), "exp(0) = 1 < 10");
}

# log()
{
    my $log = Stefo::compile(sub { log($_) > 2 });
    ok(Stefo::is_optimized($log), "log(\$_) > 2 optimized");
    ok(Stefo::check($log, 10), "log(10) ~ 2.3 > 2");
    ok(Stefo::check($log, 100), "log(100) > 2");
    ok(!Stefo::check($log, 7), "log(7) ~ 1.9 < 2");
    ok(!Stefo::check($log, 1), "log(1) = 0 < 2");
}

# =============================================================================
# Conversion Functions
# =============================================================================

# ord() - character to ASCII
{
    my $ord = Stefo::compile(sub { ord($_) > 90 });
    ok(Stefo::is_optimized($ord), "ord(\$_) > 90 optimized");
    ok(Stefo::check($ord, 'a'), "ord('a') = 97 > 90");
    ok(Stefo::check($ord, 'z'), "ord('z') = 122 > 90");
    ok(!Stefo::check($ord, 'A'), "ord('A') = 65 < 90");
    ok(!Stefo::check($ord, 'Z'), "ord('Z') = 90, not > 90");
}

# chr() - ASCII to character
{
    my $chr = Stefo::compile(sub { chr($_) eq 'A' });
    ok(Stefo::is_optimized($chr), "chr(\$_) eq 'A' optimized");
    ok(Stefo::check($chr, 65), "chr(65) eq 'A'");
    ok(!Stefo::check($chr, 66), "chr(66) ne 'A'");
    ok(!Stefo::check($chr, 97), "chr(97) = 'a' ne 'A'");
}

# hex() - hex string to number
{
    my $hex = Stefo::compile(sub { hex($_) > 200 });
    ok(Stefo::is_optimized($hex), "hex(\$_) > 200 optimized");
    ok(Stefo::check($hex, 'ff'), "hex('ff') = 255 > 200");
    ok(Stefo::check($hex, '100'), "hex('100') = 256 > 200");
    ok(!Stefo::check($hex, '64'), "hex('64') = 100 < 200");
}

# oct() - octal string to number
{
    my $oct = Stefo::compile(sub { oct($_) > 50 });
    ok(Stefo::is_optimized($oct), "oct(\$_) > 50 optimized");
    ok(Stefo::check($oct, '100'), "oct('100') = 64 > 50");
    ok(Stefo::check($oct, '777'), "oct('777') = 511 > 50");
    ok(!Stefo::check($oct, '50'), "oct('50') = 40 < 50");
}

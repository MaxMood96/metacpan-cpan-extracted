#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 39;

use Stefo;

# =============================================================================
# Bitwise Operations
# =============================================================================

# Bitwise AND (&)
{
    my $band = Stefo::compile(sub { ($_ & 0x0F) == 0x0F });
    ok(Stefo::is_optimized($band), "(\$_ & 0x0F) == 0x0F optimized");
    ok(Stefo::check($band, 0xFF), "0xFF & 0x0F == 0x0F");
    ok(Stefo::check($band, 0x1F), "0x1F & 0x0F == 0x0F");
    ok(!Stefo::check($band, 0xF0), "0xF0 & 0x0F == 0x00");
    ok(!Stefo::check($band, 0x0E), "0x0E & 0x0F == 0x0E");
}

# Bitwise AND for flag checking
{
    my $flag = Stefo::compile(sub { $_ & 4 });
    ok(Stefo::is_optimized($flag), "\$_ & 4 optimized");
    ok(Stefo::check($flag, 7), "7 & 4 is truthy");
    ok(Stefo::check($flag, 4), "4 & 4 is truthy");
    ok(Stefo::check($flag, 5), "5 & 4 is truthy");
    ok(!Stefo::check($flag, 3), "3 & 4 is falsy");
    ok(!Stefo::check($flag, 0), "0 & 4 is falsy");
}

# Bitwise OR (|)
{
    my $bor = Stefo::compile(sub { ($_ | 0x0F) == 0xFF });
    ok(Stefo::is_optimized($bor), "(\$_ | 0x0F) == 0xFF optimized");
    ok(Stefo::check($bor, 0xF0), "0xF0 | 0x0F == 0xFF");
    ok(Stefo::check($bor, 0xFF), "0xFF | 0x0F == 0xFF");
    ok(!Stefo::check($bor, 0x00), "0x00 | 0x0F == 0x0F");
    ok(!Stefo::check($bor, 0xE0), "0xE0 | 0x0F == 0xEF");
}

# Bitwise XOR (^)
{
    my $bxor = Stefo::compile(sub { ($_ ^ 0xFF) == 0 });
    ok(Stefo::is_optimized($bxor), "(\$_ ^ 0xFF) == 0 optimized");
    ok(Stefo::check($bxor, 0xFF), "0xFF ^ 0xFF == 0");
    ok(!Stefo::check($bxor, 0x00), "0x00 ^ 0xFF == 0xFF");
    ok(!Stefo::check($bxor, 0xF0), "0xF0 ^ 0xFF == 0x0F");
}

# Bitwise complement (~)
{
    my $comp = Stefo::compile(sub { (~$_ & 0xFF) == 0xF0 });
    ok(Stefo::is_optimized($comp), "(~\$_ & 0xFF) == 0xF0 optimized");
    ok(Stefo::check($comp, 0x0F), "~0x0F & 0xFF == 0xF0");
    ok(!Stefo::check($comp, 0xFF), "~0xFF & 0xFF == 0x00");
}

# Left shift (<<)
{
    my $lshift = Stefo::compile(sub { ($_ << 2) == 16 });
    ok(Stefo::is_optimized($lshift), "(\$_ << 2) == 16 optimized");
    ok(Stefo::check($lshift, 4), "4 << 2 == 16");
    ok(!Stefo::check($lshift, 3), "3 << 2 == 12");
    ok(!Stefo::check($lshift, 5), "5 << 2 == 20");
}

# Right shift (>>)
{
    my $rshift = Stefo::compile(sub { ($_ >> 2) == 4 });
    ok(Stefo::is_optimized($rshift), "(\$_ >> 2) == 4 optimized");
    ok(Stefo::check($rshift, 16), "16 >> 2 == 4");
    ok(Stefo::check($rshift, 17), "17 >> 2 == 4");
    ok(Stefo::check($rshift, 19), "19 >> 2 == 4");
    ok(!Stefo::check($rshift, 8), "8 >> 2 == 2");
    ok(!Stefo::check($rshift, 32), "32 >> 2 == 8");
}

# =============================================================================
# Ternary/Conditional Expression
# =============================================================================

# Ternary operator
{
    my $tern = Stefo::compile(sub { $_ > 10 ? 1 : 0 });
    ok(Stefo::is_optimized($tern), "\$_ > 10 ? 1 : 0 optimized");
    ok(Stefo::check($tern, 15), "15 > 10 ? 1 : 0 is truthy");
    ok(!Stefo::check($tern, 5), "5 > 10 ? 1 : 0 is falsy");
}

# Defined-or (//)
{
    my $dor = Stefo::compile(sub { defined($_) // 0 });
    ok(Stefo::is_optimized($dor), "defined(\$_) // 0 optimized");
    ok(Stefo::check($dor, 'hello'), "defined 'hello' // 0 is truthy");
    ok(Stefo::check($dor, 0), "defined 0 // 0 is truthy (0 is defined)");
}

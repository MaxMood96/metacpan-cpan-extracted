#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

use_ok('Stefo');

# Test new optree patterns

# --- String Case Operations ---
{
    my $uc = Stefo::compile(sub { uc($_) eq 'HELLO' });
    ok(Stefo::is_optimized($uc), "uc pattern optimized");
    ok(Stefo::check($uc, 'hello'), "uc('hello') eq 'HELLO'");
    ok(Stefo::check($uc, 'HELLO'), "uc('HELLO') eq 'HELLO'");
    ok(!Stefo::check($uc, 'world'), "uc('world') ne 'HELLO'");
}

{
    my $lc = Stefo::compile(sub { lc($_) eq 'hello' });
    ok(Stefo::is_optimized($lc), "lc pattern optimized");
    ok(Stefo::check($lc, 'HELLO'), "lc('HELLO') eq 'hello'");
    ok(Stefo::check($lc, 'hello'), "lc('hello') eq 'hello'");
    ok(!Stefo::check($lc, 'WORLD'), "lc('WORLD') ne 'hello'");
}

{
    my $ucfirst = Stefo::compile(sub { ucfirst($_) eq 'Hello' });
    ok(Stefo::is_optimized($ucfirst), "ucfirst pattern optimized");
    ok(Stefo::check($ucfirst, 'hello'), "ucfirst('hello') eq 'Hello'");
    ok(Stefo::check($ucfirst, 'Hello'), "ucfirst('Hello') eq 'Hello'");
}

{
    my $lcfirst = Stefo::compile(sub { lcfirst($_) eq 'hELLO' });
    ok(Stefo::is_optimized($lcfirst), "lcfirst pattern optimized");
    ok(Stefo::check($lcfirst, 'HELLO'), "lcfirst('HELLO') eq 'hELLO'");
}

# --- String Concatenation ---
{
    my $concat = Stefo::compile(sub { $_ . '!' eq 'hello!' });
    # Concat may fall back but still work
    ok(Stefo::check($concat, 'hello'), "concat 'hello' . '!' eq 'hello!'");
    ok(!Stefo::check($concat, 'world'), "concat 'world' . '!' ne 'hello!'");
}

# --- String Repeat ---
{
    my $repeat = Stefo::compile(sub { $_ x 3 eq 'aaa' });
    ok(Stefo::is_optimized($repeat), "repeat pattern optimized");
    ok(Stefo::check($repeat, 'a'), "'a' x 3 eq 'aaa'");
    ok(!Stefo::check($repeat, 'b'), "'b' x 3 ne 'aaa'");
}

# --- Exponentiation ---
{
    my $pow = Stefo::compile(sub { $_ ** 2 == 16 });
    ok(Stefo::is_optimized($pow), "pow pattern optimized");
    ok(Stefo::check($pow, 4), "4 ** 2 == 16");
    ok(Stefo::check($pow, -4), "-4 ** 2 == 16");
    ok(!Stefo::check($pow, 3), "3 ** 2 != 16");
}

# --- Unary Negation ---
{
    my $neg = Stefo::compile(sub { -$_ == 5 });
    ok(Stefo::is_optimized($neg), "negate pattern optimized");
    ok(Stefo::check($neg, -5), "-(-5) == 5");
    ok(!Stefo::check($neg, 5), "-(5) != 5");
}

# --- String Comparison Ops ---
{
    my $lt = Stefo::compile(sub { $_ lt 'm' });
    ok(Stefo::is_optimized($lt), "lt pattern optimized");
    ok(Stefo::check($lt, 'abc'), "'abc' lt 'm'");
    ok(!Stefo::check($lt, 'xyz'), "'xyz' not lt 'm'");
}

{
    my $gt = Stefo::compile(sub { $_ gt 'm' });
    ok(Stefo::is_optimized($gt), "gt pattern optimized");
    ok(Stefo::check($gt, 'xyz'), "'xyz' gt 'm'");
    ok(!Stefo::check($gt, 'abc'), "'abc' not gt 'm'");
}

{
    my $le = Stefo::compile(sub { $_ le 'hello' });
    ok(Stefo::is_optimized($le), "le pattern optimized");
    ok(Stefo::check($le, 'hello'), "'hello' le 'hello'");
    ok(Stefo::check($le, 'abc'), "'abc' le 'hello'");
    ok(!Stefo::check($le, 'world'), "'world' not le 'hello'");
}

{
    my $ge = Stefo::compile(sub { $_ ge 'hello' });
    ok(Stefo::is_optimized($ge), "ge pattern optimized");
    ok(Stefo::check($ge, 'hello'), "'hello' ge 'hello'");
    ok(Stefo::check($ge, 'world'), "'world' ge 'hello'");
    ok(!Stefo::check($ge, 'abc'), "'abc' not ge 'hello'");
}

# --- Spaceship Operators ---
{
    my $ncmp = Stefo::compile(sub { ($_ <=> 5) == 0 });
    ok(Stefo::is_optimized($ncmp), "ncmp pattern optimized");
    ok(Stefo::check($ncmp, 5), "5 <=> 5 == 0");
    ok(!Stefo::check($ncmp, 4), "4 <=> 5 != 0");
}

{
    my $scmp = Stefo::compile(sub { ($_ cmp 'hello') == 0 });
    ok(Stefo::is_optimized($scmp), "scmp pattern optimized");
    ok(Stefo::check($scmp, 'hello'), "'hello' cmp 'hello' == 0");
    ok(!Stefo::check($scmp, 'world'), "'world' cmp 'hello' != 0");
}

# --- Bitwise Operations ---
{
    my $band = Stefo::compile(sub { ($_ & 0x0F) == 5 });
    ok(Stefo::is_optimized($band), "bit_and pattern optimized");
    ok(Stefo::check($band, 0x15), "0x15 & 0x0F == 5");
    ok(Stefo::check($band, 0x25), "0x25 & 0x0F == 5");
    ok(!Stefo::check($band, 0x16), "0x16 & 0x0F != 5");
}

{
    my $bor = Stefo::compile(sub { ($_ | 0x0F) == 0x1F });
    ok(Stefo::is_optimized($bor), "bit_or pattern optimized");
    ok(Stefo::check($bor, 0x10), "0x10 | 0x0F == 0x1F");
    ok(!Stefo::check($bor, 0x20), "0x20 | 0x0F != 0x1F");
}

{
    my $bxor = Stefo::compile(sub { ($_ ^ 0xFF) == 0xF0 });
    ok(Stefo::is_optimized($bxor), "bit_xor pattern optimized");
    ok(Stefo::check($bxor, 0x0F), "0x0F ^ 0xFF == 0xF0");
}

{
    my $bnot = Stefo::compile(sub { (~$_ & 0xFF) == 0xF0 });
    ok(Stefo::is_optimized($bnot), "bit_not pattern optimized");
    ok(Stefo::check($bnot, 0x0F), "(~0x0F & 0xFF) == 0xF0");
}

{
    my $shl = Stefo::compile(sub { ($_ << 2) == 20 });
    ok(Stefo::is_optimized($shl), "left_shift pattern optimized");
    ok(Stefo::check($shl, 5), "5 << 2 == 20");
}

{
    my $shr = Stefo::compile(sub { ($_ >> 2) == 5 });
    ok(Stefo::is_optimized($shr), "right_shift pattern optimized");
    ok(Stefo::check($shr, 20), "20 >> 2 == 5");
}

# --- Ternary Operator ---
{
    my $ternary = Stefo::compile(sub { $_ > 0 ? 1 : 0 });
    ok(Stefo::is_optimized($ternary), "ternary pattern optimized");
    ok(Stefo::check($ternary, 5), "5 > 0 ? 1 : 0 is true");
    ok(!Stefo::check($ternary, -5), "-5 > 0 ? 1 : 0 is false");
    ok(!Stefo::check($ternary, 0), "0 > 0 ? 1 : 0 is false");
}

# --- Math Functions ---
{
    my $sqrt = Stefo::compile(sub { sqrt($_) == 5 });
    ok(Stefo::is_optimized($sqrt), "sqrt pattern optimized");
    ok(Stefo::check($sqrt, 25), "sqrt(25) == 5");
    ok(!Stefo::check($sqrt, 16), "sqrt(16) != 5");
}

{
    my $sin = Stefo::compile(sub { sin($_) == 0 });
    ok(Stefo::is_optimized($sin), "sin pattern optimized");
    ok(Stefo::check($sin, 0), "sin(0) == 0");
}

{
    my $cos = Stefo::compile(sub { cos($_) == 1 });
    ok(Stefo::is_optimized($cos), "cos pattern optimized");
    ok(Stefo::check($cos, 0), "cos(0) == 1");
}

{
    my $exp = Stefo::compile(sub { exp($_) > 2.7 && exp($_) < 2.8 });
    ok(Stefo::is_optimized($exp), "exp pattern optimized");
    ok(Stefo::check($exp, 1), "exp(1) is approximately e");
}

{
    my $log = Stefo::compile(sub { log($_) == 0 });
    ok(Stefo::is_optimized($log), "log pattern optimized");
    ok(Stefo::check($log, 1), "log(1) == 0");
}

# --- Chr/Ord ---
{
    my $ord = Stefo::compile(sub { ord($_) == 65 });
    ok(Stefo::is_optimized($ord), "ord pattern optimized");
    ok(Stefo::check($ord, 'A'), "ord('A') == 65");
    ok(Stefo::check($ord, 'ABC'), "ord('ABC') == 65");
    ok(!Stefo::check($ord, 'B'), "ord('B') != 65");
}

{
    my $chr = Stefo::compile(sub { chr($_) eq 'A' });
    ok(Stefo::is_optimized($chr), "chr pattern optimized");
    ok(Stefo::check($chr, 65), "chr(65) eq 'A'");
    ok(!Stefo::check($chr, 66), "chr(66) ne 'A'");
}

# --- Hex/Oct ---
{
    my $hex = Stefo::compile(sub { hex($_) == 255 });
    ok(Stefo::is_optimized($hex), "hex pattern optimized");
    ok(Stefo::check($hex, 'FF'), "hex('FF') == 255");
    ok(Stefo::check($hex, 'ff'), "hex('ff') == 255");
    ok(!Stefo::check($hex, '10'), "hex('10') != 255");
}

# --- Reverse ---
{
    my $rev = Stefo::compile(sub { reverse($_) eq 'olleh' });
    ok(Stefo::is_optimized($rev), "reverse pattern optimized");
    ok(Stefo::check($rev, 'hello'), "reverse('hello') eq 'olleh'");
    ok(!Stefo::check($rev, 'world'), "reverse('world') ne 'olleh'");
}

# --- Quotemeta ---
{
    my $qm = Stefo::compile(sub { length(quotemeta($_)) > length($_) });
    ok(Stefo::is_optimized($qm), "quotemeta pattern optimized");
    ok(Stefo::check($qm, 'a.b'), "quotemeta('a.b') has more chars");
    ok(!Stefo::check($qm, 'abc'), "quotemeta('abc') same length");
}

done_testing();

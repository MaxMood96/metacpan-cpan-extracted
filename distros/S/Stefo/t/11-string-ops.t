#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 47;

use Stefo;

# =============================================================================
# String Operations
# =============================================================================

# uc() - uppercase
{
    my $uc = Stefo::compile(sub { uc($_) eq 'HELLO' });
    ok(Stefo::is_optimized($uc), "uc(\$_) eq 'HELLO' optimized");
    ok(Stefo::check($uc, 'hello'), "uc('hello') eq 'HELLO'");
    ok(Stefo::check($uc, 'HELLO'), "uc('HELLO') eq 'HELLO'");
    ok(Stefo::check($uc, 'HeLLo'), "uc('HeLLo') eq 'HELLO'");
    ok(!Stefo::check($uc, 'world'), "uc('world') ne 'HELLO'");
}

# lc() - lowercase
{
    my $lc = Stefo::compile(sub { lc($_) eq 'hello' });
    ok(Stefo::is_optimized($lc), "lc(\$_) eq 'hello' optimized");
    ok(Stefo::check($lc, 'HELLO'), "lc('HELLO') eq 'hello'");
    ok(Stefo::check($lc, 'hello'), "lc('hello') eq 'hello'");
    ok(Stefo::check($lc, 'HeLLo'), "lc('HeLLo') eq 'hello'");
    ok(!Stefo::check($lc, 'WORLD'), "lc('WORLD') ne 'hello'");
}

# ucfirst() - uppercase first character
{
    my $ucf = Stefo::compile(sub { ucfirst($_) eq 'Hello' });
    ok(Stefo::is_optimized($ucf), "ucfirst(\$_) eq 'Hello' optimized");
    ok(Stefo::check($ucf, 'hello'), "ucfirst('hello') eq 'Hello'");
    ok(Stefo::check($ucf, 'Hello'), "ucfirst('Hello') eq 'Hello'");
    ok(!Stefo::check($ucf, 'HELLO'), "ucfirst('HELLO') ne 'Hello'");
}

# lcfirst() - lowercase first character
{
    my $lcf = Stefo::compile(sub { lcfirst($_) eq 'hELLO' });
    ok(Stefo::is_optimized($lcf), "lcfirst(\$_) eq 'hELLO' optimized");
    ok(Stefo::check($lcf, 'HELLO'), "lcfirst('HELLO') eq 'hELLO'");
    ok(Stefo::check($lcf, 'hELLO'), "lcfirst('hELLO') eq 'hELLO'");
    ok(!Stefo::check($lcf, 'hello'), "lcfirst('hello') ne 'hELLO'");
}

# String repetition (x)
{
    my $repeat = Stefo::compile(sub { $_ x 3 eq 'aaa' });
    ok(Stefo::is_optimized($repeat), "\$_ x 3 eq 'aaa' optimized");
    ok(Stefo::check($repeat, 'a'), "'a' x 3 eq 'aaa'");
    ok(!Stefo::check($repeat, 'b'), "'b' x 3 ne 'aaa'");
}

# =============================================================================
# String Comparison Operators (lt, gt, le, ge)
# =============================================================================

# lt - less than (string)
{
    my $lt = Stefo::compile(sub { $_ lt 'm' });
    ok(Stefo::is_optimized($lt), "\$_ lt 'm' optimized");
    ok(Stefo::check($lt, 'a'), "'a' lt 'm'");
    ok(Stefo::check($lt, 'hello'), "'hello' lt 'm'");
    ok(!Stefo::check($lt, 'm'), "'m' not lt 'm'");
    ok(!Stefo::check($lt, 'zebra'), "'zebra' not lt 'm'");
}

# gt - greater than (string)
{
    my $gt = Stefo::compile(sub { $_ gt 'm' });
    ok(Stefo::is_optimized($gt), "\$_ gt 'm' optimized");
    ok(Stefo::check($gt, 'zebra'), "'zebra' gt 'm'");
    ok(Stefo::check($gt, 'n'), "'n' gt 'm'");
    ok(!Stefo::check($gt, 'm'), "'m' not gt 'm'");
    ok(!Stefo::check($gt, 'a'), "'a' not gt 'm'");
}

# le - less than or equal (string)
{
    my $le = Stefo::compile(sub { $_ le 'm' });
    ok(Stefo::is_optimized($le), "\$_ le 'm' optimized");
    ok(Stefo::check($le, 'a'), "'a' le 'm'");
    ok(Stefo::check($le, 'm'), "'m' le 'm'");
    ok(!Stefo::check($le, 'n'), "'n' not le 'm'");
}

# ge - greater than or equal (string)
{
    my $ge = Stefo::compile(sub { $_ ge 'm' });
    ok(Stefo::is_optimized($ge), "\$_ ge 'm' optimized");
    ok(Stefo::check($ge, 'zebra'), "'zebra' ge 'm'");
    ok(Stefo::check($ge, 'm'), "'m' ge 'm'");
    ok(!Stefo::check($ge, 'a'), "'a' not ge 'm'");
}

# cmp - string comparison operator
{
    my $cmp_neg = Stefo::compile(sub { ($_ cmp 'm') < 0 });
    ok(Stefo::is_optimized($cmp_neg), "(\$_ cmp 'm') < 0 optimized");
    ok(Stefo::check($cmp_neg, 'a'), "('a' cmp 'm') < 0");
    ok(!Stefo::check($cmp_neg, 'm'), "('m' cmp 'm') == 0");
    ok(!Stefo::check($cmp_neg, 'z'), "('z' cmp 'm') > 0");
}

# <=> - numeric comparison operator
{
    my $ncmp = Stefo::compile(sub { ($_ <=> 10) > 0 });
    ok(Stefo::is_optimized($ncmp), "(\$_ <=> 10) > 0 optimized");
    ok(Stefo::check($ncmp, 15), "(15 <=> 10) > 0");
    ok(!Stefo::check($ncmp, 10), "(10 <=> 10) == 0");
    ok(!Stefo::check($ncmp, 5), "(5 <=> 10) < 0");
}

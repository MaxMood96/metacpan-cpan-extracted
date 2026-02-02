#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use nvec;

# Test inverse trig functions
my $v = nvec::new([0.5, 0, -0.5]);
my $asin = $v->asin();
ok(abs($asin->get(0) - 0.5236) < 0.001, 'asin(0.5) ~= 0.5236');
ok(abs($asin->get(1)) < 0.001, 'asin(0) = 0');

my $acos = $v->acos();
ok(abs($acos->get(0) - 1.0472) < 0.001, 'acos(0.5) ~= 1.0472');
ok(abs($acos->get(1) - 1.5708) < 0.001, 'acos(0) ~= pi/2');

my $v2 = nvec::new([0, 1, -1]);
my $atan = $v2->atan();
ok(abs($atan->get(0)) < 0.001, 'atan(0) = 0');
ok(abs($atan->get(1) - 0.7854) < 0.001, 'atan(1) ~= pi/4');

# Test hyperbolic functions
my $v3 = nvec::new([0, 1, -1]);
my $sinh = $v3->sinh();
ok(abs($sinh->get(0)) < 0.001, 'sinh(0) = 0');
ok(abs($sinh->get(1) - 1.1752) < 0.001, 'sinh(1) ~= 1.1752');

my $cosh = $v3->cosh();
ok(abs($cosh->get(0) - 1) < 0.001, 'cosh(0) = 1');
ok(abs($cosh->get(1) - 1.5431) < 0.001, 'cosh(1) ~= 1.5431');

my $tanh = $v3->tanh();
ok(abs($tanh->get(0)) < 0.001, 'tanh(0) = 0');
ok(abs($tanh->get(1) - 0.7616) < 0.001, 'tanh(1) ~= 0.7616');

# Test log10 and log2
my $v4 = nvec::new([1, 10, 100]);
my $log10 = $v4->log10();
ok(abs($log10->get(0)) < 0.001, 'log10(1) = 0');
ok(abs($log10->get(1) - 1) < 0.001, 'log10(10) = 1');
ok(abs($log10->get(2) - 2) < 0.001, 'log10(100) = 2');

my $v5 = nvec::new([1, 2, 8]);
my $log2 = $v5->log2();
ok(abs($log2->get(0)) < 0.001, 'log2(1) = 0');
ok(abs($log2->get(1) - 1) < 0.001, 'log2(2) = 1');
ok(abs($log2->get(2) - 3) < 0.001, 'log2(8) = 3');

# Test sign
my $v6 = nvec::new([-5, 0, 5]);
my $sign = $v6->sign();
is($sign->get(0), -1, 'sign(-5) = -1');
is($sign->get(1), 0, 'sign(0) = 0');
is($sign->get(2), 1, 'sign(5) = 1');

# Test clip
my $v7 = nvec::new([1, 5, 10]);
my $clipped = $v7->clip(2, 8);
is($clipped->get(0), 2, 'clip(1, 2, 8) = 2');
is($clipped->get(1), 5, 'clip(5, 2, 8) = 5');
is($clipped->get(2), 8, 'clip(10, 2, 8) = 8');

# Test cumsum
my $v8 = nvec::new([1, 2, 3, 4]);
my $cumsum = $v8->cumsum();
is($cumsum->len, 4, 'cumsum preserves length');
is($cumsum->get(0), 1, 'cumsum[0] = 1');
is($cumsum->get(1), 3, 'cumsum[1] = 3');
is($cumsum->get(2), 6, 'cumsum[2] = 6');
is($cumsum->get(3), 10, 'cumsum[3] = 10');

# Test cumprod
my $cumprod = $v8->cumprod();
is($cumprod->len, 4, 'cumprod preserves length');
is($cumprod->get(0), 1, 'cumprod[0] = 1');
is($cumprod->get(1), 2, 'cumprod[1] = 2');
is($cumprod->get(2), 6, 'cumprod[2] = 6');
is($cumprod->get(3), 24, 'cumprod[3] = 24');

# Test diff
my $diff = $v8->diff();
is($diff->len, 3, 'diff length = n-1');
is($diff->get(0), 1, 'diff[0] = 2-1 = 1');
is($diff->get(1), 1, 'diff[1] = 3-2 = 1');
is($diff->get(2), 1, 'diff[2] = 4-3 = 1');

# Test sort
my $unsorted = nvec::new([3, 1, 4, 1, 5, 9, 2, 6]);
my $sorted = $unsorted->sort();
is($sorted->get(0), 1, 'sorted[0] = 1');
is($sorted->get(1), 1, 'sorted[1] = 1');
is($sorted->get(2), 2, 'sorted[2] = 2');
is($sorted->get(7), 9, 'sorted[7] = 9');

# Test argsort
my $v9 = nvec::new([30, 10, 20]);
my $indices = $v9->argsort();
is($indices->get(0), 1, 'argsort[0] = 1 (index of 10)');
is($indices->get(1), 2, 'argsort[1] = 2 (index of 20)');
is($indices->get(2), 0, 'argsort[2] = 0 (index of 30)');

# Test median
my $odd = nvec::new([3, 1, 2]);
is($odd->median, 2, 'median of [3,1,2] = 2');

my $even = nvec::new([4, 1, 3, 2]);
is($even->median, 2.5, 'median of [4,1,3,2] = 2.5');

# Test isnan/isinf/isfinite
use POSIX qw(HUGE_VAL);
my $nan = HUGE_VAL - HUGE_VAL;  # NaN
my $inf = HUGE_VAL;  # Inf
my $ninf = -(HUGE_VAL);  # -Inf
my $special = nvec::new([1.0, $nan, $inf, $ninf]);  # 1, NaN, Inf, -Inf
my $isnan = $special->isnan();
is($isnan->get(0), 0, 'isnan(1) = 0');
is($isnan->get(1), 1, 'isnan(NaN) = 1');
is($isnan->get(2), 0, 'isnan(Inf) = 0');

my $isinf = $special->isinf();
is($isinf->get(0), 0, 'isinf(1) = 0');
is($isinf->get(1), 0, 'isinf(NaN) = 0');
is($isinf->get(2), 1, 'isinf(Inf) = 1');
is($isinf->get(3), 1, 'isinf(-Inf) = 1');

my $isfinite = $special->isfinite();
is($isfinite->get(0), 1, 'isfinite(1) = 1');
is($isfinite->get(1), 0, 'isfinite(NaN) = 0');
is($isfinite->get(2), 0, 'isfinite(Inf) = 0');

done_testing();

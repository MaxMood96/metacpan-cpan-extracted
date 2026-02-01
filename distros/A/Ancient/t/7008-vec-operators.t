#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use nvec;

# Test operator overloading
my $a = nvec::new([1, 2, 3, 4]);
my $b = nvec::new([5, 6, 7, 8]);

# Addition
my $c = $a + $b;
is($c->get(0), 6, '1 + 5 = 6');
is($c->get(3), 12, '4 + 8 = 12');

# Subtraction
my $d = $b - $a;
is($d->get(0), 4, '5 - 1 = 4');
is($d->get(3), 4, '8 - 4 = 4');

# Multiplication (element-wise)
my $e = $a * $b;
is($e->get(0), 5, '1 * 5 = 5');
is($e->get(3), 32, '4 * 8 = 32');

# Division (element-wise)
my $f = $b / $a;
is($f->get(0), 5, '5 / 1 = 5');
is($f->get(3), 2, '8 / 4 = 2');

# Scalar operations
my $g = $a + 10;
is($g->get(0), 11, '1 + 10 = 11');
is($g->get(3), 14, '4 + 10 = 14');

my $h = $a * 2;
is($h->get(0), 2, '1 * 2 = 2');
is($h->get(3), 8, '4 * 2 = 8');

my $i = $a / 2;
ok(abs($i->get(0) - 0.5) < 0.001, '1 / 2 = 0.5');
ok(abs($i->get(3) - 2.0) < 0.001, '4 / 2 = 2');

# Negation
my $j = -$a;
is($j->get(0), -1, '-1');
is($j->get(3), -4, '-4');

# In-place operators
my $k = nvec::new([1, 2, 3, 4]);
$k += $b;
is($k->get(0), 6, '1 += 5 = 6');
is($k->get(3), 12, '4 += 8 = 12');

my $l = nvec::new([10, 20, 30, 40]);
$l -= $a;
is($l->get(0), 9, '10 -= 1 = 9');
is($l->get(3), 36, '40 -= 4 = 36');

my $m = nvec::new([1, 2, 3, 4]);
$m *= 3;
is($m->get(0), 3, '1 *= 3 = 3');
is($m->get(3), 12, '4 *= 3 = 12');

my $n = nvec::new([10, 20, 30, 40]);
$n /= 2;
is($n->get(0), 5, '10 /= 2 = 5');
is($n->get(3), 20, '40 /= 2 = 20');

# Scalar in-place
my $o = nvec::new([1, 2, 3, 4]);
$o += 100;
is($o->get(0), 101, '1 += 100 = 101');
is($o->get(3), 104, '4 += 100 = 104');

# Chained operations
my $p = ($a + $b) * 2;
is($p->get(0), 12, '(1+5)*2 = 12');
is($p->get(3), 24, '(4+8)*2 = 24');

# Stringification
my $small = nvec::new([1, 2, 3]);
like("$small", qr/vec\[1, 2, 3\]/, 'stringify small vec');

my $large = nvec::range(0, 100);
like("$large", qr/vec\[0.*\.\.\..*99\].*len=100/, 'stringify large vec');

# Boolean context
my $empty = nvec::new([]);
ok(!$empty, 'empty vec is false');
ok($a, 'non-empty vec is true');

# abs
my $neg = nvec::new([-1, 2, -3, 4]);
my $absv = abs($neg);
is($absv->get(0), 1, 'abs(-1) = 1');
is($absv->get(2), 3, 'abs(-3) = 3');

done_testing();

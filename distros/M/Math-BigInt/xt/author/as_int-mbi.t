# -*- mode: perl; -*-

use strict;
use warnings;

use Test::More;
use Scalar::Util qw< refaddr >;

use Math::BigInt;
use Math::BigFloat;
use Math::BigRat;

my ($x, $y);

note("as_int() as a class method");

$x = Math::BigInt -> as_int("2");
subtest '$x = Math::BigInt -> as_int("2");' => sub {
    plan tests => 2;
    is(ref($x), 'Math::BigInt', '$x is a Math::BigInt');
    cmp_ok($x, "==", 2, '$x == 2');
};

note("as_int() as an instance method");

$x = Math::BigInt -> new("2"); $y = $x -> as_int();
subtest '$x = Math::BigInt -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 4;
    is(ref($x), 'Math::BigInt', '$x is a Math::BigInt');
    is(ref($y), 'Math::BigInt', '$y is a Math::BigInt');
    cmp_ok($y, "==", 2, '$y == 2');
    isnt(refaddr($x), refaddr($y), '$x and $y are different objects');
};

$x = Math::BigFloat -> new("2"); $y = $x -> as_int();
subtest '$x = Math::BigFloat -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 4;
    is(ref($x), 'Math::BigFloat', '$x is a Math::BigFloat');
    is(ref($y), 'Math::BigInt', '$y is a Math::BigInt');
    cmp_ok($y, "==", 2, '$y == 2');
    isnt(refaddr($x), refaddr($y), '$x and $y are different objects');
};

$x = Math::BigFloat -> new("2.8"); $y = $x -> as_int();
subtest '$x = Math::BigFloat -> new("2.8"); $y = $x -> as_int();' => sub {
    plan tests => 4;
    is(ref($x), 'Math::BigFloat', '$x is a Math::BigFloat');
    is(ref($y), 'Math::BigInt', '$y is a Math::BigInt');
    cmp_ok($y, "==", 2, '$y == 2');
    isnt(refaddr($x), refaddr($y), '$x and $y are different objects');
};

$x = Math::BigRat -> new("2"); $y = $x -> as_int();
subtest '$x = Math::BigRat -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 4;
    is(ref($x), 'Math::BigRat', '$x is a Math::BigRat');
    is(ref($y), 'Math::BigInt', '$y is a Math::BigInt');
    cmp_ok($y, "==", 2, '$y == 2');
    isnt(refaddr($x), refaddr($y), '$x and $y are different objects');
};

$x = Math::BigRat -> new("14/5"); $y = $x -> as_int();
subtest '$x = Math::BigRat -> new("14/5"); $y = $x -> as_int();' => sub {
    plan tests => 4;
    is(ref($x), 'Math::BigRat', '$x is a Math::BigRat');
    is(ref($y), 'Math::BigInt', '$y is a Math::BigInt');
    cmp_ok($y, "==", 2, '$y == 2');
    isnt(refaddr($x), refaddr($y), '$x and $y are different objects');
};

note("as_int() returns a Math::BigInt regardless of upgrading/downgrading");

require Math::BigFloat;
Math::BigInt -> upgrade("Math::BigFloat");
Math::BigFloat -> downgrade("Math::BigInt");
Math::BigFloat -> upgrade("Math::BigRat");

$y = Math::BigInt -> as_int("2");

subtest '$y = Math::BigInt -> as_int("2");' => sub {
    plan tests => 2;
    is(ref($y), 'Math::BigInt', 'class of $y');
    cmp_ok($y -> numify(), "==", 2, 'value of $y');
};

$y = Math::BigInt -> as_int("2.8");

subtest '$y = Math::BigInt -> as_int("2.8");' => sub {
    plan tests => 2;
    is(ref($y), 'Math::BigInt', 'class of $y');
    is($y, "2", 'value of $y');
};

$x = Math::BigInt -> new("2"); $y = $x -> as_int();

subtest '$x = Math::BigInt -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 3;
    is(ref($x), 'Math::BigInt', 'class of $x');
    is(ref($y), 'Math::BigInt', 'class of $y');
    cmp_ok($y -> numify(), "==", 2, 'value of $y');
};

$x = Math::BigFloat -> new("2"); $y = $x -> as_int();

subtest '$x = Math::BigFloat -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 3;
    is(ref($x), 'Math::BigInt', 'class of $x');
    is(ref($y), 'Math::BigInt', 'class of $y');
    cmp_ok($y -> numify(), "==", 2, 'value of $y');
};

$x = Math::BigFloat -> new("2.8"); $y = $x -> as_int();

subtest '$x = Math::BigFloat -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 3;
    is(ref($x), 'Math::BigFloat', 'class of $x');
    is(ref($y), 'Math::BigInt', 'class of $y');
    cmp_ok($y -> numify(), "==", 2, 'value of $y');
};

$x = Math::BigRat -> new("2"); $y = $x -> as_int();

subtest '$x = Math::BigRat -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 3;
    is(ref($x), 'Math::BigRat', 'class of $x');
    is(ref($y), 'Math::BigInt', 'class of $y');
    cmp_ok($y -> numify(), "==", 2, 'value of $y');
};

$x = Math::BigRat -> new("14/5"); $y = $x -> as_int();

subtest '$x = Math::BigRat -> new("2"); $y = $x -> as_int();' => sub {
    plan tests => 3;
    is(ref($x), 'Math::BigRat', 'class of $x');
    is(ref($y), 'Math::BigInt', 'class of $y');
    cmp_ok($y -> numify(), "==", 2, 'value of $y');
};

note("as_int() preserves all instance variables");

Math::BigInt -> upgrade(undef);
Math::BigFloat -> downgrade(undef);
Math::BigFloat -> upgrade(undef);

$x = Math::BigInt -> new("3");

$x -> accuracy(2);
$y = $x -> as_int();

subtest '$x = Math::BigInt -> new("3"); $x -> accuracy(2); $y = $x -> as_int()'
  => sub {
      plan tests => 4;
      is($x -> accuracy(), 2, 'accuracy of $x');
      is($x -> precision(), undef, 'precision of $x');
      is($y -> accuracy(), $x -> accuracy(), 'accuracy of $y');
      is($y -> precision(), $x -> precision(), 'precision of $y');
  };

$x -> precision(2);
$y = $x -> as_int();

subtest '$x = Math::BigInt -> new("3"); $x -> precision(2); $y = $x -> as_int()'
  => sub {
      plan tests => 4;
      is($x -> accuracy(), undef, 'accuracy of $x');
      is($x -> precision(), 2, 'precision of $x');
      is($y -> accuracy(), $x -> accuracy(), 'accuracy of $y');
      is($y -> precision(), $x -> precision(), 'precision of $y');
  };

done_testing();

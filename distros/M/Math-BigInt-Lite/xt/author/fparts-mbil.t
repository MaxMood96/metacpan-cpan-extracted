# -*- mode: perl; -*-

# test fparts(), numerator(), denominator()

use strict;
use warnings;

use Test::More tests => 31;

my $class;

BEGIN {
    $class = 'Math::BigInt::Lite';
    use_ok($class);
}

while (<DATA>) {
    s/#.*$//;                   # remove comments
    s/\s+$//;                   # remove trailing whitespace
    next unless length;         # skip empty lines

    my ($x_str, $n_str, $d_str) = split /:/;
    my $test;

    # test fparts()

    $test = qq|\$x = $class -> new("$x_str");|
          . qq| (\$n, \$d) = \$x -> fparts();|;

    subtest $test => sub {
        plan tests => 5;

        my $x = $class -> new($x_str);
        my ($n_got, $d_got) = $x -> fparts();

        like(ref($n_got), qr/^Math::BigInt(::Lite)?$/,
            "class of numerator (got a " . ref($n_got) . ")");
        like(ref($d_got), qr/^Math::BigInt(::Lite)?$/,
            "class of denominator (got a " . ref($d_got) . ")");

        is($n_got, $n_str, "value of numerator");
        is($d_got, $d_str, "value of denominator");
        is($x,     $x_str, "input is unmodified");
    };

    # test numerator()

    $test = qq|\$x = $class -> new("$x_str");|
          . qq| \$n = \$x -> numerator();|;

    subtest $test => sub {
        plan tests => 3;

        my $x = $class -> new($x_str);
        my $n_got = $x -> numerator();

        like(ref($n_got), qr/^Math::BigInt(::Lite)?$/,
            "class of numertor (got a " . ref($n_got) . ")");

        is($n_got, $n_str, "value of numerator");
        is($x,     $x_str, "input is unmodified");
    };

    # test denominator()

    $test = qq|\$x = $class -> new("$x_str");|
          . qq| \$d = \$x -> denominator();|;

    subtest $test => sub {
        plan tests => 3;

        my $x     = $class -> new($x_str);
        my $d_got = $x -> denominator();

        like(ref($d_got), qr/^Math::BigInt(::Lite)?$/,
            "class of denominator (got a " . ref($d_got) . ")");

        is($d_got, $d_str, "value of denominator");
        is($x,     $x_str, "input is unmodified");
    };
}

__DATA__

NaN:NaN:NaN

inf:inf:1
-inf:-inf:1

-30:-30:1
-3:-3:1
-1:-1:1
0:0:1
1:1:1
3:3:1
30:30:1

#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 17;

use Math::Sidef qw(factor composite prime ipow factor_exp is_prime is_composite);

is(ref(prime(100)), 'Math::AnyNum');

is(prime(1e7),     "179424673");    # 10^9-th prime number
is(composite(1e7), "10708555");     # 10^9-th composite number

ok(is_prime(ipow(2,  127) - 1));
ok(!is_prime(ipow(2, 128) + 1));

ok(!is_composite(ipow(2, 127) - 1));
ok(is_composite(ipow(2,  128) + 1));

ok(is_prime("43"));
ok(is_prime(Math::AnyNum->new(43)));

# Prime factorization of 2^64 + 1
is(join(' * ', factor(ipow(2, 64) + 1)), "274177 * 67280421310721");

# Prime factorization of 5040
is_deeply([factor_exp(5040)], [[2, 4], [3, 2], [5, 1], [7, 1]]);

# Multiple return values
is_deeply([123,   4],    [Math::Sidef::divmod(1234, 10)]);
is_deeply([-1235, 1234], [Math::Sidef::iquadratic_formula(-1, -1, 1524031 - 41)]);

# Iterate over prime numbers in range 1..20
my @primes;

Math::Sidef::each_prime(
    1, 20,
    sub {
        push @primes, $_[0];
    }
);

is("@primes", "2 3 5 7 11 13 17 19");

is(
    Math::Sidef::dirichlet_sum(
                               10**3,                                           # n
                               sub { 1 },                                       # f
                               sub { Math::Sidef::ipow($_[0], 2) },             # g
                               sub { $_[0] },                                   # F(n) = Sum_{k=1..n} f(k)
                               sub { Math::Sidef::faulhaber_sum($_[0], 2) },    # G(n) = Sum_{k=1..n} g(k)
                              ),
    "401382971"
  );

is(
    Math::AnyNum::dirichlet_sum(
                                10**4,                                           # n
                                sub { 1 },                                       # f
                                sub { Math::Sidef::ipow($_[0], 2) },             # g
                                sub { $_[0] },                                   # F(n) = Sum_{k=1..n} f(k)
                                sub { Math::Sidef::faulhaber_sum($_[0], 2) },    # G(n) = Sum_{k=1..n} g(k)
                               ),
    "400757638164"
  );

is(
    Math::Sidef::dirichlet_sum(
                               10**5,                                            # n
                               sub { 1 },                                        # f
                               sub { Math::AnyNum::ipow($_[0], 2) },             # g
                               sub { $_[0] },                                    # F(n) = Sum_{k=1..n} f(k)
                               sub { Math::AnyNum::faulhaber_sum($_[0], 2) },    # G(n) = Sum_{k=1..n} g(k)
                              ),
    "400692683389101"
  );

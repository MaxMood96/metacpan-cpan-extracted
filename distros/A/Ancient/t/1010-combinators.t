#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use blib;

use util qw(negate once partial);

# ============================================
# negate tests
# ============================================

my $is_even = sub { $_[0] % 2 == 0 };
my $is_odd = negate($is_even);

ok($is_even->(4), 'is_even: 4 is even');
ok(!$is_even->(3), 'is_even: 3 is not even');
ok($is_odd->(3), 'negate: 3 is odd');
ok(!$is_odd->(4), 'negate: 4 is not odd');

# negate with multiple args
my $both_positive = sub { $_[0] > 0 && $_[1] > 0 };
my $not_both_positive = negate($both_positive);

ok($both_positive->(1, 2), 'both_positive: 1,2 both positive');
ok(!$not_both_positive->(1, 2), 'negate: 1,2 returns false');
ok($not_both_positive->(-1, 2), 'negate: -1,2 returns true');
ok($not_both_positive->(1, -2), 'negate: 1,-2 returns true');

# negate with $_
my $is_defined = sub { defined $_ };
my $is_undefined = negate($is_defined);
{
    local $_ = 42;
    ok(!$is_undefined->(), 'negate: respects outer $_');
}

# ============================================
# once tests
# ============================================

my $counter = 0;
my $increment = once(sub { ++$counter });

is($counter, 0, 'once: not called yet');
is($increment->(), 1, 'once: first call returns 1');
is($counter, 1, 'once: counter incremented');
is($increment->(), 1, 'once: second call returns cached 1');
is($counter, 1, 'once: counter not incremented again');
is($increment->(), 1, 'once: third call still returns 1');
is($counter, 1, 'once: counter still 1');

# once with complex return value
my $get_config = once(sub {
    return { db => 'postgres', port => 5432 };
});

my $c1 = $get_config->();
my $c2 = $get_config->();
is($c1->{db}, 'postgres', 'once: returns complex value');
is($c1, $c2, 'once: returns same reference');

# once returning undef
my $undef_once = once(sub { return undef });
is($undef_once->(), undef, 'once: can return undef');
is($undef_once->(), undef, 'once: returns cached undef');

# multiple independent once functions
my $a_count = 0;
my $b_count = 0;
my $once_a = once(sub { ++$a_count });
my $once_b = once(sub { ++$b_count });

$once_a->();
$once_a->();
$once_b->();

is($a_count, 1, 'once: a called once');
is($b_count, 1, 'once: b called once');

# ============================================
# partial tests
# ============================================

my $add = sub { $_[0] + $_[1] };
my $add5 = partial($add, 5);

is($add5->(3), 8, 'partial: 5+3=8');
is($add5->(10), 15, 'partial: 5+10=15');
is($add5->(0), 5, 'partial: 5+0=5');

# partial with multiple bound args
my $add3 = sub { $_[0] + $_[1] + $_[2] };
my $add_1_2 = partial($add3, 1, 2);

is($add_1_2->(3), 6, 'partial: 1+2+3=6');
is($add_1_2->(10), 13, 'partial: 1+2+10=13');

# partial with all args bound
my $greet = sub { "Hello, $_[0]!" };
my $greet_world = partial($greet, "World");

is($greet_world->(), "Hello, World!", 'partial: all args bound');

# partial with remaining args
my $concat = sub { join('-', @_) };
my $prefix_a = partial($concat, 'a');

is($prefix_a->('b', 'c'), 'a-b-c', 'partial: with multiple remaining args');
is($prefix_a->('x'), 'a-x', 'partial: with one remaining arg');

# partial preserves order
my $sub_args = sub { [@_] };
my $partial_12 = partial($sub_args, 1, 2);
is_deeply($partial_12->(3, 4), [1, 2, 3, 4], 'partial: preserves argument order');

# partial with no bound args (identity-like)
my $no_bound = partial($add);
is($no_bound->(2, 3), 5, 'partial: with no bound args');

# nested partial
my $add4 = sub { $_[0] + $_[1] + $_[2] + $_[3] };
my $add_1 = partial($add4, 1);
my $add_1_2_nested = partial($add_1, 2);

is($add_1_2_nested->(3, 4), 10, 'partial: nested partial 1+2+3+4=10');

done_testing;

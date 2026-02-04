#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 97;

use Stefo;

# =============================================================================
# Numeric Comparison Operators
# =============================================================================

# Greater than or equal (>=)
{
    my $ge = Stefo::compile(sub { $_ >= 10 });
    ok(Stefo::is_optimized($ge), "\$_ >= 10 optimized");
    ok(Stefo::check($ge, 10), "10 >= 10 is true");
    ok(Stefo::check($ge, 15), "15 >= 10 is true");
    ok(!Stefo::check($ge, 5), "5 >= 10 is false");
    ok(!Stefo::check($ge, 9), "9 >= 10 is false");
}

# Less than or equal (<=)
{
    my $le = Stefo::compile(sub { $_ <= 10 });
    ok(Stefo::is_optimized($le), "\$_ <= 10 optimized");
    ok(Stefo::check($le, 10), "10 <= 10 is true");
    ok(Stefo::check($le, 5), "5 <= 10 is true");
    ok(!Stefo::check($le, 15), "15 <= 10 is false");
    ok(!Stefo::check($le, 11), "11 <= 10 is false");
}

# Numeric equality (==)
{
    my $eq = Stefo::compile(sub { $_ == 42 });
    ok(Stefo::is_optimized($eq), "\$_ == 42 optimized");
    ok(Stefo::check($eq, 42), "42 == 42 is true");
    ok(!Stefo::check($eq, 41), "41 == 42 is false");
    ok(!Stefo::check($eq, 43), "43 == 42 is false");
    ok(!Stefo::check($eq, 0), "0 == 42 is false");
}

# Numeric inequality (!=)
{
    my $ne = Stefo::compile(sub { $_ != 42 });
    ok(Stefo::is_optimized($ne), "\$_ != 42 optimized");
    ok(!Stefo::check($ne, 42), "42 != 42 is false");
    ok(Stefo::check($ne, 41), "41 != 42 is true");
    ok(Stefo::check($ne, 0), "0 != 42 is true");
    ok(Stefo::check($ne, -42), "-42 != 42 is true");
}

# =============================================================================
# String Comparison Operators
# =============================================================================

# String equality (eq)
{
    my $eq = Stefo::compile(sub { $_ eq 'hello' });
    ok(Stefo::is_optimized($eq), "\$_ eq 'hello' optimized");
    ok(Stefo::check($eq, 'hello'), "'hello' eq 'hello' is true");
    ok(!Stefo::check($eq, 'world'), "'world' eq 'hello' is false");
    ok(!Stefo::check($eq, 'Hello'), "'Hello' eq 'hello' is false (case sensitive)");
    ok(!Stefo::check($eq, ''), "'' eq 'hello' is false");
}

# String inequality (ne)
{
    my $ne = Stefo::compile(sub { $_ ne 'hello' });
    ok(Stefo::is_optimized($ne), "\$_ ne 'hello' optimized");
    ok(!Stefo::check($ne, 'hello'), "'hello' ne 'hello' is false");
    ok(Stefo::check($ne, 'world'), "'world' ne 'hello' is true");
    ok(Stefo::check($ne, 'Hello'), "'Hello' ne 'hello' is true (case sensitive)");
    ok(Stefo::check($ne, ''), "'' ne 'hello' is true");
}

# =============================================================================
# Length Checks
# =============================================================================

# length($_) > N
{
    my $len = Stefo::compile(sub { length($_) > 5 });
    ok(Stefo::is_optimized($len), "length(\$_) > 5 optimized");
    ok(Stefo::check($len, 'abcdef'), "length('abcdef') > 5 is true");
    ok(!Stefo::check($len, 'abc'), "length('abc') > 5 is false");
    ok(!Stefo::check($len, 'abcde'), "length('abcde') > 5 is false (boundary)");
    ok(Stefo::check($len, 'abcdefghij'), "length('abcdefghij') > 5 is true");
}

# =============================================================================
# Reference Checks
# =============================================================================

# ref($_) - is a reference
{
    my $is_ref = Stefo::compile(sub { ref($_) });
    ok(Stefo::is_optimized($is_ref), "ref(\$_) optimized");
    ok(Stefo::check($is_ref, []), "ref([]) is true");
    ok(Stefo::check($is_ref, {}), "ref({}) is true");
    ok(Stefo::check($is_ref, sub {}), "ref(sub {}) is true");
    ok(!Stefo::check($is_ref, 'scalar'), "ref('scalar') is false");
    ok(!Stefo::check($is_ref, 42), "ref(42) is false");
}

# ref($_) eq 'ARRAY'
{
    my $is_array = Stefo::compile(sub { ref($_) eq 'ARRAY' });
    ok(Stefo::is_optimized($is_array), "ref(\$_) eq 'ARRAY' optimized");
    ok(Stefo::check($is_array, []), "ref([]) eq 'ARRAY' is true");
    ok(Stefo::check($is_array, [1, 2, 3]), "ref([1,2,3]) eq 'ARRAY' is true");
    ok(!Stefo::check($is_array, {}), "ref({}) eq 'ARRAY' is false");
    ok(!Stefo::check($is_array, 'ARRAY'), "ref('ARRAY') eq 'ARRAY' is false");
}

# ref($_) eq 'HASH'
{
    my $is_hash = Stefo::compile(sub { ref($_) eq 'HASH' });
    ok(Stefo::is_optimized($is_hash), "ref(\$_) eq 'HASH' optimized");
    ok(Stefo::check($is_hash, {}), "ref({}) eq 'HASH' is true");
    ok(Stefo::check($is_hash, {a => 1}), "ref({a=>1}) eq 'HASH' is true");
    ok(!Stefo::check($is_hash, []), "ref([]) eq 'HASH' is false");
    ok(!Stefo::check($is_hash, 'HASH'), "ref('HASH') eq 'HASH' is false");
}

# =============================================================================
# Regex Matching
# =============================================================================

# Positive regex match (=~)
{
    my $match = Stefo::compile(sub { $_ =~ /foo/ });
    ok(Stefo::is_optimized($match), "\$_ =~ /foo/ optimized");
    ok(Stefo::check($match, 'foobar'), "'foobar' =~ /foo/ is true");
    ok(Stefo::check($match, 'barfoo'), "'barfoo' =~ /foo/ is true");
    ok(!Stefo::check($match, 'bar'), "'bar' =~ /foo/ is false");
    ok(!Stefo::check($match, 'FOO'), "'FOO' =~ /foo/ is false (case sensitive)");
}

# Negative regex match (!~)
{
    my $nomatch = Stefo::compile(sub { $_ !~ /foo/ });
    ok(Stefo::is_optimized($nomatch), "\$_ !~ /foo/ optimized");
    ok(!Stefo::check($nomatch, 'foobar'), "'foobar' !~ /foo/ is false");
    ok(Stefo::check($nomatch, 'bar'), "'bar' !~ /foo/ is true");
    ok(Stefo::check($nomatch, 'FOO'), "'FOO' !~ /foo/ is true (case sensitive)");
}

# =============================================================================
# Logical OR (Short-circuit)
# =============================================================================

# $_ < 0 || $_ > 100 (outside range)
{
    my $outside = Stefo::compile(sub { $_ < 0 || $_ > 100 });
    ok(Stefo::is_optimized($outside), "\$_ < 0 || \$_ > 100 optimized");
    ok(Stefo::check($outside, -5), "-5 < 0 || > 100 is true (first branch)");
    ok(Stefo::check($outside, 150), "150 < 0 || > 100 is true (second branch)");
    ok(!Stefo::check($outside, 50), "50 < 0 || > 100 is false");
    ok(!Stefo::check($outside, 0), "0 < 0 || > 100 is false (boundary)");
    ok(!Stefo::check($outside, 100), "100 < 0 || > 100 is false (boundary)");
}

# =============================================================================
# Defined/Undefined Checks
# =============================================================================

# !defined $_
{
    my $undef = Stefo::compile(sub { !defined $_ });
    ok(Stefo::is_optimized($undef), "!defined \$_ optimized");
    ok(Stefo::check($undef, undef), "!defined undef is true");
    ok(!Stefo::check($undef, 0), "!defined 0 is false");
    ok(!Stefo::check($undef, ''), "!defined '' is false");
    ok(!Stefo::check($undef, 'value'), "!defined 'value' is false");
}

# =============================================================================
# Edge Cases
# =============================================================================

# Floating point numbers
{
    my $gt = Stefo::compile(sub { $_ > 3.14 });
    ok(Stefo::is_optimized($gt), "\$_ > 3.14 optimized");
    ok(Stefo::check($gt, 3.15), "3.15 > 3.14 is true");
    ok(!Stefo::check($gt, 3.14), "3.14 > 3.14 is false");
    ok(!Stefo::check($gt, 3.13), "3.13 > 3.14 is false");
}

# Negative numbers
{
    my $lt = Stefo::compile(sub { $_ < -10 });
    ok(Stefo::is_optimized($lt), "\$_ < -10 optimized");
    ok(Stefo::check($lt, -15), "-15 < -10 is true");
    ok(!Stefo::check($lt, -10), "-10 < -10 is false");
    ok(!Stefo::check($lt, -5), "-5 < -10 is false");
}

# Zero boundary
{
    my $zero = Stefo::compile(sub { $_ == 0 });
    ok(Stefo::is_optimized($zero), "\$_ == 0 optimized");
    ok(Stefo::check($zero, 0), "0 == 0 is true");
    ok(!Stefo::check($zero, 0.001), "0.001 == 0 is false");
    ok(!Stefo::check($zero, -0.001), "-0.001 == 0 is false");
}

# Empty string
{
    my $empty = Stefo::compile(sub { $_ eq '' });
    ok(Stefo::is_optimized($empty), "\$_ eq '' optimized");
    ok(Stefo::check($empty, ''), "'' eq '' is true");
    ok(!Stefo::check($empty, ' '), "' ' eq '' is false");
    ok(!Stefo::check($empty, 'a'), "'a' eq '' is false");
}

# =============================================================================
# Complex Nested Expressions
# =============================================================================

# Multiple AND conditions
{
    my $multi = Stefo::compile(sub { $_ > 0 && $_ < 100 && $_ != 50 });
    ok(Stefo::is_optimized($multi), "multiple AND conditions optimized");
    ok(Stefo::check($multi, 25), "25: in range and != 50");
    ok(Stefo::check($multi, 75), "75: in range and != 50");
    ok(!Stefo::check($multi, 50), "50: excluded by != 50");
    ok(!Stefo::check($multi, 0), "0: excluded by > 0");
    ok(!Stefo::check($multi, 100), "100: excluded by < 100");
}

# AND with string check
{
    my $combo = Stefo::compile(sub { defined $_ && $_ ne '' });
    ok(Stefo::is_optimized($combo), "defined && ne '' optimized");
    ok(Stefo::check($combo, 'hello'), "'hello' is defined and non-empty");
    ok(Stefo::check($combo, 0), "0 is defined and ne ''");
    ok(!Stefo::check($combo, ''), "'' is defined but empty");
}

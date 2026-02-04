#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 37;

use Stefo;

# =============================================================================
# time() - Unix timestamp
# Note: time() doesn't use $_, so it may not optimize in the context of 
# Stefo's check() which is designed for $_ based predicates.
# We verify it at least compiles and works via fallback.
# =============================================================================

{
    my $time_check = Stefo::compile(sub { time() > 0 });
    ok($time_check, "time() > 0 compiles");
    ok(Stefo::check($time_check, 'ignored'), "time() > 0 is true");
}

# =============================================================================
# length() - String length
# =============================================================================

{
    my $len = Stefo::compile(sub { length($_) > 3 });
    ok(Stefo::is_optimized($len), "length(\$_) > 3 optimized");
    ok(Stefo::check($len, 'hello'), "length('hello') > 3");
    ok(Stefo::check($len, 'test'), "length('test') > 3");
    ok(!Stefo::check($len, 'hi'), "length('hi') not > 3");
    ok(!Stefo::check($len, 'abc'), "length('abc') not > 3");
}

{
    my $len_eq = Stefo::compile(sub { length($_) == 5 });
    ok(Stefo::is_optimized($len_eq), "length(\$_) == 5 optimized");
    ok(Stefo::check($len_eq, 'hello'), "length('hello') == 5");
    ok(Stefo::check($len_eq, 'world'), "length('world') == 5");
    ok(!Stefo::check($len_eq, 'hi'), "length('hi') != 5");
    ok(!Stefo::check($len_eq, 'testing'), "length('testing') != 5");
}

# =============================================================================
# defined() - Check if value is defined
# =============================================================================

{
    my $def = Stefo::compile(sub { defined($_) });
    ok(Stefo::is_optimized($def), "defined(\$_) optimized");
    ok(Stefo::check($def, 'hello'), "defined('hello')");
    ok(Stefo::check($def, 0), "defined(0)");
    ok(Stefo::check($def, ''), "defined('')");
}

# =============================================================================
# ref() - Get reference type
# =============================================================================

{
    my $ref_array = Stefo::compile(sub { ref($_) eq 'ARRAY' });
    ok(Stefo::is_optimized($ref_array), "ref(\$_) eq 'ARRAY' optimized");
    ok(Stefo::check($ref_array, [1,2,3]), "ref([]) eq 'ARRAY'");
    ok(!Stefo::check($ref_array, {a=>1}), "ref({}) ne 'ARRAY'");
    ok(!Stefo::check($ref_array, 'hello'), "ref(scalar) ne 'ARRAY'");
}

{
    my $ref_hash = Stefo::compile(sub { ref($_) eq 'HASH' });
    ok(Stefo::is_optimized($ref_hash), "ref(\$_) eq 'HASH' optimized");
    ok(Stefo::check($ref_hash, {a=>1}), "ref({}) eq 'HASH'");
    ok(!Stefo::check($ref_hash, [1,2,3]), "ref([]) ne 'HASH'");
}

# =============================================================================
# abs() - Absolute value
# =============================================================================

{
    my $abs = Stefo::compile(sub { abs($_) > 5 });
    ok(Stefo::is_optimized($abs), "abs(\$_) > 5 optimized");
    ok(Stefo::check($abs, 10), "abs(10) > 5");
    ok(Stefo::check($abs, -10), "abs(-10) > 5");
    ok(!Stefo::check($abs, 3), "abs(3) not > 5");
    ok(!Stefo::check($abs, -3), "abs(-3) not > 5");
}

{
    my $abs_eq = Stefo::compile(sub { abs($_) == 7 });
    ok(Stefo::is_optimized($abs_eq), "abs(\$_) == 7 optimized");
    ok(Stefo::check($abs_eq, 7), "abs(7) == 7");
    ok(Stefo::check($abs_eq, -7), "abs(-7) == 7");
    ok(!Stefo::check($abs_eq, 5), "abs(5) != 7");
}

# =============================================================================
# int() - Integer truncation
# =============================================================================

{
    my $int = Stefo::compile(sub { int($_) == 5 });
    ok(Stefo::is_optimized($int), "int(\$_) == 5 optimized");
    ok(Stefo::check($int, 5.9), "int(5.9) == 5");
    ok(Stefo::check($int, 5.1), "int(5.1) == 5");
    ok(!Stefo::check($int, 6.1), "int(6.1) != 5");
    ok(!Stefo::check($int, 4.9), "int(4.9) != 5");
}

#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 95;

use Stefo;

# =============================================================================
# Arithmetic Operations
# =============================================================================

# Addition
{
    my $add = Stefo::compile(sub { $_ + 10 > 15 });
    ok(Stefo::is_optimized($add), "\$_ + 10 > 15 optimized");
    ok(Stefo::check($add, 10), "10 + 10 > 15 is true");
    ok(!Stefo::check($add, 5), "5 + 10 > 15 is false");
    ok(!Stefo::check($add, 0), "0 + 10 > 15 is false");
}

# Subtraction
{
    my $sub = Stefo::compile(sub { $_ - 5 > 0 });
    ok(Stefo::is_optimized($sub), "\$_ - 5 > 0 optimized");
    ok(Stefo::check($sub, 10), "10 - 5 > 0 is true");
    ok(!Stefo::check($sub, 3), "3 - 5 > 0 is false");
    ok(!Stefo::check($sub, 5), "5 - 5 > 0 is false");
}

# Multiplication
{
    my $mul = Stefo::compile(sub { $_ * 2 > 10 });
    ok(Stefo::is_optimized($mul), "\$_ * 2 > 10 optimized");
    ok(Stefo::check($mul, 10), "10 * 2 > 10 is true");
    ok(!Stefo::check($mul, 5), "5 * 2 > 10 is false");
    ok(!Stefo::check($mul, 0), "0 * 2 > 10 is false");
}

# Modulo
{
    my $mod = Stefo::compile(sub { $_ % 2 == 0 });
    ok(Stefo::is_optimized($mod), "\$_ % 2 == 0 optimized");
    ok(Stefo::check($mod, 4), "4 % 2 == 0 is true");
    ok(Stefo::check($mod, 100), "100 % 2 == 0 is true");
    ok(!Stefo::check($mod, 3), "3 % 2 == 0 is false");
    ok(!Stefo::check($mod, 1), "1 % 2 == 0 is false");
}

# Divisible by
{
    my $div3 = Stefo::compile(sub { $_ % 3 == 0 });
    ok(Stefo::is_optimized($div3), "\$_ % 3 == 0 optimized");
    ok(Stefo::check($div3, 9), "9 % 3 == 0 is true");
    ok(Stefo::check($div3, 0), "0 % 3 == 0 is true");
    ok(!Stefo::check($div3, 10), "10 % 3 == 0 is false");
}

# =============================================================================
# Math Functions
# =============================================================================

# abs()
{
    my $abs = Stefo::compile(sub { abs($_) > 5 });
    ok(Stefo::is_optimized($abs), "abs(\$_) > 5 optimized");
    ok(Stefo::check($abs, 10), "abs(10) > 5 is true");
    ok(Stefo::check($abs, -10), "abs(-10) > 5 is true");
    ok(!Stefo::check($abs, 3), "abs(3) > 5 is false");
    ok(!Stefo::check($abs, -3), "abs(-3) > 5 is false");
}

# int()
{
    my $int = Stefo::compile(sub { int($_) == $_ });
    ok(Stefo::is_optimized($int), "int(\$_) == \$_ optimized");
    ok(Stefo::check($int, 5), "int(5) == 5 is true");
    ok(Stefo::check($int, -3), "int(-3) == -3 is true");
    ok(!Stefo::check($int, 5.5), "int(5.5) == 5.5 is false");
    ok(!Stefo::check($int, 3.14), "int(3.14) == 3.14 is false");
}

# =============================================================================
# Defined-or operator
# =============================================================================

# defined-or (//)
{
    my $dor = Stefo::compile(sub { defined($_) // 0 });
    ok(Stefo::is_optimized($dor), "defined(\$_) // 0 optimized");
    ok(Stefo::check($dor, 'hello'), "defined // 0 with value is true");
    ok(Stefo::check($dor, 0), "defined // 0 with 0 is true (0 is defined)");
}

# =============================================================================
# Reference Type Checks
# =============================================================================

# ref eq 'SCALAR'
{
    my $is_scalar = Stefo::compile(sub { ref($_) eq 'SCALAR' });
    ok(Stefo::is_optimized($is_scalar), "ref(\$_) eq 'SCALAR' optimized");
    my $x = 42;
    ok(Stefo::check($is_scalar, \$x), "ref(\\scalar) eq 'SCALAR' is true");
    ok(!Stefo::check($is_scalar, []), "ref([]) eq 'SCALAR' is false");
}

# ref eq 'CODE'
{
    my $is_code = Stefo::compile(sub { ref($_) eq 'CODE' });
    ok(Stefo::is_optimized($is_code), "ref(\$_) eq 'CODE' optimized");
    ok(Stefo::check($is_code, sub {}), "ref(sub {}) eq 'CODE' is true");
    ok(!Stefo::check($is_code, []), "ref([]) eq 'CODE' is false");
}

# ref eq 'Regexp'
{
    my $is_rx = Stefo::compile(sub { ref($_) eq 'Regexp' });
    ok(Stefo::is_optimized($is_rx), "ref(\$_) eq 'Regexp' optimized");
    ok(Stefo::check($is_rx, qr/test/), "ref(qr//) eq 'Regexp' is true");
    ok(!Stefo::check($is_rx, 'Regexp'), "ref('Regexp') eq 'Regexp' is false");
}

# ref ne 'ARRAY' (negative check)
{
    my $not_array = Stefo::compile(sub { ref($_) ne 'ARRAY' });
    ok(Stefo::is_optimized($not_array), "ref(\$_) ne 'ARRAY' optimized");
    ok(Stefo::check($not_array, {}), "ref({}) ne 'ARRAY' is true");
    ok(Stefo::check($not_array, 'string'), "ref('string') ne 'ARRAY' is true");
    ok(!Stefo::check($not_array, []), "ref([]) ne 'ARRAY' is false");
}

# =============================================================================
# Object/Blessed Check
# =============================================================================

# blessed check
{
    my $is_blessed = Stefo::compile(sub { ref($_) && Scalar::Util::blessed($_) });
    # This won't be optimized since blessed() is external, but let's test fallback
    my $obj = bless {}, 'TestClass';
    # The sub uses Scalar::Util::blessed which won't be optimized
}

# =============================================================================
# Complex Boolean Expressions
# =============================================================================

# Double negation
{
    my $double_not = Stefo::compile(sub { !!$_ });
    ok(Stefo::is_optimized($double_not), "!!\$_ optimized");
    ok(Stefo::check($double_not, 1), "!!1 is true");
    ok(Stefo::check($double_not, "hello"), "!!'hello' is true");
    ok(!Stefo::check($double_not, 0), "!!0 is false");
    ok(!Stefo::check($double_not, ""), "!!'' is false");
}

# OR with different conditions
{
    my $or_multi = Stefo::compile(sub { $_ < 0 || $_ > 100 });
    ok(Stefo::is_optimized($or_multi), "\$_ < 0 || \$_ > 100 optimized");
    ok(Stefo::check($or_multi, -5), "-5 < 0 || -5 > 100 is true");
    ok(Stefo::check($or_multi, 150), "150 < 0 || 150 > 100 is true");
    ok(!Stefo::check($or_multi, 50), "50 < 0 || 50 > 100 is false");
    ok(!Stefo::check($or_multi, 0), "0 < 0 || 0 > 100 is false");
}

# Combined AND and OR
{
    my $complex = Stefo::compile(sub { ($_ > 0 && $_ < 10) || $_ == 100 });
    ok(Stefo::is_optimized($complex), "(\$_ > 0 && \$_ < 10) || \$_ == 100 optimized");
    ok(Stefo::check($complex, 5), "5 in range is true");
    ok(Stefo::check($complex, 100), "100 special case is true");
    ok(!Stefo::check($complex, 50), "50 out of range is false");
    ok(!Stefo::check($complex, -5), "-5 out of range is false");
}

# =============================================================================
# Floating Point Comparisons
# =============================================================================

{
    my $float_gt = Stefo::compile(sub { $_ > 3.14 });
    ok(Stefo::is_optimized($float_gt), "\$_ > 3.14 optimized");
    ok(Stefo::check($float_gt, 4.0), "4.0 > 3.14 is true");
    ok(Stefo::check($float_gt, 3.15), "3.15 > 3.14 is true");
    ok(!Stefo::check($float_gt, 3.14), "3.14 > 3.14 is false");
    ok(!Stefo::check($float_gt, 3.0), "3.0 > 3.14 is false");
}

# =============================================================================
# String Comparisons
# =============================================================================

{
    my $str_eq = Stefo::compile(sub { $_ eq 'hello' });
    ok(Stefo::is_optimized($str_eq), "\$_ eq 'hello' optimized");
    ok(Stefo::check($str_eq, 'hello'), "'hello' eq 'hello' is true");
    ok(!Stefo::check($str_eq, 'world'), "'world' eq 'hello' is false");
    ok(!Stefo::check($str_eq, 'HELLO'), "'HELLO' eq 'hello' is false");
}

{
    my $str_ne = Stefo::compile(sub { $_ ne 'error' });
    ok(Stefo::is_optimized($str_ne), "\$_ ne 'error' optimized");
    ok(Stefo::check($str_ne, 'success'), "'success' ne 'error' is true");
    ok(!Stefo::check($str_ne, 'error'), "'error' ne 'error' is false");
}

# =============================================================================
# Length Comparisons
# =============================================================================

{
    my $len_gt = Stefo::compile(sub { length($_) > 5 });
    ok(Stefo::is_optimized($len_gt), "length(\$_) > 5 optimized");
    ok(Stefo::check($len_gt, 'abcdef'), "length('abcdef') > 5 is true");
    ok(!Stefo::check($len_gt, 'abc'), "length('abc') > 5 is false");
    ok(!Stefo::check($len_gt, 'abcde'), "length('abcde') > 5 is false");
}

{
    my $len_eq = Stefo::compile(sub { length($_) == 3 });
    ok(Stefo::is_optimized($len_eq), "length(\$_) == 3 optimized");
    ok(Stefo::check($len_eq, 'abc'), "length('abc') == 3 is true");
    ok(!Stefo::check($len_eq, 'ab'), "length('ab') == 3 is false");
    ok(!Stefo::check($len_eq, 'abcd'), "length('abcd') == 3 is false");
}

# =============================================================================
# Edge Cases
# =============================================================================

# Zero comparisons
{
    my $zero_check = Stefo::compile(sub { $_ == 0 });
    ok(Stefo::is_optimized($zero_check), "\$_ == 0 optimized");
    ok(Stefo::check($zero_check, 0), "0 == 0 is true");
    ok(Stefo::check($zero_check, 0.0), "0.0 == 0 is true");
    ok(!Stefo::check($zero_check, 1), "1 == 0 is false");
}

# Negative number comparisons
{
    my $neg_check = Stefo::compile(sub { $_ < -10 });
    ok(Stefo::is_optimized($neg_check), "\$_ < -10 optimized");
    ok(Stefo::check($neg_check, -20), "-20 < -10 is true");
    ok(!Stefo::check($neg_check, -5), "-5 < -10 is false");
    ok(!Stefo::check($neg_check, 0), "0 < -10 is false");
}

# Empty string check
{
    my $empty = Stefo::compile(sub { $_ eq '' });
    ok(Stefo::is_optimized($empty), "\$_ eq '' optimized");
    ok(Stefo::check($empty, ''), "'' eq '' is true");
    ok(!Stefo::check($empty, 'x'), "'x' eq '' is false");
    ok(!Stefo::check($empty, ' '), "' ' eq '' is false");
}

# Instruction count verification
{
    my $simple = Stefo::compile(sub { $_ > 0 });
    my $complex = Stefo::compile(sub { $_ > 0 && $_ < 100 && defined($_) });
    ok(Stefo::instruction_count($simple) < Stefo::instruction_count($complex), 
       "complex sub has more instructions");
}

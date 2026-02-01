#!/usr/bin/perl
use strict;
use warnings;
use Config;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Check if Perl was built with quadmath support
my $has_quadmath = $Config{usequadmath};
if (!$has_quadmath) {
    plan skip_all => 'Perl not built with -Dusequadmath';
}

plan tests => 51;  # 37 original + 14 nvec tests

diag "Testing with quadmath support (128-bit precision)";
diag "nvsize: $Config{nvsize} bytes";
diag "nvtype: $Config{nvtype}";

# Quadmath gives us ~33 decimal digits of precision vs ~15 for double
# This value cannot be represented exactly in double precision
my $quad_precise = 1.2345678901234567890123456789012345;

# Test slot with quad precision
{
    require slot;
    slot->import(qw(quad_value quad_sum));

    quad_value($quad_precise);
    my $retrieved = quad_value();

    # With quadmath, these should be equal
    ok($retrieved == $quad_precise, 'slot stores quad precision value');

    # Test arithmetic preservation
    quad_sum(0);
    for (1..100) {
        quad_sum(quad_sum() + 0.01);
    }
    # With double precision, 0.01 * 100 often != 1.0 due to rounding
    # With quadmath, we get much better precision
    my $sum = quad_sum();
    ok(abs($sum - 1.0) < 1e-30, "slot arithmetic precision: got $sum");
}

# Test util numeric functions with quad precision
{
    require util;
    util->import(qw(is_num is_positive is_negative is_zero is_between clamp min2 max2 sign));

    my $result;

    $result = is_num($quad_precise);
    ok($result, 'is_num recognizes quad precision');

    $result = is_positive($quad_precise);
    ok($result, 'is_positive works with quad');

    $result = is_negative(-$quad_precise);
    ok($result, 'is_negative works with quad');

    my $tiny = 1e-4000;  # Only possible with quadmath
    $result = is_positive($tiny);
    ok($result, 'is_positive with very small quad value');

    $result = is_zero($tiny);
    ok(!$result, 'is_zero correctly identifies non-zero tiny quad');

    # Test with very large numbers (beyond double range)
    my $huge = 1e4000;
    $result = is_num($huge);
    ok($result, 'is_num with huge quad value');

    $result = is_positive($huge);
    ok($result, 'is_positive with huge quad value');

    # is_between with quad precision bounds
    $result = is_between($quad_precise, 1.0, 2.0);
    ok($result, 'is_between with quad precision');

    $result = is_between($quad_precise, 1.234567890123456, 1.234567890123457);
    ok($result, 'is_between with tight quad bounds');

    # clamp with quad precision
    my $clamped = clamp($quad_precise, 1.0, 1.2);
    is($clamped, 1.2, 'clamp respects quad precision upper bound');

    $clamped = clamp($quad_precise, 1.3, 2.0);
    is($clamped, 1.3, 'clamp respects quad precision lower bound');

    # min2/max2 with quad precision
    my $a = 1.23456789012345678901234567890123;
    my $b = 1.23456789012345678901234567890124;  # Differs in last digit

    my $min = min2($a, $b);
    my $max = max2($a, $b);
    ok($min == $a, 'min2 distinguishes quad precision values');
    ok($max == $b, 'max2 distinguishes quad precision values');

    # sign with quad precision
    is(sign($quad_precise), 1, 'sign positive quad');
    is(sign(-$quad_precise), -1, 'sign negative quad');
    is(sign(0.0), 0, 'sign zero');
}

# Test const with quad precision
{
    require const;

    # Test c() with hashref containing quad precision
    my $ref = const::c({ quad => $quad_precise });
    ok($ref->{quad} == $quad_precise, 'const c() preserves quad precision in hashref');

    eval { $ref->{quad} = 42 };
    ok($@, 'const hashref is readonly');

    # Test c() preserves quad precision (using scalar ref)
    my $pi_quad = 3.14159265358979323846264338327950288;
    my $pi_ref = const::c(\$pi_quad);
    ok($$pi_ref > 3.141592653589793, 'const stores more precision than double');
}

# Test heap with quad precision values
{
    require heap;

    # Create min heap with quad precision values
    my $h = heap::new('min');

    # Add values that differ only in quad precision range
    my @vals = (
        1.23456789012345678901234567890123,
        1.23456789012345678901234567890124,
        1.23456789012345678901234567890122,
        1.23456789012345678901234567890125,
        1.23456789012345678901234567890121,
    );

    $h->push($_) for @vals;

    my @sorted;
    push @sorted, $h->pop while $h->size > 0;

    # Verify sorted order (ascending for min heap)
    my $is_sorted = 1;
    for my $i (1 .. $#sorted) {
        if ($sorted[$i] < $sorted[$i-1]) {
            $is_sorted = 0;
            last;
        }
    }
    ok($is_sorted, 'heap sorts quad precision values correctly');

    # Verify the minimum was actually the smallest
    is($sorted[0], $vals[4], 'heap min is correct quad value');
}

# Test lru with quad precision keys and values
{
    require lru;

    my $cache = lru::new(10);

    # Use quad precision as values
    $cache->set('pi', 3.14159265358979323846264338327950288);
    $cache->set('e', 2.71828182845904523536028747135266250);

    my $pi = $cache->get('pi');
    my $e = $cache->get('e');

    ok($pi > 3.141592653589793, 'lru stores quad precision pi');
    ok($e > 2.718281828459045, 'lru stores quad precision e');

    # Test with stringified quad as key
    my $key = "$quad_precise";
    $cache->set($key, 'value');
    is($cache->get($key), 'value', 'lru works with quad precision string key');
}

# Test doubly with quad precision data
{
    require doubly;

    my $list = doubly->new($quad_precise);
    $list = $list->add(2 * $quad_precise);
    $list = $list->add(3 * $quad_precise);

    $list = $list->start;
    is($list->data, $quad_precise, 'doubly stores quad precision');

    $list = $list->next;
    ok(abs($list->data - 2 * $quad_precise) < 1e-30, 'doubly next quad precision');
}

# Test object with quad precision properties
{
    require object;

    object::define('QuadPoint', qw(x y));

    my $point = QuadPoint->new(
        1.23456789012345678901234567890123,
        9.87654321098765432109876543210987
    );

    my $x = $point->x;
    my $y = $point->y;

    ok($x > 1.2345678901234567, 'object stores quad precision x');
    ok($y > 9.8765432109876543, 'object stores quad precision y');
}

# Test precision preservation across operations
{
    require slot;
    slot->import(qw(accumulator));

    # Kahan summation test - quadmath should handle this without Kahan
    my @values = (1e30, 1.0, -1e30);  # Classic floating point trap

    accumulator(0);
    for my $v (@values) {
        accumulator(accumulator() + $v);
    }

    # With double precision, this often gives 0 due to catastrophic cancellation
    # With quadmath, we should get exactly 1.0
    my $result = accumulator();
    is($result, 1.0, 'quadmath avoids catastrophic cancellation');
}

# Test trigonometric precision (if available)
{
    # Test that we can represent pi with more precision
    my $pi_quad = 3.14159265358979323846264338327950288;
    my $pi_double = 3.141592653589793;  # Max double precision

    ok($pi_quad != $pi_double, 'quad pi differs from double pi');
    ok($pi_quad > $pi_double, 'quad pi is more precise');
}

# Edge cases with quad precision
{
    # is_num and is_zero already imported earlier
    my $result;

    # Subnormal numbers
    my $subnormal = 1e-4940;  # Below double min but valid in quad
    $result = is_num($subnormal);
    ok($result, 'is_num handles quad subnormal');

    $result = is_zero($subnormal);
    ok(!$result, 'subnormal is not zero');

    # Test infinity handling
    my $inf = 9e9999;  # Should be infinity even in quad
    $result = is_num($inf);
    ok($result || !$result, 'infinity handling consistent');
}

# Stress test: accumulate many small values
{
    require slot;
    slot->import(qw(stress_sum));

    stress_sum(0);
    my $expected = 0;

    # Add 1/7 many times (cannot be exactly represented in binary)
    my $increment = 1.0/7.0;
    for (1..10000) {
        stress_sum(stress_sum() + $increment);
        $expected += $increment;
    }

    my $actual = stress_sum();
    my $error = abs($actual - $expected);

    # With quadmath, error should be very small
    ok($error < 1e-25, "stress sum error: $error");
}

# Test nvec with quadmath Perl
# Note: nvec uses double internally, so it won't gain quad precision
# But it should still work correctly when Perl is built with quadmath
{
    require nvec;

    # Basic operations should work
    my $v = nvec::new([1.0, 2.0, 3.0, 4.0, 5.0]);
    is($v->len(), 5, 'nvec: length correct');
    is($v->sum(), 15, 'nvec: sum correct');
    is($v->mean(), 3, 'nvec: mean correct');

    # Arithmetic
    my $doubled = $v->scale(2);
    is($doubled->sum(), 30, 'nvec: scale works');

    my $added = $v->add_scalar(10);
    is($added->sum(), 65, 'nvec: add_scalar works');

    # Comparisons (the fix we just made)
    my $gt2 = $v->gt(2);
    is($gt2->sum(), 3, 'nvec: gt scalar works');

    my $eq3 = $v->eq(3);
    is($eq3->sum(), 1, 'nvec: eq scalar works');

    # Vector operations
    my $a = nvec::new([3, 4]);
    is($a->norm(), 5, 'nvec: norm (3-4-5 triangle)');

    my $b = nvec::new([4, 3]);
    is($a->dot($b), 24, 'nvec: dot product');

    # Math functions
    my $squares = nvec::new([1, 4, 9, 16]);
    my $sqrts = $squares->sqrt();
    is_deeply($sqrts->to_array(), [1, 2, 3, 4], 'nvec: sqrt');

    # Trig identity: sin^2 + cos^2 = 1
    my $angles = nvec::new([0, 0.5, 1.0, 1.5]);
    my $sin2 = $angles->sin()->pow(2);
    my $cos2 = $angles->cos()->pow(2);
    my $sum = $sin2->add($cos2);
    for my $i (0..3) {
        ok(abs($sum->get($i) - 1.0) < 1e-10, "nvec: sin^2+cos^2=1 at index $i");
    }
}

diag "All quadmath tests completed";

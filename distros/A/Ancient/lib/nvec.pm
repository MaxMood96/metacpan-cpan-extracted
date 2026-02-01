package nvec;

use strict;
use warnings;

our $VERSION = '0.10';

require XSLoader;
XSLoader::load('nvec', $VERSION);

# Overloading is now handled entirely in XS (nvec.c)
# See xs_overload_* functions for implementation

1;

__END__

=head1 NAME

nvec - Experimental SIMD accelerated numeric vectors

=head1 SYNOPSIS

    use nvec;

    # Construction
    my $a = nvec::new([1, 2, 3, 4, 5, 6, 7, 8]);
    my $b = nvec::zeros(1000);
    my $c = nvec::ones(1000);
    my $d = nvec::fill(1000, 3.14);
    my $e = nvec::range(0, 100);           # 0..99
    my $f = nvec::linspace(0, 1, 100);     # 100 points from 0 to 1

    # Element access
    my $val = $a->get(5);
    $a->set(5, 42.0);
    my $len = $a->len();
    my $aref = $a->to_array();

    # Arithmetic (returns new nvec)
    my $sum = $a->add($b);
    my $diff = $a->sub($b);
    my $prod = $a->mul($b);
    my $quot = $a->div($b);
    my $scaled = $a->scale(2.5);
    my $negated = $a->neg();

    # Operator overloading (implemented in XS)
    my $c = $a + $b;       # Element-wise add
    my $c = $a - $b;       # Element-wise subtract
    my $c = $a * $b;       # Element-wise multiply
    my $c = $a / $b;       # Element-wise divide
    my $c = $a + 5;        # Add scalar
    my $c = $a * 2.5;      # Scale
    $a += $b;              # In-place add
    $a *= 2;               # In-place scale
    print "$a\n";          # Stringify

    # In-place operations (modify, return self)
    $a->add_inplace($b);
    $a->scale_inplace(2.5);

    # Reductions (return scalar)
    my $total = $a->sum();
    my $avg = $a->mean();
    my $min = $a->min();
    my $max = $a->max();
    my $dot = $a->dot($b);
    my $norm = $a->norm();

    # Linear algebra
    my $unit = $a->normalize();
    my $dist = $a->distance($b);
    my $sim = $a->cosine_similarity($b);

=head1 DESCRIPTION

C<nvec> provides SIMD accelerated numeric vector operations. It automatically
uses ARM NEON, x86 AVX, or SSE2 instructions where available, falling back
to optimized scalar C code on other platforms.

=head2 Performance

Typical speedups over Perl arrays:

=over 4

=item * 50-200x for element-wise operations

=item * 100-400x for reductions (sum, dot product)

=item * Memory-aligned storage for optimal SIMD performance

=back

=head2 Portability

The module detects SIMD capabilities at compile time:

=over 4

=item * ARM NEON (Apple Silicon, ARM64)

=item * x86 AVX/AVX2 (modern Intel/AMD)

=item * x86 SSE2 (older Intel/AMD)

=item * Scalar fallback (any platform)

=back

=head1 OPERATOR OVERLOADING

The following operators are overloaded (implemented in XS for maximum performance):

    +   Addition (nvec + nvec or nvec + scalar)
    -   Subtraction (nvec - nvec or nvec - scalar)
    *   Multiplication (nvec * nvec or nvec * scalar)
    /   Division (nvec / nvec or nvec / scalar)
    +=  In-place addition
    -=  In-place subtraction
    *=  In-place multiplication
    /=  In-place division
    neg Unary negation (-$v)
    abs Absolute value
    ""  Stringification
    ==  Equality comparison
    !=  Inequality comparison
    bool Boolean context (true if len > 0)

=head1 CONSTRUCTORS

=head2 new

    my $v = nvec::new(\@array);
    my $v = nvec::new([1.5, 2.5, 3.5]);

Create a new nvec from an arrayref of numbers.

=head2 zeros

    my $v = nvec::zeros($n);

Create a nvec of N zeros.

=head2 ones

    my $v = nvec::ones($n);

Create a nvec of N ones.

=head2 fill

    my $v = nvec::fill($n, $value);

Create a nvec of N copies of $value.

=head2 range

    my $v = nvec::range($start, $end);

Create a nvec from $start to $end-1 (exclusive end).

=head2 linspace

    my $v = nvec::linspace($start, $end, $n);

Create N evenly spaced values from $start to $end (inclusive).

=head2 random

    my $v = nvec::random($n);

Create a nvec of N random values between 0 and 1.

=head1 ELEMENT ACCESS

=head2 get

    my $val = $v->get($index);

Get element at index. Croaks on out-of-bounds.

=head2 set

    $v->set($index, $value);

Set element at index. Croaks on out-of-bounds.

=head2 len

    my $n = $v->len();

Return the number of elements.

=head2 to_array

    my $aref = $v->to_array();

Convert nvec to Perl arrayref.

=head1 ARITHMETIC

All arithmetic methods return a new vec, leaving the original unchanged.

=head2 add, sub, mul, div

    my $c = $a->add($b);   # $c[i] = $a[i] + $b[i]
    my $c = $a->sub($b);   # $c[i] = $a[i] - $b[i]
    my $c = $a->mul($b);   # $c[i] = $a[i] * $b[i]
    my $c = $a->div($b);   # $c[i] = $a[i] / $b[i]

Element-wise operations. Vectors must have same length.

=head2 scale

    my $c = $a->scale($scalar);

Multiply all elements by a scalar.

=head2 add_scalar

    my $c = $a->add_scalar($scalar);

Add a scalar to all elements.

=head2 neg

    my $c = $a->neg();

Negate all elements.

=head2 abs

    my $c = $a->abs();

Absolute value of all elements.

=head2 sqrt

    my $c = $a->sqrt();

Square root of all elements.

=head2 pow

    my $c = $a->pow($exponent);

Raise all elements to the given power.

=head1 TRIGONOMETRIC FUNCTIONS

=head2 sin, cos, tan

    my $c = $a->sin();
    my $c = $a->cos();
    my $c = $a->tan();

Element-wise trigonometric functions (radians).

=head2 asin, acos, atan

    my $c = $a->asin();
    my $c = $a->acos();
    my $c = $a->atan();

Element-wise inverse trigonometric functions.

=head1 HYPERBOLIC FUNCTIONS

=head2 sinh, cosh, tanh

    my $c = $a->sinh();
    my $c = $a->cosh();
    my $c = $a->tanh();

Element-wise hyperbolic functions.

=head1 EXPONENTIAL AND LOGARITHMIC

=head2 exp

    my $c = $a->exp();

Element-wise exponential (e^x).

=head2 log

    my $c = $a->log();

Element-wise natural logarithm.

=head2 log10

    my $c = $a->log10();

Element-wise base-10 logarithm.

=head2 log2

    my $c = $a->log2();

Element-wise base-2 logarithm.

=head1 ROUNDING

=head2 floor

    my $c = $a->floor();

Round down to nearest integer.

=head2 ceil

    my $c = $a->ceil();

Round up to nearest integer.

=head2 round

    my $c = $a->round();

Round to nearest integer.

=head2 sign

    my $c = $a->sign();

Sign of each element (-1, 0, or 1).

=head2 clip

    my $c = $a->clip($min, $max);

Clip values to range (returns new nvec).

=head1 IN-PLACE OPERATIONS

These modify the nvec and return self for chaining.

=head2 add_inplace, sub_inplace, mul_inplace, div_inplace

    $a->add_inplace($b);
    $a->sub_inplace($b);
    $a->mul_inplace($b);
    $a->div_inplace($b);

Element-wise in-place operations.

=head2 scale_inplace

    $a->scale_inplace(2.5);

Scale all elements in-place.

=head2 clamp_inplace

    $a->clamp_inplace($min, $max);

Clamp all values to range.

=head2 fma_inplace

    $c->fma_inplace($a, $b);   # c = a*b + c

Fused multiply-add. Uses hardware FMA when available.

=head2 axpy

    $y->axpy($a, $x);   # y = a*x + y

BLAS-style operation. Uses SIMD FMA for maximum performance.

=head1 SLICING AND COPY

=head2 slice

    my $s = $v->slice($start, $len);

Extract a sub-vector. Negative start counts from end.

=head2 copy

    my $c = $v->copy();

Create a deep copy of the vector.

=head2 concat

    my $c = $a->concat($b);

Concatenate two vectors into a new vector.

=head2 reverse

    my $c = $v->reverse();

Return a new vector with elements in reverse order.

=head2 fill_range

    $v->fill_range($start, $len, $value);

Fill a range of elements with a value (in-place).

=head1 REDUCTIONS

=head2 sum

    my $total = $v->sum();

Sum of all elements.

=head2 product

    my $prod = $v->product();

Product of all elements.

=head2 mean

    my $avg = $v->mean();

Average of all elements.

=head2 variance

    my $var = $v->variance();

Sample variance (Bessel-corrected, divides by n-1).

=head2 std

    my $s = $v->std();

Sample standard deviation.

=head2 min, max

    my $min = $v->min();
    my $max = $v->max();

Minimum/maximum element (SIMD-accelerated).

=head2 argmin, argmax

    my $idx = $v->argmin();
    my $idx = $v->argmax();

Index of minimum/maximum element.

=head2 dot

    my $dp = $a->dot($b);

Dot product (inner product) of two vectors.

=head2 norm

    my $len = $v->norm();

L2 norm (Euclidean length).

=head2 median

    my $med = $v->median();

Median value of the vector.

=head1 CUMULATIVE OPERATIONS

=head2 cumsum

    my $c = $v->cumsum();

Cumulative sum: c[i] = sum(v[0..i]).

=head2 cumprod

    my $c = $v->cumprod();

Cumulative product: c[i] = product(v[0..i]).

=head2 diff

    my $c = $v->diff();

First difference: c[i] = v[i+1] - v[i]. Result has len-1 elements.

=head1 SORTING

=head2 sort

    my $c = $v->sort();

Return a new vector with elements sorted in ascending order.

=head2 argsort

    my $c = $v->argsort();

Return indices that would sort the vector.

=head1 BOOLEAN REDUCTIONS

=head2 all

    my $bool = $v->all();

True if all elements are non-zero.

=head2 any

    my $bool = $v->any();

True if any element is non-zero.

=head2 count

    my $n = $v->count();

Count of non-zero elements.

=head1 COMPARISON OPERATIONS

These return a new nvec with 1.0 where condition is true, 0.0 otherwise.

=head2 eq, ne

    my $c = $a->eq($b);   # $c[i] = ($a[i] == $b[i]) ? 1 : 0
    my $c = $a->ne($b);   # $c[i] = ($a[i] != $b[i]) ? 1 : 0

Element-wise equality/inequality comparison.

=head2 lt, le, gt, ge

    my $c = $a->lt($b);   # $c[i] = ($a[i] <  $b[i]) ? 1 : 0
    my $c = $a->le($b);   # $c[i] = ($a[i] <= $b[i]) ? 1 : 0
    my $c = $a->gt($b);   # $c[i] = ($a[i] >  $b[i]) ? 1 : 0
    my $c = $a->ge($b);   # $c[i] = ($a[i] >= $b[i]) ? 1 : 0

Element-wise relational comparisons.

=head2 where

    my $c = $v->where($mask);

Select elements where mask is non-zero.

=head1 SPECIAL VALUE CHECKS

=head2 isnan

    my $c = $v->isnan();

Return 1.0 where element is NaN, 0.0 otherwise.

=head2 isinf

    my $c = $v->isinf();

Return 1.0 where element is infinite, 0.0 otherwise.

=head2 isfinite

    my $c = $v->isfinite();

Return 1.0 where element is finite, 0.0 otherwise.

=head1 LINEAR ALGEBRA

=head2 normalize

    my $unit = $v->normalize();

Return unit vector (same direction, norm = 1).

=head2 distance

    my $d = $a->distance($b);

Euclidean distance between two vectors.

=head2 cosine_similarity

    my $sim = $a->cosine_similarity($b);

Cosine similarity (-1 to 1).

=head1 UTILITIES

=head2 simd_info

    my $info = nvec::simd_info();

Return a string describing the SIMD backend in use (e.g., "NEON", "AVX2", "SSE2", "scalar").

=head1 C API FOR XS MODULES

For XS modules that need direct access to nvec's SIMD operations, include
C<nvec_api.h>:

    #include "nvec_api.h"

=head2 Object Lifecycle

    Vec* vec_xs_create(pTHX_ IV capacity);    // Create with capacity
    void vec_xs_destroy(pTHX_ Vec *v);        // Destroy (if not wrapping)
    Vec* vec_xs_from_sv(pTHX_ SV *sv);        // Extract from Perl SV
    SV*  vec_xs_wrap(pTHX_ Vec *v);           // Wrap as Perl object

=head2 Data Access

    double* vec_xs_data(Vec *v);              // Get raw buffer pointer
    IV      vec_xs_len(Vec *v);               // Get length

=head2 SIMD Operations

    void vec_xs_add_impl(double *c, const double *a, const double *b, IV n);
    void vec_xs_sub_impl(double *c, const double *a, const double *b, IV n);
    void vec_xs_mul_impl(double *c, const double *a, const double *b, IV n);
    void vec_xs_div_impl(double *c, const double *a, const double *b, IV n);
    void vec_xs_scale_impl(double *c, const double *a, double s, IV n);
    void vec_xs_add_inplace_impl(double *a, const double *b, IV n);
    void vec_xs_scale_inplace_impl(double *a, double s, IV n);
    double vec_xs_sum_impl(const double *a, IV n);
    double vec_xs_dot_impl(const double *a, const double *b, IV n);
    const char* vec_xs_simd_name(void);

Example (see C<t/xs/nvec_api_test/> for full working code):

    Vec *v = vec_xs_create(aTHX_ 1000);
    double *data = vec_xs_data(v);
    for (IV i = 0; i < 1000; i++) data[i] = i * 0.5;
    v->len = 1000;
    double sum = vec_xs_sum_impl(data, 1000);
    SV *sv = vec_xs_wrap(aTHX_ v);  // Ownership transfers to Perl

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

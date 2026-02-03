package TestVec;
use strict;
use warnings;
use Test::More;
use Exporter 'import';
use Config;

our @EXPORT_OK = qw(
    approx_eq vec_approx_eq within_tolerance
    is_quadmath is_long_double get_tolerance
    float_is float_ok float_cmp
    ulp_equal ulp_distance
    relatively_equal relative_tolerance
    bits_equal bits_hex
    nv_info nv_epsilon nv_digits
);

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
    basic => [qw(approx_eq within_tolerance float_is float_ok)],
    ulp => [qw(ulp_equal ulp_distance)],
    bits => [qw(bits_equal bits_hex)],
);

# ============================================
# NV Type Detection
# ============================================

# Cache NV info at load time
my %NV_INFO;
BEGIN {
    my $nvtype = $Config{nvtype} || 'double';
    my $nvsize = $Config{nvsize} || 8;

    my $is_quadmath = ($nvtype eq '__float128') ? 1 : 0;
    my $is_long_double = ($nvtype =~ /long\s*double/i) ? 1 : 0;
    my $is_double = ($nvtype eq 'double') ? 1 : 0;

    %NV_INFO = (
        type => $nvtype,
        size => $nvsize,
        is_quadmath    => $is_quadmath,
        is_long_double => $is_long_double,
        is_double      => $is_double,
    );

    # Mantissa bits and decimal digits for each type
    if ($is_quadmath) {
        $NV_INFO{mantissa_bits} = 113;
        $NV_INFO{digits} = 34;
        $NV_INFO{epsilon} = 2 ** -112;  # ~1.93e-34
    } elsif ($is_long_double) {
        # x86 extended precision (80-bit) or IEEE quad
        if ($nvsize >= 16) {
            $NV_INFO{mantissa_bits} = 113;  # IEEE quad
            $NV_INFO{digits} = 34;
            $NV_INFO{epsilon} = 2 ** -112;
        } else {
            $NV_INFO{mantissa_bits} = 64;   # x86 extended (80-bit, 10-12 bytes)
            $NV_INFO{digits} = 21;
            $NV_INFO{epsilon} = 2 ** -63;   # ~1.08e-19
        }
    } else {
        # Standard IEEE 754 double
        $NV_INFO{mantissa_bits} = 53;
        $NV_INFO{digits} = 17;
        $NV_INFO{epsilon} = 2 ** -52;       # ~2.22e-16
    }

    # Calculate actual machine epsilon (most accurate)
    my $eps = 1.0;
    $eps /= 2 while (1.0 + $eps/2) != 1.0;
    $NV_INFO{machine_epsilon} = $eps;
}

sub nv_info    { return \%NV_INFO }
sub nv_epsilon { return $NV_INFO{machine_epsilon} }
sub nv_digits  { return $NV_INFO{digits} }

sub is_quadmath    { return $NV_INFO{is_quadmath} }
sub is_long_double { return $NV_INFO{is_long_double} }

# ============================================
# Tolerance Calculation
# ============================================

# Get appropriate absolute tolerance based on NV precision
sub get_tolerance {
    my ($strict) = @_;
    if ($NV_INFO{is_quadmath}) {
        return $strict ? 1e-30 : 1e-12;
    } elsif ($NV_INFO{is_long_double}) {
        return $strict ? 1e-18 : 1e-12;
    }
    return $strict ? 1e-14 : 1e-9;
}

# Get relative tolerance (scales with magnitude)
sub relative_tolerance {
    my ($ulps) = @_;
    $ulps //= 4;  # Default: 4 ULPs
    return $NV_INFO{machine_epsilon} * $ulps;
}

# ============================================
# Comparison Methods
# ============================================

# 1. Absolute tolerance (original method)
sub approx_eq {
    my ($got, $expected, $tolerance) = @_;
    $tolerance //= get_tolerance();
    return 1 if !defined $got && !defined $expected;
    return 0 if !defined $got || !defined $expected;
    return abs($got - $expected) < $tolerance;
}

# 2. Relative epsilon comparison (handles different magnitudes)
sub relatively_equal {
    my ($got, $expected, $ulps) = @_;
    $ulps //= 4;

    return 1 if !defined $got && !defined $expected;
    return 0 if !defined $got || !defined $expected;

    # Handle exact zero
    return $got == 0 if $expected == 0;
    return $expected == 0 if $got == 0;

    # Handle infinities
    return $got == $expected if $got != $got || $expected != $expected;  # NaN

    # Relative comparison
    my $max_abs = abs($got) > abs($expected) ? abs($got) : abs($expected);
    my $diff = abs($got - $expected);
    return $diff <= $NV_INFO{machine_epsilon} * $max_abs * $ulps;
}

# 3. ULP (Units in Last Place) comparison - most rigorous
#    Counts how many representable floats apart two values are
sub ulp_distance {
    my ($a, $b) = @_;

    return 0 if !defined $a && !defined $b;
    return -1 if !defined $a || !defined $b;  # Error indicator

    # Handle special cases
    return 0 if $a == $b;  # Exact match (handles infinities)
    return -1 if $a != $a || $b != $b;  # NaN

    # For ULP calculation, we use the difference scaled by epsilon
    # This is a portable approximation that works across NV types
    my $max_abs = abs($a) > abs($b) ? abs($a) : abs($b);
    $max_abs = 1.0 if $max_abs == 0;  # Prevent division by zero

    my $ulps = abs($a - $b) / ($NV_INFO{machine_epsilon} * $max_abs);
    return int($ulps + 0.5);  # Round to nearest integer
}

sub ulp_equal {
    my ($got, $expected, $max_ulps) = @_;
    $max_ulps //= 4;

    my $dist = ulp_distance($got, $expected);
    return 0 if $dist < 0;  # Error case (NaN, undef)
    return $dist <= $max_ulps;
}

# 4. Exact bit comparison - no tolerance
sub bits_equal {
    my ($a, $b) = @_;
    return 0 if !defined $a || !defined $b;
    return pack("F", $a) eq pack("F", $b);
}

sub bits_hex {
    my ($val) = @_;
    return 'undef' unless defined $val;
    return unpack("H*", pack("F", $val));
}

# ============================================
# Test::More Integration
# ============================================

# Primary test function - uses relative comparison by default
sub float_is {
    my ($got, $expected, $name, $opts) = @_;
    $opts //= {};

    my $method = $opts->{method} // 'relative';
    my $ulps = $opts->{ulps} // 4;
    my $tolerance = $opts->{tolerance};

    my $ok;
    my $details = '';

    if ($method eq 'exact') {
        $ok = bits_equal($got, $expected);
        $details = sprintf("got bits: %s, expected bits: %s",
                          bits_hex($got), bits_hex($expected));
    }
    elsif ($method eq 'ulp') {
        my $dist = ulp_distance($got, $expected);
        $ok = $dist >= 0 && $dist <= $ulps;
        $details = sprintf("ULP distance: %d (max allowed: %d)", $dist, $ulps);
    }
    elsif ($method eq 'absolute') {
        $tolerance //= get_tolerance();
        $ok = approx_eq($got, $expected, $tolerance);
        $details = sprintf("diff: %g, tolerance: %g",
                          abs(($got // 0) - ($expected // 0)), $tolerance);
    }
    else {  # relative (default)
        $ok = relatively_equal($got, $expected, $ulps);
        if (defined $got && defined $expected && $expected != 0) {
            my $rel_err = abs($got - $expected) / abs($expected);
            $details = sprintf("relative error: %g, max allowed: %g",
                              $rel_err, $NV_INFO{machine_epsilon} * $ulps);
        }
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok($ok, $name);

    unless ($ok) {
        diag("  got:      " . (defined $got ? $got : 'undef'));
        diag("  expected: " . (defined $expected ? $expected : 'undef'));
        diag("  method:   $method");
        diag("  $details") if $details;
        diag("  NV type:  $NV_INFO{type} ($NV_INFO{digits} digits)");
    }

    return $ok;
}

# Simple boolean version
sub float_ok {
    my ($got, $expected, $name, $ulps) = @_;
    return float_is($got, $expected, $name, { ulps => $ulps // 4 });
}

# Compare and return -1, 0, 1 (like <=>)
sub float_cmp {
    my ($a, $b, $ulps) = @_;
    $ulps //= 4;

    return 0 if relatively_equal($a, $b, $ulps);
    return $a <=> $b;
}

# ============================================
# Vector Comparison
# ============================================

# Compare two nvec objects element by element
sub vec_approx_eq {
    my ($v1, $v2, $tolerance) = @_;
    $tolerance //= get_tolerance();

    return 0 unless $v1->len() == $v2->len();

    my $a1 = $v1->to_array();
    my $a2 = $v2->to_array();

    for my $i (0 .. $#$a1) {
        return 0 unless approx_eq($a1->[$i], $a2->[$i], $tolerance);
    }
    return 1;
}

# Legacy function - wrapper around float_is with absolute tolerance
sub within_tolerance {
    my ($got, $expected, $name, $tolerance) = @_;
    return float_is($got, $expected, $name, {
        method => 'absolute',
        tolerance => $tolerance
    });
}

1;

__END__

=head1 NAME

TestVec - Comprehensive float/vector testing with multiple comparison methods

=head1 SYNOPSIS

    use lib 't/lib';
    use TestVec qw(:all);

    # Check NV type
    diag("Running with: " . nv_info->{type});
    diag("Precision: " . nv_digits() . " decimal digits");
    diag("Machine epsilon: " . nv_epsilon());

    # Recommended: relative comparison (handles all magnitudes)
    float_is($got, $expected, "values match");
    float_ok($got, $expected, "quick check");

    # ULP comparison (most rigorous)
    float_is($got, $expected, "precise", { method => 'ulp', ulps => 2 });

    # Exact bit comparison (strictest)
    float_is($got, $expected, "exact", { method => 'exact' });

    # Absolute tolerance (legacy)
    float_is($got, $expected, "within tol", { method => 'absolute' });

    # Low-level checks
    ok(relatively_equal($a, $b, 4), "within 4 ULPs relatively");
    ok(ulp_equal($a, $b, 2), "within 2 ULPs");
    ok(bits_equal($a, $b), "exact bit match");

    # Vector comparison
    ok(vec_approx_eq($v1, $v2), "vectors match");

=head1 DESCRIPTION

TestVec provides multiple strategies for comparing floating-point values,
automatically adapting to the Perl's NV type (double, long double, or quadmath).

=head2 Comparison Methods

=over 4

=item B<relative> (default)

Compares using relative error scaled by machine epsilon. Best for general use
as it handles values of different magnitudes correctly.

=item B<ulp>

Counts "Units in Last Place" - the number of representable floats between
two values. Most mathematically rigorous for numerical algorithm testing.

=item B<exact>

Compares the actual bit representation. Use when values should be identical.

=item B<absolute>

Traditional absolute tolerance. Use with caution as it doesn't scale with
value magnitude.

=back

=head2 NV Type Detection

    is_quadmath()      # True if using __float128 (34 digits)
    is_long_double()   # True if using long double (21 digits typically)
    nv_info()          # Hash with all NV details
    nv_epsilon()       # Actual machine epsilon
    nv_digits()        # Decimal digits of precision

=head1 FUNCTIONS

=head2 float_is($got, $expected, $name, \%opts)

Primary test function. Options:

    method    => 'relative'|'ulp'|'exact'|'absolute'
    ulps      => N        # Max ULPs for relative/ulp methods (default: 4)
    tolerance => N        # Absolute tolerance for absolute method

=head2 float_ok($got, $expected, $name, $ulps)

Shorthand for float_is with relative comparison.

=head2 relatively_equal($a, $b, $ulps)

Returns true if values are within $ulps relative ULPs.

=head2 ulp_distance($a, $b)

Returns the ULP distance between two values (-1 on error).

=head2 bits_equal($a, $b)

Returns true if values have identical bit representation.

=head2 bits_hex($val)

Returns hex string of value's bit representation (for debugging).

=head1 QUADMATH TESTING

To test with quadmath:

    docker run --rm -v $(pwd):/work -w /work perl:5.40-threaded \
        perl -Mblib t/your_test.t

The module auto-detects the NV type and adjusts tolerances accordingly.

=cut

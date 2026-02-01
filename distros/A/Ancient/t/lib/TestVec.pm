package TestVec;
use strict;
use warnings;
use Test::More;
use Exporter 'import';

our @EXPORT_OK = qw(
    approx_eq vec_approx_eq within_tolerance
    is_quadmath get_tolerance
);

# Detect if running under quadmath
sub is_quadmath {
    my $nvtype = eval { require Config; $Config::Config{nvtype} } || '';
    return $nvtype eq '__float128';
}

# Get appropriate tolerance based on precision
# Quadmath has ~34 decimal digits, double has ~15
sub get_tolerance {
    my ($strict) = @_;
    if (is_quadmath()) {
        return $strict ? 1e-30 : 1e-12;
    }
    return $strict ? 1e-12 : 1e-9;
}

# Compare two scalars with tolerance
sub approx_eq {
    my ($got, $expected, $tolerance) = @_;
    $tolerance //= get_tolerance();
    return 1 if !defined $got && !defined $expected;
    return 0 if !defined $got || !defined $expected;
    return abs($got - $expected) < $tolerance;
}

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

# Test helper: check value within tolerance
sub within_tolerance {
    my ($got, $expected, $name, $tolerance) = @_;
    $tolerance //= get_tolerance();
    my $ok = approx_eq($got, $expected, $tolerance);
    ok($ok, $name);
    unless ($ok) {
        diag("  got: $got");
        diag("  expected: $expected");
        diag("  tolerance: $tolerance");
        diag("  diff: " . abs($got - $expected));
    }
    return $ok;
}

1;

__END__

=head1 NAME

TestVec - Test helpers for nvec module

=head1 SYNOPSIS

    use lib 't/lib';
    use TestVec qw(approx_eq vec_approx_eq within_tolerance is_quadmath);

    # Check if running under quadmath
    if (is_quadmath()) {
        diag("Running with 128-bit precision");
    }

    # Compare floats with appropriate tolerance
    ok(approx_eq($got, $expected), "values match");

    # Compare nvec objects
    ok(vec_approx_eq($v1, $v2), "vectors match");

    # Test with diagnostic output
    within_tolerance($result, 3.14159, "pi approximation");

=cut

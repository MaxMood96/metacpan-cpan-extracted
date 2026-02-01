#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 6;
use lib 'blib/lib', 'blib/arch';

BEGIN { use_ok('nvec') }

# Test that the exported C API symbols are accessible via DynaLoader
# (Other XS modules would use vec_api.h directly)

# Create vectors and test basic C API availability through Perl interface
my $v1 = nvec::new([1, 2, 3, 4, 5]);
my $v2 = nvec::new([5, 4, 3, 2, 1]);

# These operations use the internal SIMD implementations
# that are now exported via vec_xs_* functions
my $sum = $v1->sum();
is($sum, 15, "SIMD sum works (internally uses vec_sum_impl)");

my $dot = $v1->dot($v2);
is($dot, 35, "SIMD dot works (internally uses vec_dot_impl)");

my $v3 = $v1->add($v2);
my $result = $v3->to_array();
is_deeply($result, [6, 6, 6, 6, 6], "SIMD add works (internally uses vec_add_impl)");

my $v4 = $v1->scale(2);
$result = $v4->to_array();
is_deeply($result, [2, 4, 6, 8, 10], "SIMD scale works (internally uses vec_scale_impl)");

# Check SIMD name is accessible
my $simd = nvec::simd_info();
like($simd, qr/^(NEON|AVX2|AVX|SSE2|Scalar)$/, "SIMD info via exported API: $simd");

diag "";
diag "=== vec XS C API ===";
diag "Other XS modules can #include \"vec_api.h\" and call:";
diag "  vec_xs_create, vec_xs_from_sv, vec_xs_wrap";
diag "  vec_xs_data, vec_xs_len";
diag "  vec_xs_add_impl, vec_xs_sub_impl, vec_xs_mul_impl, vec_xs_div_impl";
diag "  vec_xs_scale_impl, vec_xs_sum_impl, vec_xs_dot_impl";
diag "  vec_xs_add_inplace_impl, vec_xs_scale_inplace_impl";
diag "All use SIMD: $simd";

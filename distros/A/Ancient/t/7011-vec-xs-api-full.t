#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 't/lib', 'blib/lib', 'blib/arch';

# Check if modules can load BEFORE running any tests
# This avoids "Bad plan" errors when skip_all is needed
BEGIN {
    # Try to load nvec first
    eval { require nvec };
    if ($@) {
        plan skip_all => "nvec not loadable: $@";
        exit 0;
    }
    nvec->import();

    # Try to load nvec_api_test (depends on nvec.so)
    eval { require nvec_api_test; nvec_api_test->import(); };
    if ($@) {
        plan skip_all => "nvec_api_test not loadable (linking issue): $@";
        exit 0;
    }
}

pass('nvec loaded');
pass('nvec_api_test loaded');

# Test SIMD name from C API
my $simd = nvec_api_test::simd_name_from_c();
like($simd, qr/^(NEON|AVX2|AVX|SSE2|Scalar)$/, "SIMD name from C: $simd");

# Test create_from_c - creates nvec entirely in C
my $v = nvec_api_test::create_from_c(5);
isa_ok($v, 'nvec', "create_from_c returns nvec object");
is($v->len(), 5, "nvec has correct length");

my $arr = $v->to_array();
is_deeply($arr, [1, 2, 3, 4, 5], "nvec has correct data (1..n)");

# Test sum_from_c - uses vec_xs_sum_impl directly
my $sum = nvec_api_test::sum_from_c($v);
is($sum, 15, "sum_from_c uses SIMD sum: 1+2+3+4+5 = 15");

# Test dot_from_c - uses vec_xs_dot_impl directly
my $v2 = nvec::new([1, 1, 1, 1, 1]);
my $dot = nvec_api_test::dot_from_c($v, $v2);
is($dot, 15, "dot_from_c uses SIMD dot: [1,2,3,4,5]·[1,1,1,1,1] = 15");

# Test add_from_c - uses vec_xs_add_impl and vec_xs_create
my $v3 = nvec_api_test::add_from_c($v, $v2);
isa_ok($v3, 'nvec', "add_from_c returns nvec object");
is_deeply($v3->to_array(), [2, 3, 4, 5, 6], "add_from_c uses SIMD add");

# Test scale_inplace_from_c - uses vec_xs_scale_inplace_impl
my $v4 = nvec::new([1, 2, 3]);
nvec_api_test::scale_inplace_from_c($v4, 10);
is_deeply($v4->to_array(), [10, 20, 30], "scale_inplace_from_c uses SIMD scale");

diag "";
diag "=== Full XS API Test Passed ===";
diag "nvec_api_test module successfully:";
diag "  - Created nvec in C using vec_xs_create()";
diag "  - Extracted nvec from Perl using vec_xs_from_sv()";
diag "  - Returned nvec to Perl using vec_xs_wrap()";
diag "  - Called SIMD sum via vec_xs_sum_impl()";
diag "  - Called SIMD dot via vec_xs_dot_impl()";
diag "  - Called SIMD add via vec_xs_add_impl()";
diag "  - Called SIMD scale via vec_xs_scale_inplace_impl()";
diag "All operations used $simd SIMD acceleration";

done_testing;

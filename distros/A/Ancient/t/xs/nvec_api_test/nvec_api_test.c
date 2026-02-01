/*
 * nvec_api_test.c - Test module that uses nvec's C API
 *
 * Demonstrates how other XS modules can use nvec_api.h
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Include the nvec C API */
#include "../nvec/nvec_api.h"

/* Test: create a nvec from C, populate it, return to Perl */
static XS(xs_create_from_c) {
    dXSARGS;
    IV size;
    IV i;
    Vec *v;
    double *data;

    if (items != 1) croak("Usage: create_from_c($size)");

    size = SvIV(ST(0));

    /* Use nvec C API to create */
    v = vec_xs_create(aTHX_ size);
    data = vec_xs_data(v);

    /* Populate with test data */
    for (i = 0; i < size; i++) {
        data[i] = (double)(i + 1);
    }
    v->len = size;

    /* Wrap and return */
    ST(0) = sv_2mortal(vec_xs_wrap(aTHX_ v));
    XSRETURN(1);
}

/* Test: extract nvec from Perl, compute sum using C API */
static XS(xs_sum_from_c) {
    dXSARGS;
    Vec *v;
    double *data;
    IV len;
    double sum;

    if (items != 1) croak("Usage: sum_from_c($nvec)");

    /* Use nvec C API to extract */
    v = vec_xs_from_sv(aTHX_ ST(0));
    data = vec_xs_data(v);
    len = vec_xs_len(v);

    /* Use SIMD sum directly */
    sum = vec_xs_sum_impl(data, len);

    ST(0) = sv_2mortal(newSVnv(sum));
    XSRETURN(1);
}

/* Test: dot product via C API */
static XS(xs_dot_from_c) {
    dXSARGS;
    Vec *a;
    Vec *b;
    double dot;

    if (items != 2) croak("Usage: dot_from_c($nvec1, $nvec2)");

    a = vec_xs_from_sv(aTHX_ ST(0));
    b = vec_xs_from_sv(aTHX_ ST(1));

    if (vec_xs_len(a) != vec_xs_len(b)) {
        croak("Vectors must have same length");
    }

    dot = vec_xs_dot_impl(vec_xs_data(a), vec_xs_data(b), vec_xs_len(a));

    ST(0) = sv_2mortal(newSVnv(dot));
    XSRETURN(1);
}

/* Test: add two nvecs via C API, return new nvec */
static XS(xs_add_from_c) {
    dXSARGS;
    Vec *a;
    Vec *b;
    Vec *c;
    IV len;

    if (items != 2) croak("Usage: add_from_c($nvec1, $nvec2)");

    a = vec_xs_from_sv(aTHX_ ST(0));
    b = vec_xs_from_sv(aTHX_ ST(1));
    len = vec_xs_len(a);

    if (len != vec_xs_len(b)) {
        croak("Vectors must have same length");
    }

    /* Create result nvec */
    c = vec_xs_create(aTHX_ len);
    c->len = len;

    /* Use SIMD add */
    vec_xs_add_impl(vec_xs_data(c), vec_xs_data(a), vec_xs_data(b), len);

    ST(0) = sv_2mortal(vec_xs_wrap(aTHX_ c));
    XSRETURN(1);
}

/* Test: scale in-place via C API */
static XS(xs_scale_inplace_from_c) {
    dXSARGS;
    Vec *v;
    double s;

    if (items != 2) croak("Usage: scale_inplace_from_c($nvec, $scalar)");

    v = vec_xs_from_sv(aTHX_ ST(0));
    s = SvNV(ST(1));

    /* SIMD scale in-place */
    vec_xs_scale_inplace_impl(vec_xs_data(v), s, vec_xs_len(v));

    XSRETURN(0);
}

/* Test: get SIMD name */
static XS(xs_simd_name_from_c) {
    dXSARGS;
    const char *name;
    PERL_UNUSED_VAR(items);

    name = vec_xs_simd_name();
    ST(0) = sv_2mortal(newSVpv(name, 0));
    XSRETURN(1);
}

/* Boot function */
XS_EXTERNAL(boot_nvec_api_test);
XS_EXTERNAL(boot_nvec_api_test) {
    dXSARGS;
    PERL_UNUSED_VAR(items);

    newXS("nvec_api_test::create_from_c", xs_create_from_c, __FILE__);
    newXS("nvec_api_test::sum_from_c", xs_sum_from_c, __FILE__);
    newXS("nvec_api_test::dot_from_c", xs_dot_from_c, __FILE__);
    newXS("nvec_api_test::add_from_c", xs_add_from_c, __FILE__);
    newXS("nvec_api_test::scale_inplace_from_c", xs_scale_inplace_from_c, __FILE__);
    newXS("nvec_api_test::simd_name_from_c", xs_simd_name_from_c, __FILE__);

    XSRETURN_YES;
}

enum ArraySource {
    ARRAY_SRC_INVOCANT,
    ARRAY_SRC_DEREF_SCALAR,
    ARRAY_SRC_DEREF_ARRAY,
    ARRAY_SRC_DEREF_HASH,
    ARRAY_SRC_CALL_METHOD,
};

// SIMPLE SIG: all, count, pop, shift, etc
typedef struct {
    char*               name;
    enum ArraySource    arr_source;
    char*               arr_source_string;
    char*               arr_source_fallback;
    I32                 arr_source_index;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_array_SIMPLE_SIG;

// NEW ELEMS SIG: push, unshift, etc (add new elements to arrayref, so need a type)
typedef struct {
    char*               name;
    enum ArraySource    arr_source;
    char*               arr_source_string;
    char*               arr_source_fallback;
    I32                 arr_source_index;
    I32                 element_type;
    CV*                 element_type_cv;
    SV*                 element_type_tiny;
    bool                has_element_type_tiny;
    CV*                 element_coercion_cv;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_array_NEW_ELEMS_SIG;

// CODEREF SIG: for_each, map, grep, etc (methods which accept a potentially curried coderef)
typedef struct {
    char*               name;
    enum ArraySource    arr_source;
    char*               arr_source_string;
    char*               arr_source_fallback;
    I32                 arr_source_index;
    CV*                 callback;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_array_CALLBACK_SIG;

// INDEX SIG: get, etc (methods which accept a potentially curried index)
typedef struct {
    char*               name;
    enum ArraySource    arr_source;
    char*               arr_source_string;
    char*               arr_source_fallback;
    I32                 arr_source_index;
    bool                has_index;
    I32                 index;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_array_INDEX_SIG;

// SV SIG: join, etc (methods which accept a potentially curried scalar)
typedef struct {
    char*               name;
    enum ArraySource    arr_source;
    char*               arr_source_string;
    char*               arr_source_fallback;
    I32                 arr_source_index;
    bool                has_curried_sv;
    SV*                 curried_sv;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_array_SV_SIG;

// SETTER SIG: accessor, set (combination of NEW_ELEMS, INDEX, and SV)
typedef struct {
    char*               name;
    enum ArraySource    arr_source;
    char*               arr_source_string;
    char*               arr_source_fallback;
    I32                 arr_source_index;
    bool                has_index;
    I32                 index;
    bool                has_curried_sv;
    SV*                 curried_sv;
    I32                 element_type;
    CV*                 element_type_cv;
    SV*                 element_type_tiny;
    bool                has_element_type_tiny;
    CV*                 element_coercion_cv;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_array_SETTER_SIG;

#define GET_ARRAY_FROM_SOURCE                                           \
    AV *array = NULL;                                                   \
    AV *out = NULL;                                                     \
    SV *val = NULL;                                                     \
    STMT_START {                                                        \
        SV *tmp;                                                        \
                                                                        \
        switch (sig->arr_source) {                                      \
        case ARRAY_SRC_INVOCANT:                                        \
            if (!SvROK(invocant) ||                                     \
                SvTYPE(SvRV(invocant)) != SVt_PVAV)                     \
                croak("Invocant is not an array reference");            \
            array = (AV *)SvRV(invocant);                               \
            break;                                                      \
                                                                        \
        case ARRAY_SRC_DEREF_SCALAR:                                    \
            if (!SvROK(invocant) ||                                     \
                !SvROK(SvRV(invocant)) ||                               \
                SvTYPE(SvRV(SvRV(invocant))) != SVt_PVAV)               \
                croak("Invocant is not a scalar ref to array");         \
            array = (AV *)SvRV(SvRV(invocant));                         \
            break;                                                      \
                                                                        \
        case ARRAY_SRC_DEREF_ARRAY:                                     \
            if (!SvROK(invocant) ||                                     \
                SvTYPE(SvRV(invocant)) != SVt_PVAV)                     \
                croak("Invocant is not an array reference");            \
            tmp = *av_fetch((AV *)SvRV(invocant),                       \
                             sig->arr_source_index, 0);                 \
            if (!tmp || !SvROK(tmp) ||                                  \
                SvTYPE(SvRV(tmp)) != SVt_PVAV)                          \
                croak("Array element is not an array ref");             \
            array = (AV *)SvRV(tmp);                                    \
            break;                                                      \
                                                                        \
        case ARRAY_SRC_DEREF_HASH: {                                    \
            if (!SvROK(invocant) ||                                     \
                SvTYPE(SvRV(invocant)) != SVt_PVHV)                     \
                croak("Invocant is not a hash reference");              \
            if (sig->arr_source_fallback &&                             \
                !hv_exists((HV *)SvRV(invocant),                        \
                           sig->arr_source_string,                      \
                           strlen(sig->arr_source_string))) {           \
                dSP;                                                    \
                ENTER;                                                  \
                SAVETMPS;                                               \
                PUSHMARK(SP);                                           \
                XPUSHs(invocant);                                       \
                PUTBACK;                                                \
                call_method(sig->arr_source_fallback, G_VOID|G_DISCARD);\
                FREETMPS;                                               \
                LEAVE;                                                  \
            }                                                           \
            tmp = *hv_fetch((HV *)SvRV(invocant),                       \
                             sig->arr_source_string,                    \
                             strlen(sig->arr_source_string), 0);        \
            if (!tmp || !SvROK(tmp) ||                                  \
                SvTYPE(SvRV(tmp)) != SVt_PVAV)                          \
                croak("Hash value is not an array ref");                \
            array = (AV *)SvRV(tmp);                                    \
            break;                                                      \
        }                                                               \
                                                                        \
        case ARRAY_SRC_CALL_METHOD: {                                   \
            dSP;                                                        \
            ENTER;                                                      \
            SAVETMPS;                                                   \
            PUSHMARK(SP);                                               \
            XPUSHs(invocant);                                           \
            PUTBACK;                                                    \
            call_method(sig->arr_source_string, G_SCALAR);              \
            SPAGAIN;                                                    \
            tmp = POPs;                                                 \
            PUTBACK;                                                    \
            if (!SvROK(tmp) ||                                          \
                SvTYPE(SvRV(tmp)) != SVt_PVAV)                          \
                croak("Method did not return an array ref");            \
            array = (AV *)SvRV(tmp);                                    \
            FREETMPS;                                                   \
            LEAVE;                                                      \
            break;                                                      \
        }                                                               \
                                                                        \
        default:                                                        \
            croak("Unknown array source");                              \
        }                                                               \
    } STMT_END

SV*
shvxs_array_return_sv_object(
    SV*               invocant,
    AV*               array,
    char*             return_class,
    char*             return_constructor,
    enum ArraySource  arr_source,
    char*             arr_source_string,
    I32               arr_source_index
) {
    dTHX;

    SV *array_ref = newRV_noinc((SV *)array);
    SV *obj;

    SV *return_class_sv    = NULL;
    HV *return_class_stash = NULL;

    if (return_class && strcmp(return_class, "1") == 0) {
        if (!SvROK(invocant) || !SvOBJECT(SvRV(invocant)))
            croak("Invocant is not an object");
        return_class_stash = SvSTASH(SvRV(invocant));
        return_class_sv = newSVpv(HvNAME(return_class_stash), 0);
    }
    else if (return_class) {
        return_class_sv = newSVpv(return_class, 0);
        return_class_stash = gv_stashpv(return_class, GV_ADD);
    }

    /* Case 1: call constructor */
    if (return_constructor) {
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(sv_2mortal(return_class_sv));
        XPUSHs(array_ref);
        PUTBACK;

        call_method(return_constructor, G_SCALAR);

        SPAGAIN;
        obj = SvREFCNT_inc(POPs);
        PUTBACK;

        FREETMPS;
        LEAVE;

        return obj;
    }

    /* Case 2: bless(\@array, class) */
    if (arr_source == ARRAY_SRC_INVOCANT) {
        obj = sv_bless(array_ref, return_class_stash);
        return SvREFCNT_inc(obj);
    }

    /* Case 3: bless(\$tmp, class) */
    if (arr_source == ARRAY_SRC_DEREF_SCALAR) {
        SV *tmp = newSV(0);
        sv_setsv(tmp, array_ref);

        SV *tmp_ref = newRV_noinc(tmp);
        obj = sv_bless(tmp_ref, return_class_stash);

        return SvREFCNT_inc(obj);
    }

    /* Case 4: bless(\@tmp, class) */
    if (arr_source == ARRAY_SRC_DEREF_ARRAY) {
        AV *tmp = newAV();
        av_store(tmp, arr_source_index, SvREFCNT_inc(array_ref));

        SV *tmp_ref = newRV_noinc((SV *)tmp);
        obj = sv_bless(tmp_ref, return_class_stash);

        return SvREFCNT_inc(obj);
    }

    /* Case 5: bless(\%tmp, class) */
    if (arr_source == ARRAY_SRC_DEREF_HASH) {
        HV *tmp = newHV();
        hv_store(
            tmp,
            arr_source_string,
            strlen(arr_source_string),
            SvREFCNT_inc(array_ref),
            0
        );

        SV *tmp_ref = newRV_noinc((SV *)tmp);
        obj = sv_bless(tmp_ref, return_class_stash);

        return SvREFCNT_inc(obj);
    }

    /* Case 6: forbidden */
    if (arr_source == ARRAY_SRC_CALL_METHOD) {
        croak("ARRAY_SRC_CALL_METHOD not permitted for return object construction");
    }

    croak("Invalid ArraySource value");
}

#define RETURN_ARRAY_EXPECTATION                                        \
    STMT_START {                                                        \
        switch (sig->method_return_pattern) {                           \
        case SHOULD_RETURN_NOTHING: {                                   \
            if (GIMME_V == G_SCALAR) {                                  \
                XSRETURN_UNDEF;                                         \
            }                                                           \
            XSRETURN_EMPTY;                                             \
        }                                                               \
                                                                        \
        case SHOULD_RETURN_UNDEF:                                       \
            XSRETURN_UNDEF;                                             \
                                                                        \
        case SHOULD_RETURN_TRUE:                                        \
            XSRETURN_YES;                                               \
                                                                        \
        case SHOULD_RETURN_FALSE:                                       \
            XSRETURN_NO;                                                \
                                                                        \
        case SHOULD_RETURN_INVOCANT:                                    \
            ST(0) = sv_2mortal(newSVsv(invocant));                      \
            XSRETURN(1);                                                \
                                                                        \
        case SHOULD_RETURN_VAL:                                         \
            ST(0) = val;                                                \
            XSRETURN(1);                                                \
                                                                        \
        case SHOULD_RETURN_COUNT:                                       \
            I32 n = av_len(array) + 1;                                  \
            ST(0) = sv_2mortal(newSViv(n));                             \
            XSRETURN(1);                                                \
                                                                        \
        case SHOULD_RETURN_ARRAY:                                       \
        case SHOULD_RETURN_ARRAYBLESS: {                                \
            I32 n = av_len(array) + 1;                                  \
                                                                        \
            if (GIMME_V == G_SCALAR) {                                  \
                enum ReturnPattern rp = sig->method_return_pattern;     \
                if ( rp == SHOULD_RETURN_ARRAY ) {                      \
                    ST(0) = sv_2mortal(newSViv(n));                     \
                    XSRETURN(1);                                        \
                }                                                       \
                else {                                                  \
                    ST(0) = shvxs_array_return_sv_object(               \
                        invocant,                                       \
                        array,                                          \
                        sig->method_return_class,                       \
                        sig->method_return_constructor,                 \
                        sig->arr_source,                                \
                        sig->arr_source_string,                         \
                        sig->arr_source_index                           \
                    );                                                  \
                    XSRETURN(1);                                        \
                }                                                       \
            }                                                           \
                                                                        \
            if (n > 0) {                                                \
                SP = MARK;                                              \
                EXTEND(SP, n);                                          \
                for (I32 i = 0; i < n; i++) {                           \
                    SV **svp = av_fetch(array, i, 0);                   \
                    PUSHs(svp ? sv_2mortal(newSVsv(*svp))               \
                               : &PL_sv_undef);                         \
                }                                                       \
            }                                                           \
            XSRETURN(n);                                                \
        }                                                               \
                                                                        \
        case SHOULD_RETURN_OUT:                                         \
        case SHOULD_RETURN_OUTBLESS: {                                  \
            I32 n = av_len(out) + 1;                                    \
                                                                        \
            if (GIMME_V == G_SCALAR) {                                  \
                enum ReturnPattern rp = sig->method_return_pattern;     \
                if ( rp == SHOULD_RETURN_OUT ) {                        \
                    ST(0) = sv_2mortal(newSViv(n));                     \
                    XSRETURN(1);                                        \
                }                                                       \
                else {                                                  \
                    ST(0) = shvxs_array_return_sv_object(               \
                        invocant,                                       \
                        out,                                            \
                        sig->method_return_class,                       \
                        sig->method_return_constructor,                 \
                        sig->arr_source,                                \
                        sig->arr_source_string,                         \
                        sig->arr_source_index                           \
                    );                                                  \
                    XSRETURN(1);                                        \
                }                                                       \
            }                                                           \
                                                                        \
            if (n > 0) {                                                \
                SP = MARK;                                              \
                EXTEND(SP, n);                                          \
                for (I32 i = 0; i < n; i++) {                           \
                    SV **svp = av_fetch(out, i, 0);                     \
                    PUSHs(svp ? sv_2mortal(newSVsv(*svp))               \
                               : &PL_sv_undef);                         \
                }                                                       \
            }                                                           \
            XSRETURN(n);                                                \
        }                                                               \
                                                                        \
        case SHOULD_RETURN_OTHER:                                       \
        default:                                                        \
            break;                                                      \
        }                                                               \
    } STMT_END

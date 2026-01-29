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

#define GET_INDEX_FROM_SOURCE(z)                                        \
    I32 ix = 0;                                                         \
    bool has_ix = FALSE;                                                \
    STMT_START {                                                        \
        if (sig->has_index) {                                           \
            has_ix = TRUE;                                              \
            ix = sig->index;                                            \
        }                                                               \
        else if (items > z) {                                           \
            bool ok = check_type(ST(z), TYPE_BASE_INT, NULL);           \
            if (!ok) type_error(ST(z), "$_", z, TYPE_BASE_INT, NULL);   \
            has_ix = FALSE;                                             \
            ix = SvIV(ST(z));                                           \
        }                                                               \
        else {                                                          \
            croak(WRONG_NUMBER_OF_PARAMETERS);                          \
        }                                                               \
    } STMT_END

#define GET_CURRIED_SV_FROM_SOURCE(z)                                   \
    SV* curried_sv = NULL;                                              \
    bool has_curried_sv = FALSE;                                        \
    STMT_START {                                                        \
        if (sig->has_curried_sv) {                                      \
            has_curried_sv = TRUE;                                      \
            curried_sv = sig->curried_sv;                               \
        }                                                               \
        else if (items > z) {                                           \
            has_curried_sv = FALSE;                                     \
            curried_sv = newSVsv(ST(z));                                \
        }                                                               \
        else {                                                          \
            croak(WRONG_NUMBER_OF_PARAMETERS);                          \
        }                                                               \
    } STMT_END

 #define MAYBE_GET_CURRIED_SV_FROM_SOURCE(z)                             \
     SV* curried_sv = NULL;                                              \
     bool has_curried_sv = FALSE;                                        \
     STMT_START {                                                        \
         if (sig->has_curried_sv) {                                      \
             has_curried_sv = TRUE;                                      \
             curried_sv = sig->curried_sv;                               \
         }                                                               \
         else if (items > z) {                                           \
             has_curried_sv = FALSE;                                     \
             curried_sv = newSVsv(ST(z));                                \
         }                                                               \
     } STMT_END

#define GET_CALLBACK_FROM_SOURCE(z)                                     \
    CV *callback = NULL;                                                \
    bool has_callback = FALSE;                                          \
    STMT_START {                                                        \
        if (sig->callback) {                                            \
            if (items > 1 && SvOK(ST(1))) {                             \
                if (SvROK(ST(1)) && SvTYPE(SvRV(ST(1))) == SVt_PVCV) {  \
                    croak(WRONG_NUMBER_OF_PARAMETERS);                  \
                }                                                       \
            }                                                           \
            callback = sig->callback;                                   \
            has_callback = TRUE;                                        \
        }                                                               \
        else if (items <= z ) {                                         \
            croak(WRONG_NUMBER_OF_PARAMETERS);                          \
        }                                                               \
        else if ( !SvROK(ST(z)) || SvTYPE(SvRV(ST(z))) != SVt_PVCV ) {  \
            type_error(ST(z), "$_", z, TYPE_BASE_CODEREF, NULL);        \
        }                                                               \
        else {                                                          \
            callback = (CV *)SvRV(ST(z));                               \
        }                                                               \
    } STMT_END

#define MAYBE_GET_CALLBACK_FROM_SOURCE(z)                               \
    CV *callback = NULL;                                                \
    bool has_callback = FALSE;                                          \
    STMT_START {                                                        \
        if (sig->callback) {                                            \
            if (items > z && SvOK(ST(z))) {                             \
                if (SvROK(ST(z)) && SvTYPE(SvRV(ST(z))) == SVt_PVCV) {  \
                    croak(WRONG_NUMBER_OF_PARAMETERS);                  \
                }                                                       \
            }                                                           \
            callback = sig->callback;                                   \
            has_callback = TRUE;                                        \
        }                                                               \
        else {                                                          \
            if (items <= z                                              \
                || !SvROK(ST(z))                                        \
                || SvTYPE(SvRV(ST(z))) != SVt_PVCV) {                   \
                callback = NULL;                                        \
            }                                                           \
            else {                                                      \
                callback = (CV *)SvRV(ST(z));                           \
            }                                                           \
        }                                                               \
    } STMT_END

SV*
shvxs_return_sv_object(
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

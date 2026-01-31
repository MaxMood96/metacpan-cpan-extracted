enum StringSource {
    STR_SRC_INVOCANT,
    STR_SRC_DEREF_SCALAR,
    STR_SRC_DEREF_ARRAY,
    STR_SRC_DEREF_HASH,
    STR_SRC_CALL_METHOD,
};

typedef struct {
    char*               name;
    enum StringSource   str_source;
    char*               str_source_string;
    char*               str_source_fallback;
    I32                 str_source_index;
    bool                has_curried_sv;
    SV*                 curried_sv;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_string_CMP_SIG;

typedef struct {
    char*               name;
    enum StringSource   str_source;
    char*               str_source_string;
    char*               str_source_fallback;
    I32                 str_source_index;
    bool                has_curried_sv;
    SV*                 curried_sv;
    I32                 type;
    CV*                 type_cv;
    SV*                 type_tiny;
    bool                has_type_tiny;
    CV*                 coercion_cv;
    enum ReturnPattern  method_return_pattern;
    char*               method_return_class;
    char*               method_return_constructor;
} shvxs_string_SETTER_SIG;

#define GET_STRING_FROM_SOURCE                                          \
    SV *string = NULL; /* var for incoming string */                    \
    SV *val    = NULL; /* var for outgoing value */                     \
    STMT_START {                                                        \
        SV *tmp;                                                        \
                                                                        \
        switch (sig->str_source) {                                      \
        case STR_SRC_INVOCANT:                                          \
            string = invocant;                                          \
            break;                                                      \
                                                                        \
        case STR_SRC_DEREF_SCALAR:                                      \
            if (!SvROK(invocant))                                       \
                croak("Invocant is not a scalar reference");            \
            string = SvRV(invocant);                                    \
            break;                                                      \
                                                                        \
        case STR_SRC_DEREF_ARRAY: {                                     \
            if (!SvROK(invocant) ||                                     \
                SvTYPE(SvRV(invocant)) != SVt_PVAV)                     \
                croak("Invocant is not an array reference");            \
            SV **svp = av_fetch((AV *)SvRV(invocant),                   \
                                sig->str_source_index, 1);              \
            if (!svp)                                                   \
                croak("Failed to create array element");                \
            string = *svp; /* alias */                                  \
            break;                                                      \
        }                                                               \
                                                                        \
        case STR_SRC_DEREF_HASH: {                                      \
            if (!SvROK(invocant) ||                                     \
                SvTYPE(SvRV(invocant)) != SVt_PVHV)                     \
                croak("Invocant is not a hash reference");              \
                                                                        \
            if (sig->str_source_fallback &&                             \
                !hv_exists((HV *)SvRV(invocant),                        \
                           sig->str_source_string,                      \
                           (I32)strlen(sig->str_source_string))) {      \
                ENTER;                                                  \
                SAVETMPS;                                               \
                PUSHMARK(SP);                                           \
                XPUSHs(invocant);                                       \
                PUTBACK;                                                \
                call_method(sig->str_source_fallback,                   \
                            G_VOID | G_DISCARD);                        \
                SPAGAIN;                                                \
                FREETMPS;                                               \
                LEAVE;                                                  \
            }                                                           \
                                                                        \
            SV **svp = hv_fetch((HV *)SvRV(invocant),                   \
                                sig->str_source_string,                 \
                                (I32)strlen(sig->str_source_string),    \
                                1);                                     \
            if (!svp)                                                   \
                croak("Failed to create hash value");                   \
            string = *svp; /* alias */                                  \
            break;                                                      \
        }                                                               \
                                                                        \
        case STR_SRC_CALL_METHOD: {                                     \
            ENTER;                                                      \
            SAVETMPS;                                                   \
            PUSHMARK(SP);                                               \
            XPUSHs(invocant);                                           \
            PUTBACK;                                                    \
            I32 count = call_method(sig->str_source_string, G_SCALAR);  \
            SPAGAIN;                                                    \
            tmp = (count > 0) ? POPs : &PL_sv_undef;                    \
            PUTBACK;                                                    \
            string = newSVsv(tmp);                                      \
            FREETMPS;                                                   \
            LEAVE;                                                      \
            break;                                                      \
        }                                                               \
                                                                        \
        default:                                                        \
            croak("Unknown string source");                             \
        }                                                               \
    } STMT_END

#define SET_STRING(newsv)                                               \
    STMT_START {                                                        \
        SV *ns = newsv;                                                 \
        if (!ns) ns = &PL_sv_undef;                                     \
                                                                        \
        /* For non-method sources, `string` aliases original storage,   \
           so this updates the original location automatically. */      \
        if (sig->str_source != STR_SRC_CALL_METHOD) {                   \
            sv_setsv(string, ns);                                       \
        }                                                               \
        else {                                                          \
            /* Keep local copy in sync too */                           \
            if (string)                                                 \
                sv_setsv(string, ns);                                   \
                                                                        \
            ENTER;                                                      \
            SAVETMPS;                                                   \
            PUSHMARK(SP);                                               \
            XPUSHs(invocant);                                           \
            XPUSHs(ns);                                                 \
            PUTBACK;                                                    \
            call_method(sig->str_source_string, G_VOID | G_DISCARD);    \
            SPAGAIN;                                                    \
            FREETMPS;                                                   \
            LEAVE;                                                      \
        }                                                               \
    } STMT_END


#define RETURN_STRING_EXPECTATION                                       \
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
        case SHOULD_RETURN_STRING:                                      \
            ST(0) = sv_2mortal(newSVsv(string));                        \
            XSRETURN(1);                                                \
                                                                        \
        case SHOULD_RETURN_VAL:                                         \
            ST(0) = val;                                                \
            XSRETURN(1);                                                \
                                                                        \
        case SHOULD_RETURN_OTHER:                                       \
        default:                                                        \
            break;                                                      \
        }                                                               \
    } STMT_END

SV*
sv_lower(pTHX_ SV* sv) {
    STRLEN len;
    char *s = SvPV_force(sv, len);
    for (; len--; s++)
        *s = toLOWER(*s);
    return sv;
}

static I32
sv_cmp_ci(pTHX_ SV *a, SV *b)
{
    I32 c;

    ENTER;
    SAVETMPS;

    SV *ta = sv_2mortal(newSVsv(a));
    SV *tb = sv_2mortal(newSVsv(b));

    sv_lower(aTHX_ ta);
    sv_lower(aTHX_ tb);

    c = sv_cmp(ta, tb);

    FREETMPS;
    LEAVE;

    return c;
}

#define SV_CMP_CI(a, b) sv_cmp_ci(aTHX_ (a), (b))

#define CHECK_CURRIED_SV_IS_STRING                                          \
    bool ok = SvOK(curried_sv) && !SvROK(curried_sv) && !isGV(curried_sv);  \
    if (!ok && has_curried_sv) {                                            \
        type_error(curried_sv, "$curried", 0, TYPE_BASE_STR, NULL);         \
    }                                                                       \
    else if (!ok) {                                                         \
        type_error(curried_sv, "$_", 1, TYPE_BASE_STR, NULL);               \
    }

#define COMMON_STRING_PARAM_COUNT_CHECK                                     \
    if (has_curried_sv && items!=1) {                                       \
        croak(WRONG_NUMBER_OF_PARAMETERS);                                  \
    }                                                                       \
    else if(!has_curried_sv && items!=2) {                                  \
        croak(WRONG_NUMBER_OF_PARAMETERS);                                  \
    }

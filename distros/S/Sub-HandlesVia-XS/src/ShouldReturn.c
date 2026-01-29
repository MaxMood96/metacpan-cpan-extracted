enum ReturnPattern {
    SHOULD_RETURN_OTHER,
    SHOULD_RETURN_NOTHING,
    SHOULD_RETURN_UNDEF,
    SHOULD_RETURN_TRUE,
    SHOULD_RETURN_FALSE,
    SHOULD_RETURN_INVOCANT,
    SHOULD_RETURN_ARRAY,
    SHOULD_RETURN_ARRAYBLESS,
    SHOULD_RETURN_OUT,
    SHOULD_RETURN_OUTBLESS,
    SHOULD_RETURN_VAL,
    SHOULD_RETURN_COUNT,
};

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
            dSP;                                                        \
            I32 n = av_len(array) + 1;                                  \
                                                                        \
            if (GIMME_V == G_SCALAR) {                                  \
                enum ReturnPattern rp = sig->method_return_pattern;     \
                if ( rp == SHOULD_RETURN_ARRAY ) {                      \
                    ST(0) = sv_2mortal(newSViv(n));                     \
                    XSRETURN(1);                                        \
                }                                                       \
                else {                                                  \
                    ST(0) = shvxs_return_sv_object(                     \
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
            SP = MARK;                                                  \
                                                                        \
            if (n > 0) {                                                \
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
            dSP;                                                        \
            I32 n = av_len(out) + 1;                                    \
                                                                        \
            if (GIMME_V == G_SCALAR) {                                  \
                enum ReturnPattern rp = sig->method_return_pattern;     \
                if ( rp == SHOULD_RETURN_OUT ) {                        \
                    ST(0) = sv_2mortal(newSViv(n));                     \
                    XSRETURN(1);                                        \
                }                                                       \
                else {                                                  \
                    ST(0) = shvxs_return_sv_object(                     \
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
            SP = MARK;                                                  \
                                                                        \
            if (n > 0) {                                                \
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

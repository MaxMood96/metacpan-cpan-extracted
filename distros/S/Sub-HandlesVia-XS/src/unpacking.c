#define UNPACK_SIG(type) const type *sig = (const type *) CvXSUBANY(cv).any_ptr

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

#define UNPACKING_HV_FROM_SV(sv, hvvar)                            \
    HV *hvvar = NULL;                                              \
    STMT_START {                                                   \
        if (!SvROK(sv) || SvTYPE(SvRV(sv)) != SVt_PVHV) {          \
            croak(#sv " must be a hashref");                       \
        }                                                          \
        hvvar = (HV *)SvRV(sv);                                    \
    } STMT_END

#define UNPACKING_GET_ENUM(hv, out, field, def, enumtype)          \
    STMT_START {                                                   \
        SV **svp = hv_fetch(hv, #field,                            \
                             sizeof(#field) - 1, 0);               \
        if (svp && SvOK(*svp)) {                                   \
            out->field = (enum enumtype)SvIV(*svp);                \
        }                                                          \
        else {                                                     \
            out->field = def;                                      \
        }                                                          \
    } STMT_END

#define UNPACKING_GET_STRING(hv, out, field, def)                  \
    STMT_START {                                                   \
        SV **svp = hv_fetch(hv, #field,                            \
                             sizeof(#field) - 1, 0);               \
        if (svp && SvOK(*svp)) {                                   \
            STRLEN len;                                            \
            const char *s = SvPV(*svp, len);                       \
            out->field = savepvn(s, len);                          \
        }                                                          \
        else {                                                     \
            out->field = def;                                      \
        }                                                          \
    } STMT_END

#define UNPACKING_GET_I32(hv, out, field, def)                     \
    STMT_START {                                                   \
        SV **svp = hv_fetch(hv, #field,                            \
                             sizeof(#field) - 1, 0);               \
        if (svp && SvOK(*svp)) {                                   \
            out->field = (I32)SvIVx(*svp);                          \
        }                                                          \
        else {                                                     \
            out->field = def;                                      \
        }                                                          \
    } STMT_END

#define UNPACKING_MAYBE_I32(hv, out, field, predfield)             \
    STMT_START {                                                   \
        SV **svp = hv_fetch(hv, #field,                            \
                             sizeof(#field) - 1, 0);               \
        if (svp && SvOK(*svp)) {                                   \
            out->field = (I32)SvIVx(*svp);                         \
            out->predfield = TRUE;                                 \
        }                                                          \
        else {                                                     \
            out->field = 0;                                        \
            out->predfield = FALSE;                                \
        }                                                          \
    } STMT_END

#define UNPACKING_MAYBE_SV(hv, out, field, predfield)              \
    STMT_START {                                                   \
        SV **svp = hv_fetch(hv, #field, sizeof(#field) - 1, 0);    \
        if (svp && SvOK(*svp)) {                                   \
            out->field = SV_SAFE_COPY(*svp);                       \
            out->predfield = TRUE;                                 \
        }                                                          \
        else {                                                     \
            out->field = NULL;                                     \
            out->predfield = FALSE;                                \
        }                                                          \
    } STMT_END

#define UNPACKING_GET_CV(hv, out, field)                           \
    STMT_START {                                                   \
        SV **svp = hv_fetch(hv, #field,                            \
                             sizeof(#field) - 1, 0);               \
        if (svp && SvOK(*svp)) {                                   \
            SV *sv = *svp;                                         \
            SV *rv;                                                \
            CV *cv;                                                \
            if (!SvROK(sv))                                        \
                croak(#field " must be a coderef");                \
            rv = SvRV(sv);                                         \
            if (SvTYPE(rv) == SVt_PVCV) {                          \
                cv = (CV *)rv;                                     \
            }                                                      \
            else if (SvTYPE(rv) == SVt_PVGV) {                     \
                cv = GvCV((GV *)rv);                               \
                if (!cv)                                           \
                    croak(#field " glob has no CODE slot");        \
            }                                                      \
            else {                                                 \
                croak(#field " must be a coderef");                \
            }                                                      \
            out->field = (CV *)SvREFCNT_inc((SV *)cv);             \
        }                                                          \
    } STMT_END

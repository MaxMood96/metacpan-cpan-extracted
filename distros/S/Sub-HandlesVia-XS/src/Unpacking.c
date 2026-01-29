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

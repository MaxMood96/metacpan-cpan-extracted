enum {
    TYPE_BASE_ANY             =    0,
    TYPE_BASE_DEFINED         =    1,
    TYPE_BASE_REF             =    2,
    TYPE_BASE_BOOL            =    3,
    TYPE_BASE_INT             =    4,
    TYPE_BASE_PZINT           =    5,
    TYPE_BASE_NUM             =    6,
    TYPE_BASE_PZNUM           =    7,
    TYPE_BASE_STR             =    8,
    TYPE_BASE_NESTR           =    9,
    TYPE_BASE_CLASSNAME       =   10,
    TYPE_BASE_OBJECT          =   12,
    TYPE_BASE_SCALARREF       =   13,
    TYPE_BASE_CODEREF         =   14,

    TYPE_OTHER                =   15,

    TYPE_ARRAYREF             =   16,
    TYPE_HASHREF              =   32,
};

static bool
_S_pv_is_integer (char* const pv) {
    dTHX;
    const char* p;
    p = &pv[0];

    /* -?[0-9]+ */
    if(*p == '-') p++;

    if (!*p) return FALSE;

    while(*p){
        if(!isDIGIT(*p)){
            return FALSE;
        }
        p++;
    }
    return TRUE;
}

static bool
_S_nv_is_integer (NV const nv) {
    dTHX;
    if(nv == (NV)(IV)nv){
        return TRUE;
    }
    else {
        char buf[64];  /* Must fit sprintf/Gconvert of longest NV */
        const char* p;
        (void)Gconvert(nv, NV_DIG, 0, buf);
        return _S_pv_is_integer(buf);
    }
}

bool
_is_class_loaded (SV* const klass) {
    dTHX;
    HV *stash;
    GV** gvp;
    HE* he;

    if ( !SvPOKp(klass) || !SvCUR(klass) ) { /* XXX: SvPOK does not work with magical scalars */
        return FALSE;
    }

    stash = gv_stashsv( klass, FALSE );
    if ( !stash ) {
        return FALSE;
    }

    if (( gvp = (GV**)hv_fetchs(stash, "VERSION", FALSE) )) {
        if ( isGV(*gvp) && GvSV(*gvp) && SvOK(GvSV(*gvp)) ){
            return TRUE;
        }
    }

    if (( gvp = (GV**)hv_fetchs(stash, "ISA", FALSE) )) {
        if ( isGV(*gvp) && GvAV(*gvp) && av_len(GvAV(*gvp)) != -1 ) {
            return TRUE;
        }
    }

    hv_iterinit(stash);
    while (( he = hv_iternext(stash) )) {
        GV* const gv = (GV*)HeVAL(he);
        if ( isGV(gv) ) {
            if ( GvCVu(gv) ) { /* is GV and has CV */
                hv_iterinit(stash); /* reset */
                return TRUE;
            }
        }
        else if ( SvOK(gv) ) { /* is a stub or constant */
            hv_iterinit(stash); /* reset */
            return TRUE;
        }
    }
    return FALSE;
}

// Full version of check_type
static bool
check_type(SV* const val, int flags, CV* check_cv)
{
    dTHX;
    assert(val);

    if ( ( flags & TYPE_OTHER ) == TYPE_OTHER ) {
        if ( !check_cv ) {
            warn( "Type constraint check coderef gone AWOL so just assuming value passes" );
            return 1;
        }

        SV* result;

        dSP;
        int count;
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        EXTEND(SP, 1);
        PUSHs(sv_2mortal(val));
        PUTBACK;
        count  = call_sv((SV *)check_cv, G_SCALAR);
        SPAGAIN;
        result = POPs;
        bool return_val = SvTRUE(result);
        FREETMPS;
        LEAVE;
        
        return return_val;
    }
    
    if ( flags & TYPE_ARRAYREF ) {
        if ( !IsArrayRef(val) ) {
            return FALSE;
        }
        if ( flags == TYPE_ARRAYREF ) {
            return TRUE;
        }
        int newflags = flags & ( TYPE_ARRAYREF - 1 );
        AV* const av = (AV*)SvRV(val);
        I32 const len = av_len(av) + 1;
        I32 i;
        for (i = 0; i < len; i++) {
            SV* const subval = *av_fetch(av, i, TRUE);
            if ( ! check_type(subval, newflags, NULL) ) {
                return FALSE;
            }
        }
        return TRUE;
    }

    if ( flags & TYPE_HASHREF ) {
        if ( !IsHashRef(val) ) {
            return FALSE;
        }
        if ( flags == TYPE_HASHREF ) {
            return TRUE;
        }
        int newflags = flags & ( TYPE_HASHREF - 1 );
        HV* const hv = (HV*)SvRV(val);
        HE* he;
        hv_iterinit(hv);
        while ((he = hv_iternext(hv))) {
            SV* const subval = hv_iterval(hv, he);
            if ( ! check_type(subval, newflags, NULL) ) {
                hv_iterinit(hv); /* reset */
                return FALSE;
            }
        }
        return TRUE;
    }
    
    switch ( flags ) {
        case TYPE_BASE_ANY:
            return TRUE;
        case TYPE_BASE_DEFINED:
            return SvOK(val);
        case TYPE_BASE_REF:
            return SvOK(val) && SvROK(val);
        case TYPE_BASE_BOOL: {
            if ( SvROK(val) || isGV(val) ) {
                return FALSE;
            }
            else if ( sv_true( val ) ) {
                if ( SvPOKp(val) ) {
                    // String "1"
                    return SvCUR(val) == 1 && SvPVX(val)[0] == '1';
                }
                else if ( SvIOKp(val) ) {
                    // Integer 1
                    return SvIVX(val) == 1;
                }
                else if( SvNOKp(val) ) {
                    // Float 1.0
                    return SvNVX(val) == 1.0;
                }
                else {
                    // Another way to check for string "1"???
                    STRLEN len;
                    char* ptr = SvPV(val, len);
                    return len == 1 && ptr[0] == '1';
                }
            }
            else {
                // Any non-reference non-true value (0, undef, "", "0")
                // is a valid Bool.
                return TRUE;
            }
        }
        case TYPE_BASE_INT:
            if ( SvOK(val) && !SvROK(val) && !isGV(val) ) {
                if ( SvPOK(val) ) {
                    return _S_pv_is_integer( SvPVX(val) );
                }
                else if ( SvIOK(val) ) {
                    return TRUE;
                }
                else if ( SvNOK(val) ) {
                    return _S_nv_is_integer( SvNVX(val) );
                }
            }
            return FALSE;
        case TYPE_BASE_PZINT: {
            if ( (!SvOK(val)) || SvROK(val) || isGV(val) ) {
                return FALSE;
            }
            if ( SvPOKp(val) ){
                if ( ! _S_pv_is_integer( SvPVX(val) ) ) {
                    return FALSE;
                }
            }
            else if ( SvIOKp(val) ) {
                /* ok */
            }
            else if ( SvNOKp(val) ) {
                if ( ! _S_nv_is_integer( SvNVX(val) ) ) {
                    return FALSE;
                }
            }
            STRLEN len;
            char* i = SvPVx(val, len);
            return ( (len > 0 && i[0] != '-') ? TRUE : FALSE );
        }
        case TYPE_BASE_NUM:
            // In Perl We Trust
            return looks_like_number(val);
        case TYPE_BASE_PZNUM:
            if ( ! looks_like_number(val) ) {
                return FALSE;
            }
            NV numeric = SvNV(val);
            return numeric >= 0.0;
        case TYPE_BASE_STR:
            return SvOK(val) && !SvROK(val) && !isGV(val);
        case TYPE_BASE_NESTR:
            if ( SvOK(val) && !SvROK(val) && !isGV(val) ) {
                STRLEN l = sv_len(val);
                return ( (l==0) ? FALSE : TRUE );
            }
            return FALSE;
        case TYPE_BASE_CLASSNAME:
            return _is_class_loaded(val);
        case TYPE_BASE_OBJECT:
            return IsObject(val);
        case TYPE_BASE_SCALARREF:
            return IsScalarRef(val);
        case TYPE_BASE_CODEREF:
            return IsCodeRef(val);
        case TYPE_OTHER:
            croak("PANIC!");
        default:
            croak("PANIC!");
    }
}

// Macro version which falls back to the full version
#define CHECK_TYPE(ok, val, flags, check_cv)                      \
    STMT_START {                                                  \
        switch (flags) {                                          \
            case TYPE_BASE_ANY:                                   \
                (ok) = TRUE;                                      \
                break;                                            \
                                                                  \
            case TYPE_BASE_DEFINED:                               \
                (ok) = SvOK(val);                                 \
                break;                                            \
                                                                  \
            case TYPE_BASE_REF:                                   \
                (ok) = SvOK(val) && SvROK(val);                   \
                break;                                            \
                                                                  \
            case TYPE_BASE_BOOL: {                                \
                if (SvROK(val) || isGV(val)) {                    \
                    (ok) = FALSE;                                 \
                }                                                 \
                else if (sv_true(val)) {                          \
                    if (SvPOKp(val)) {                            \
                        (ok) =                                    \
                            SvCUR(val) == 1 &&                    \
                            SvPVX(val)[0] == '1';                 \
                    }                                             \
                    else if (SvIOKp(val)) {                       \
                        (ok) = (SvIVX(val) == 1);                 \
                    }                                             \
                    else if (SvNOKp(val)) {                       \
                        (ok) = (SvNVX(val) == 1.0);               \
                    }                                             \
                    else {                                        \
                        STRLEN len;                               \
                        char *ptr = SvPV(val, len);               \
                        (ok) = (len == 1 && ptr[0] == '1');       \
                    }                                             \
                }                                                 \
                else {                                            \
                    (ok) = TRUE;                                  \
                }                                                 \
                break;                                            \
            }                                                     \
                                                                  \
            case TYPE_BASE_INT:                                   \
                if (SvOK(val) && !SvROK(val) && !isGV(val)) {     \
                    if (SvPOK(val)) {                             \
                        (ok) = _S_pv_is_integer(SvPVX(val));      \
                    }                                             \
                    else if (SvIOK(val)) {                        \
                        (ok) = TRUE;                              \
                    }                                             \
                    else if (SvNOK(val)) {                        \
                        (ok) = _S_nv_is_integer(SvNVX(val));      \
                    }                                             \
                    else {                                        \
                        (ok) = FALSE;                             \
                    }                                             \
                }                                                 \
                else {                                            \
                    (ok) = FALSE;                                 \
                }                                                 \
                break;                                            \
                                                                  \
            case TYPE_BASE_PZINT: {                               \
                if (!SvOK(val) || SvROK(val) || isGV(val)) {      \
                    (ok) = FALSE;                                 \
                    break;                                        \
                }                                                 \
                if (SvPOKp(val)) {                                \
                    if (!_S_pv_is_integer(SvPVX(val))) {          \
                        (ok) = FALSE;                             \
                        break;                                    \
                    }                                             \
                }                                                 \
                else if (SvNOKp(val)) {                           \
                    if (!_S_nv_is_integer(SvNVX(val))) {          \
                        (ok) = FALSE;                             \
                        break;                                    \
                    }                                             \
                }                                                 \
                STRLEN len;                                       \
                char *i = SvPVx(val, len);                        \
                (ok) = (len > 0 && i[0] != '-');                  \
                break;                                            \
            }                                                     \
                                                                  \
            case TYPE_BASE_NUM:                                   \
                (ok) = looks_like_number(val);                    \
                break;                                            \
                                                                  \
            case TYPE_BASE_PZNUM:                                 \
                if (!looks_like_number(val)) {                    \
                    (ok) = FALSE;                                 \
                }                                                 \
                else {                                            \
                    NV n = SvNV(val);                             \
                    (ok) = (n >= 0.0);                            \
                }                                                 \
                break;                                            \
                                                                  \
            case TYPE_BASE_STR:                                   \
                (ok) = SvOK(val) && !SvROK(val) && !isGV(val);    \
                break;                                            \
                                                                  \
            case TYPE_BASE_NESTR:                                 \
                if (SvOK(val) && !SvROK(val) && !isGV(val)) {     \
                    STRLEN l = sv_len(val);                       \
                    (ok) = (l != 0);                              \
                }                                                 \
                else {                                            \
                    (ok) = FALSE;                                 \
                }                                                 \
                break;                                            \
                                                                  \
            case TYPE_BASE_CLASSNAME:                             \
                (ok) = _is_class_loaded(val);                     \
                break;                                            \
                                                                  \
            case TYPE_BASE_OBJECT:                                \
                (ok) = IsObject(val);                             \
                break;                                            \
                                                                  \
            case TYPE_BASE_SCALARREF:                             \
                (ok) = IsScalarRef(val);                          \
                break;                                            \
                                                                  \
            case TYPE_BASE_CODEREF:                               \
                (ok) = IsCodeRef(val);                            \
                break;                                            \
                                                                  \
            case TYPE_ARRAYREF:                                   \
                (ok) = IsArrayRef(val);                           \
                break;                                            \
                                                                  \
            case TYPE_HASHREF:                                    \
                (ok) = IsHashRef(val);                            \
                break;                                            \
                                                                  \
            default:                                              \
                (ok) = check_type(val, flags, check_cv);          \
                break;                                            \
        }                                                         \
    } STMT_END

#define TRY_COERCE_TYPE(ok, val, flags, check_cv, coercion_cv)    \
    STMT_START {                                                  \
        if (!(ok) && (coercion_cv) != NULL) {                     \
            dSP;                                                  \
            ENTER; SAVETMPS;                                      \
            PUSHMARK(SP);                                         \
            XPUSHs(val);                                          \
            PUTBACK;                                              \
            SV *newval = NULL;                                    \
            I32 count = call_sv((SV*)(coercion_cv), G_SCALAR);    \
            SPAGAIN;                                              \
            if (count > 0) {                                      \
                newval = newSVsv(POPs);                           \
                if (check_type(newval, flags, check_cv)) {        \
                    ok = TRUE;                                    \
                    val = newval;                                 \
                }                                                 \
            }                                                     \
            FREETMPS; LEAVE;                                      \
        }                                                         \
    } STMT_END

const char *
type_name(I32 type_flags)
{
    static char buf[64];

    /* Extract container flags */
    bool is_array = (type_flags & TYPE_ARRAYREF) != 0;
    bool is_hash  = (type_flags & TYPE_HASHREF)  != 0;

    /* Not supported */
    if (is_array && is_hash) {
        return "Unknown";
    }

    /* Extract base type (low 4 bits) */
    I32 base = type_flags & 0x0F;

    const char *base_name;

    switch (base) {
        case TYPE_BASE_ANY:        base_name = "Any";                  break;
        case TYPE_BASE_DEFINED:    base_name = "Defined";              break;
        case TYPE_BASE_REF:        base_name = "Ref";                  break;
        case TYPE_BASE_BOOL:       base_name = "Bool";                 break;
        case TYPE_BASE_INT:        base_name = "Int";                  break;
        case TYPE_BASE_PZINT:      base_name = "PositiveOrZeroInt";    break;
        case TYPE_BASE_NUM:        base_name = "Num";                  break;
        case TYPE_BASE_PZNUM:      base_name = "PositiveOrZeroNum";    break;
        case TYPE_BASE_STR:        base_name = "Str";                  break;
        case TYPE_BASE_NESTR:      base_name = "NonEmptyStr";          break;
        case TYPE_BASE_CLASSNAME:  base_name = "ClassName";            break;
        case TYPE_BASE_OBJECT:     base_name = "Object";               break;
        case TYPE_BASE_SCALARREF:  base_name = "ScalarRef";            break;
        case TYPE_BASE_CODEREF:    base_name = "CodeRef";              break;
        case TYPE_OTHER:           base_name = "Unknown";              break;
        default:                   base_name = "Unknown";              break;
    }

    if (is_array) {
        snprintf(buf, sizeof(buf), "ArrayRef[%s]", base_name);
        return buf;
    }

    if (is_hash) {
        snprintf(buf, sizeof(buf), "HashRef[%s]", base_name);
        return buf;
    }

    return base_name;
}

void
type_error(SV *val, char *varname, I32 ix,
           I32 element_type, SV *element_type_tiny)
{
    dTHX;
    dSP;

    /* Normalize val */
    if (!val)
        val = &PL_sv_undef;

    /* Build full_varname */
    SV *full_varname;

    if (varname) {
        if (ix < 0) {
            full_varname = newSVpv(varname, 0);
        }
        else {
            full_varname = newSVpvf("%s[%" IVdf "]", varname, (IV)ix);
        }
    }
    else {
        full_varname = newSVpvs("$_");
    }

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);

    if (element_type_tiny && SvROK(element_type_tiny) && SvOBJECT(SvRV(element_type_tiny)))
    {
        /* invocant: blessed Type::Tiny object */
        XPUSHs(element_type_tiny);
        /* undef as type name because _failed_check can extract from invocant */
        XPUSHs(&PL_sv_undef);
        /* failing value */
        XPUSHs(sv_2mortal(newSVsv(val)));
        /* varname => $full_varname */
        XPUSHs(sv_2mortal(newSVpvs("varname")));
        XPUSHs(sv_2mortal(full_varname));
        PUTBACK;

        call_method("_failed_check", G_VOID | G_DISCARD);
    }
    else {
        /* invocant: undef */
        XPUSHs(&PL_sv_undef);
        /* type name */
        SV *type_name_sv = sv_2mortal(newSVpv(type_name(element_type), 0));
        XPUSHs(type_name_sv);
        /* failing value */
        XPUSHs(sv_2mortal(newSVsv(val)));
        /* varname => $full_varname */
        XPUSHs(sv_2mortal(newSVpvs("varname")));
        XPUSHs(sv_2mortal(full_varname));
        PUTBACK;

        call_pv("Type::Tiny::_failed_check", G_VOID | G_DISCARD);
    }

    /* Never returns normally */
    FREETMPS;
    LEAVE;
}


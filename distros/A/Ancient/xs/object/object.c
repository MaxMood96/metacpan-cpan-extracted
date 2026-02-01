#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "object_compat.h"

/* Object flags - stored in mg_private */
#define OBJ_FLAG_LOCKED  0x01
#define OBJ_FLAG_FROZEN  0x02

/* Built-in type IDs for inline checks */
typedef enum {
    TYPE_NONE = 0,
    TYPE_ANY,
    TYPE_DEFINED,
    TYPE_STR,
    TYPE_INT,
    TYPE_NUM,
    TYPE_BOOL,
    TYPE_ARRAYREF,
    TYPE_HASHREF,
    TYPE_CODEREF,
    TYPE_OBJECT,
    TYPE_CUSTOM       /* Uses registered or callback check */
} BuiltinTypeID;

/* Type check/coerce function signatures for external plugins */
typedef bool (*ObjectTypeCheckFunc)(pTHX_ SV *val);
typedef SV*  (*ObjectTypeCoerceFunc)(pTHX_ SV *val);

/* Registered type entry (for plugins) */
typedef struct {
    char *name;
    ObjectTypeCheckFunc check;      /* C function for type check */
    ObjectTypeCoerceFunc coerce;    /* C function for coercion */
    SV *perl_check;                 /* Fallback Perl callback */
    SV *perl_coerce;                /* Fallback Perl coercion */
} RegisteredType;

/* Per-slot specification - parsed from "name:Type:default(val)" */
typedef struct {
    char *name;
    BuiltinTypeID type_id;          /* Built-in type or TYPE_CUSTOM */
    RegisteredType *registered;     /* For external XS types */
    SV *default_sv;                 /* Default value (immutable, refcnt'd) */
    SV *trigger_cb;                 /* Trigger callback */
    SV *coerce_cb;                  /* Coercion callback (Perl) */
    U8 is_required;                 /* Croak if not provided in new() */
    U8 is_readonly;                 /* Croak if set after new() */
    U8 has_default;
    U8 has_trigger;
    U8 has_coerce;
    U8 has_type;
} SlotSpec;

/* Custom op definitions */
static XOP object_new_xop;
static XOP object_get_xop;
static XOP object_set_xop;
static XOP object_set_typed_xop;

/* Per-class metadata */
typedef struct {
    char *class_name;
    HV *prop_to_idx;      /* property name -> slot index */
    char **idx_to_prop;   /* slot index -> property name */
    IV slot_count;
    HV *stash;            /* cached stash pointer */
    /* Type system extensions */
    SlotSpec **slots;     /* Per-slot specifications, NULL if no specs */
    U8 has_any_types;     /* Quick check: any slot has type checking? */
    U8 has_any_defaults;  /* Quick check: any slot has defaults? */
    U8 has_any_triggers;  /* Quick check: any slot has triggers? */
    U8 has_any_required;  /* Quick check: any slot is required? */
} ClassMeta;

/* Global class registry */
static HV *g_class_registry = NULL;  /* class name -> ClassMeta* */

/* Global type registry for external plugins */
static HV *g_type_registry = NULL;   /* type name -> RegisteredType* */

/* Forward declarations */
static ClassMeta* get_class_meta(pTHX_ const char *class_name, STRLEN len);
static void install_constructor(pTHX_ const char *class_name, ClassMeta *meta);
static void install_accessor(pTHX_ const char *class_name, const char *prop_name, IV idx);
static void install_accessor_typed(pTHX_ const char *class_name, const char *prop_name, IV idx, ClassMeta *meta);

/* ============================================
   Built-in type checking (inline)
   ============================================ */

static inline BuiltinTypeID parse_builtin_type(const char *type_str, STRLEN len) {
    if (len == 3 && strEQ(type_str, "Str")) return TYPE_STR;
    if (len == 3 && strEQ(type_str, "Int")) return TYPE_INT;
    if (len == 3 && strEQ(type_str, "Num")) return TYPE_NUM;
    if (len == 3 && strEQ(type_str, "Any")) return TYPE_ANY;
    if (len == 4 && strEQ(type_str, "Bool")) return TYPE_BOOL;
    if (len == 6 && strEQ(type_str, "Object")) return TYPE_OBJECT;
    if (len == 7 && strEQ(type_str, "Defined")) return TYPE_DEFINED;
    if (len == 7 && strEQ(type_str, "CodeRef")) return TYPE_CODEREF;
    if (len == 7 && strEQ(type_str, "HashRef")) return TYPE_HASHREF;
    if (len == 8 && strEQ(type_str, "ArrayRef")) return TYPE_ARRAYREF;
    return TYPE_NONE;  /* Unknown - could be custom */
}

/* Inline type check - returns true if value passes check */
static inline bool check_builtin_type(pTHX_ SV *val, BuiltinTypeID type_id) {
    switch (type_id) {
        case TYPE_ANY:
            return true;
        case TYPE_DEFINED:
            return SvOK(val);
        case TYPE_STR:
            return SvOK(val) && !SvROK(val);  /* defined non-ref */
        case TYPE_INT:
            if (SvIOK(val)) return true;
            if (SvPOK(val)) {
                /* String that looks like integer */
                STRLEN len;
                const char *pv = SvPV(val, len);
                if (len == 0) return false;
                const char *p = pv;
                if (*p == '-' || *p == '+') p++;
                while (*p && *p >= '0' && *p <= '9') p++;
                return p == pv + len;
            }
            return false;
        case TYPE_NUM:
            return SvNIOK(val) || (SvPOK(val) && looks_like_number(val));
        case TYPE_BOOL:
            /* Accept 0, 1, "", or boolean SVs */
            if (SvIOK(val)) {
                IV iv = SvIV(val);
                return iv == 0 || iv == 1;
            }
            return SvTRUE(val) || !SvOK(val) || (SvPOK(val) && SvCUR(val) == 0);
        case TYPE_ARRAYREF:
            return SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV;
        case TYPE_HASHREF:
            return SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVHV;
        case TYPE_CODEREF:
            return SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVCV;
        case TYPE_OBJECT:
            return SvROK(val) && sv_isobject(val);
        default:
            return true;  /* No check or unknown */
    }
}

/* Get type name for error messages */
static const char* type_id_to_name(BuiltinTypeID type_id) {
    switch (type_id) {
        case TYPE_ANY: return "Any";
        case TYPE_DEFINED: return "Defined";
        case TYPE_STR: return "Str";
        case TYPE_INT: return "Int";
        case TYPE_NUM: return "Num";
        case TYPE_BOOL: return "Bool";
        case TYPE_ARRAYREF: return "ArrayRef";
        case TYPE_HASHREF: return "HashRef";
        case TYPE_CODEREF: return "CodeRef";
        case TYPE_OBJECT: return "Object";
        case TYPE_CUSTOM: return "custom";
        default: return "unknown";
    }
}

/* Check a value against a slot's type constraint (handles both C and Perl callbacks) */
static bool check_slot_type(pTHX_ SV *val, SlotSpec *spec) {
    if (!spec || !spec->has_type) return true;
    
    if (spec->type_id != TYPE_CUSTOM) {
        return check_builtin_type(aTHX_ val, spec->type_id);
    }
    
    if (!spec->registered) return true;
    
    /* Try C function first (fast path - ~5 cycles) */
    if (spec->registered->check) {
        return spec->registered->check(aTHX_ val);
    }
    
    /* Fall back to Perl callback (~100 cycles) */
    if (spec->registered->perl_check) {
        dSP;
        int count;
        bool result;
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(val);
        PUTBACK;
        count = call_sv(spec->registered->perl_check, G_SCALAR);
        SPAGAIN;
        result = (count > 0) ? SvTRUE(POPs) : false;
        FREETMPS;
        LEAVE;
        return result;
    }
    
    return true;
}

/* ============================================
   Slot spec parser: "name:Type:default(val)"
   ============================================ */

static SlotSpec* parse_slot_spec(pTHX_ const char *spec_str, STRLEN len) {
    SlotSpec *spec;
    const char *p = spec_str;
    const char *end = spec_str + len;
    const char *name_start, *name_end;
    
    Newxz(spec, 1, SlotSpec);
    
    /* Parse property name (before first ':') */
    name_start = p;
    while (p < end && *p != ':') p++;
    name_end = p;
    
    STRLEN name_len = name_end - name_start;
    Newx(spec->name, name_len + 1, char);
    Copy(name_start, spec->name, name_len, char);
    spec->name[name_len] = '\0';
    
    /* Parse modifiers after name */
    while (p < end) {
        if (*p == ':') p++;  /* Skip separator */
        if (p >= end) break;
        
        const char *mod_start = p;
        
        /* Check for function-style modifiers: default(...), trigger(...) */
        while (p < end && *p != ':' && *p != '(') p++;
        
        STRLEN mod_len = p - mod_start;
        
        if (p < end && *p == '(') {
            /* Function-style: default(value) or trigger(&callback) */
            const char *arg_start = ++p;
            int paren_depth = 1;
            while (p < end && paren_depth > 0) {
                if (*p == '(') paren_depth++;
                else if (*p == ')') paren_depth--;
                p++;
            }
            const char *arg_end = p - 1;  /* Before closing paren */
            STRLEN arg_len = arg_end - arg_start;
            
            if (mod_len == 7 && strncmp(mod_start, "default", 7) == 0) {
                /* Parse default value */
                spec->has_default = 1;
                /* Simple default: copy as string and eval at runtime */
                /* For now, support literal numbers and strings */
                if (arg_len > 0) {
                    char *arg_copy;
                    Newx(arg_copy, arg_len + 1, char);
                    Copy(arg_start, arg_copy, arg_len, char);
                    arg_copy[arg_len] = '\0';
                    
                    /* Try to parse as number */
                    if (arg_copy[0] >= '0' && arg_copy[0] <= '9') {
                        if (strchr(arg_copy, '.')) {
                            spec->default_sv = newSVnv(atof(arg_copy));
                        } else {
                            spec->default_sv = newSViv(atoi(arg_copy));
                        }
                    } else if (arg_copy[0] == '-' && arg_len > 1) {
                        if (strchr(arg_copy, '.')) {
                            spec->default_sv = newSVnv(atof(arg_copy));
                        } else {
                            spec->default_sv = newSViv(atoi(arg_copy));
                        }
                    } else if (arg_copy[0] == '\'' || arg_copy[0] == '"') {
                        /* String literal - strip quotes */
                        if (arg_len >= 2) {
                            spec->default_sv = newSVpvn(arg_copy + 1, arg_len - 2);
                        } else {
                            spec->default_sv = newSVpvn("", 0);
                        }
                    } else if (strncmp(arg_copy, "undef", 5) == 0) {
                        spec->default_sv = newSV(0);
                    } else if (strncmp(arg_copy, "[]", 2) == 0) {
                        spec->default_sv = newRV_noinc((SV*)newAV());
                    } else if (strncmp(arg_copy, "{}", 2) == 0) {
                        spec->default_sv = newRV_noinc((SV*)newHV());
                    } else {
                        /* Default to string */
                        spec->default_sv = newSVpvn(arg_copy, arg_len);
                    }
                    Safefree(arg_copy);
                }
            } else if (mod_len == 7 && strncmp(mod_start, "trigger", 7) == 0) {
                /* trigger(&callback) - store callback name for later resolution */
                spec->has_trigger = 1;
                /* Note: callback resolution happens at runtime in Perl layer */
                /* For now, store as string - will be resolved in object.pm */
                if (arg_len > 0) {
                    char *cb_copy;
                    Newx(cb_copy, arg_len + 1, char);
                    Copy(arg_start, cb_copy, arg_len, char);
                    cb_copy[arg_len] = '\0';
                    /* Store as SV for later resolution */
                    spec->trigger_cb = newSVpvn(cb_copy, arg_len);
                    Safefree(cb_copy);
                }
            } else if (mod_len == 6 && strncmp(mod_start, "coerce", 6) == 0) {
                /* coerce(&callback) */
                spec->has_coerce = 1;
                if (arg_len > 0) {
                    char *cb_copy;
                    Newx(cb_copy, arg_len + 1, char);
                    Copy(arg_start, cb_copy, arg_len, char);
                    cb_copy[arg_len] = '\0';
                    spec->coerce_cb = newSVpvn(cb_copy, arg_len);
                    Safefree(cb_copy);
                }
            }
        } else {
            /* Simple modifier: type name or flag */
            if (mod_len == 8 && strncmp(mod_start, "required", 8) == 0) {
                spec->is_required = 1;
            } else if (mod_len == 8 && strncmp(mod_start, "readonly", 8) == 0) {
                spec->is_readonly = 1;
            } else {
                /* Try as type name */
                char *type_copy;
                Newx(type_copy, mod_len + 1, char);
                Copy(mod_start, type_copy, mod_len, char);
                type_copy[mod_len] = '\0';
                
                BuiltinTypeID type_id = parse_builtin_type(type_copy, mod_len);
                if (type_id != TYPE_NONE) {
                    spec->type_id = type_id;
                    spec->has_type = 1;
                } else {
                    /* Check type registry for custom types */
                    if (g_type_registry) {
                        SV **svp = hv_fetch(g_type_registry, type_copy, mod_len, 0);
                        if (svp) {
                            spec->registered = INT2PTR(RegisteredType*, SvIV(*svp));
                            spec->type_id = TYPE_CUSTOM;
                            spec->has_type = 1;
                        }
                    }
                }
                Safefree(type_copy);
            }
        }
    }
    
    return spec;
}

/* Magic vtable for object flags */
static MGVTBL object_magic_vtbl = {
    NULL,  /* get */
    NULL,  /* set */
    NULL,  /* len */
    NULL,  /* clear */
    NULL,  /* free */
    NULL,  /* copy */
    NULL,  /* dup */
    NULL   /* local */
};

/* Get object magic (for flags) */
static MAGIC* get_object_magic(pTHX_ SV *obj) {
    MAGIC *mg;
    if (!SvROK(obj)) return NULL;
    mg = mg_find(SvRV(obj), PERL_MAGIC_ext);
    while (mg) {
        if (mg->mg_virtual == &object_magic_vtbl) return mg;
        mg = mg->mg_moremagic;
    }
    return NULL;
}

/* Add object magic */
static MAGIC* add_object_magic(pTHX_ SV *obj) {
    MAGIC *mg;
    SV *rv = SvRV(obj);
    mg = sv_magicext(rv, NULL, PERL_MAGIC_ext, &object_magic_vtbl, NULL, 0);
    mg->mg_private = 0;  /* flags */
    return mg;
}

/* ============================================
   Class definition and registration
   ============================================ */

static ClassMeta* create_class_meta(pTHX_ const char *class_name, STRLEN len) {
    ClassMeta *meta;
    Newxz(meta, 1, ClassMeta);
    Newxz(meta->class_name, len + 1, char);
    Copy(class_name, meta->class_name, len, char);
    meta->class_name[len] = '\0';
    meta->prop_to_idx = newHV();
    meta->idx_to_prop = NULL;
    meta->slot_count = 1;  /* slot 0 reserved for prototype */
    meta->stash = gv_stashpvn(class_name, len, GV_ADD);
    return meta;
}

static ClassMeta* get_class_meta(pTHX_ const char *class_name, STRLEN len) {
    SV **svp;
    if (!g_class_registry) return NULL;
    svp = hv_fetch(g_class_registry, class_name, len, 0);
    if (svp && SvIOK(*svp)) {
        return INT2PTR(ClassMeta*, SvIV(*svp));
    }
    return NULL;
}

static void register_class_meta(pTHX_ const char *class_name, STRLEN len, ClassMeta *meta) {
    if (!g_class_registry) {
        g_class_registry = newHV();
    }
    hv_store(g_class_registry, class_name, len, newSViv(PTR2IV(meta)), 0);
}

/* ============================================
   Custom OP: object constructor
   ============================================ */

/* pp_object_new - create new object, class info in op_targ, args on stack */
static OP* pp_object_new(pTHX) {
    dSP; dMARK;
    IV items = SP - MARK;
    ClassMeta *meta = INT2PTR(ClassMeta*, PL_op->op_targ);
    AV *obj_av;
    SV *obj_sv;
    IV i;
    U32 is_named = PL_op->op_private;  /* 1 = named pairs, 0 = positional */

    /* Create array with pre-extended size */
    obj_av = newAV();
    av_extend(obj_av, meta->slot_count - 1);

    /* Slot 0 = prototype (initially undef) */
    av_store(obj_av, 0, &PL_sv_undef);

    if (is_named) {
        /* Named pairs: name => value, name => value */
        for (i = 0; i < items; i += 2) {
            SV *key_sv = MARK[i + 1];
            SV *val_sv = (i + 1 < items) ? MARK[i + 2] : &PL_sv_undef;
            STRLEN key_len;
            const char *key = SvPV(key_sv, key_len);
            SV **idx_svp = hv_fetch(meta->prop_to_idx, key, key_len, 0);
            if (idx_svp && SvIOK(*idx_svp)) {
                IV idx = SvIV(*idx_svp);
                
                /* Type check on construction if slot has type */
                if (meta->slots && meta->slots[idx] && meta->slots[idx]->has_type) {
                    SlotSpec *spec = meta->slots[idx];
                    if (spec->type_id != TYPE_CUSTOM) {
                        if (!check_builtin_type(aTHX_ val_sv, spec->type_id)) {
                            croak("Type constraint failed for '%s' in new(): expected %s",
                                  spec->name, type_id_to_name(spec->type_id));
                        }
                    } else if (spec->registered && spec->registered->check) {
                        if (!spec->registered->check(aTHX_ val_sv)) {
                            croak("Type constraint failed for '%s' in new(): expected %s",
                                  spec->name, spec->registered->name);
                        }
                    }
                }
                av_store(obj_av, idx, newSVsv(val_sv));
            }
        }
    } else {
        /* Positional: value, value, value */
        for (i = 0; i < items && i < meta->slot_count - 1; i++) {
            IV idx = i + 1;
            SV *val_sv = MARK[i + 1];
            
            /* Type check on construction if slot has type */
            if (meta->slots && meta->slots[idx] && meta->slots[idx]->has_type) {
                SlotSpec *spec = meta->slots[idx];
                if (spec->type_id != TYPE_CUSTOM) {
                    if (!check_builtin_type(aTHX_ val_sv, spec->type_id)) {
                        croak("Type constraint failed for '%s' in new(): expected %s",
                              spec->name, type_id_to_name(spec->type_id));
                    }
                } else if (spec->registered && spec->registered->check) {
                    if (!spec->registered->check(aTHX_ val_sv)) {
                        croak("Type constraint failed for '%s' in new(): expected %s",
                              spec->name, spec->registered->name);
                    }
                }
            }
            av_store(obj_av, idx, newSVsv(val_sv));
        }
    }

    /* Fill unset slots with defaults or undef, check required */
    for (i = 1; i < meta->slot_count; i++) {
        SV **existing = av_fetch(obj_av, i, 0);
        if (!existing || !SvOK(*existing)) {
            SlotSpec *spec = (meta->slots) ? meta->slots[i] : NULL;
            
            if (spec && spec->is_required) {
                croak("Required slot '%s' not provided in new()", spec->name);
            }
            
            if (spec && spec->has_default && spec->default_sv) {
                /* Clone the default value (in case it's a reference) */
                if (SvROK(spec->default_sv)) {
                    /* For refs, create fresh copy each time */
                    if (SvTYPE(SvRV(spec->default_sv)) == SVt_PVAV) {
                        av_store(obj_av, i, newRV_noinc((SV*)newAV()));
                    } else if (SvTYPE(SvRV(spec->default_sv)) == SVt_PVHV) {
                        av_store(obj_av, i, newRV_noinc((SV*)newHV()));
                    } else {
                        av_store(obj_av, i, newSVsv(spec->default_sv));
                    }
                } else {
                    av_store(obj_av, i, newSVsv(spec->default_sv));
                }
            } else {
                av_store(obj_av, i, newSV(0));
            }
        }
    }

    /* Create blessed reference */
    obj_sv = newRV_noinc((SV*)obj_av);
    sv_bless(obj_sv, meta->stash);

    /* Magic for lock/freeze is added lazily when first needed */

    SP = MARK;
    XPUSHs(obj_sv);
    PUTBACK;
    return NORMAL;
}

/* ============================================
   Custom OP: property accessor (get)
   ============================================ */

static OP* pp_object_get(pTHX) {
    dSP;
    SV *obj = TOPs;
    IV idx = PL_op->op_targ;
    AV *av;
    SV **svp;

    if (!SvROK(obj) || SvTYPE(SvRV(obj)) != SVt_PVAV) {
        croak("Not an object");
    }

    av = (AV*)SvRV(obj);
    svp = av_fetch(av, idx, 0);
    
    if (svp && SvOK(*svp)) {
        SETs(*svp);
    } else {
        /* Check prototype chain */
        SV **proto_svp = av_fetch(av, 0, 0);
        if (proto_svp && SvROK(*proto_svp)) {
            /* Recurse into prototype - for now, simple one-level */
            AV *proto_av = (AV*)SvRV(*proto_svp);
            svp = av_fetch(proto_av, idx, 0);
            if (svp && SvOK(*svp)) {
                SETs(*svp);
                RETURN;
            }
        }
        SETs(&PL_sv_undef);
    }
    RETURN;
}

/* ============================================
   Custom OP: property accessor (set)
   ============================================ */

static OP* pp_object_set(pTHX) {
    dSP;
    SV *val = POPs;
    SV *obj = TOPs;
    IV idx = PL_op->op_targ;
    AV *av;
    MAGIC *mg;

    if (!SvROK(obj) || SvTYPE(SvRV(obj)) != SVt_PVAV) {
        croak("Not an object");
    }

    av = (AV*)SvRV(obj);

    /* Check frozen/locked */
    mg = get_object_magic(aTHX_ obj);
    if (mg && (mg->mg_private & OBJ_FLAG_FROZEN)) {
        croak("Cannot modify frozen object");
    }

    av_store(av, idx, newSVsv(val));
    SETs(val);
    RETURN;
}

/* ============================================
   Custom OP: property accessor (set) with type check
   Uses op_private to store type ID for inline check
   ============================================ */

/* Helper struct to pass both idx and meta through op */
typedef struct {
    IV slot_idx;
    ClassMeta *meta;
} SlotOpData;

static OP* pp_object_set_typed(pTHX) {
    dSP;
    SV *val = POPs;
    SV *obj = TOPs;
    SlotOpData *data = INT2PTR(SlotOpData*, PL_op->op_targ);
    IV idx = data->slot_idx;
    ClassMeta *meta = data->meta;
    SlotSpec *spec = meta->slots[idx];
    AV *av;
    MAGIC *mg;

    if (!SvROK(obj) || SvTYPE(SvRV(obj)) != SVt_PVAV) {
        croak("Not an object");
    }

    av = (AV*)SvRV(obj);

    /* Check frozen/locked */
    mg = get_object_magic(aTHX_ obj);
    if (mg && (mg->mg_private & OBJ_FLAG_FROZEN)) {
        croak("Cannot modify frozen object");
    }

    /* Readonly check */
    if (spec->is_readonly) {
        croak("Cannot modify readonly slot '%s'", spec->name);
    }

    /* Coercion (if callback exists) */
    if (spec->has_coerce && spec->coerce_cb) {
        dSP;
        PUSHMARK(SP);
        XPUSHs(val);
        PUTBACK;
        call_sv(spec->coerce_cb, G_SCALAR);
        SPAGAIN;
        val = POPs;
        PUTBACK;
    }

    /* External XS type coercion (C function - fast path) */
    if (spec->type_id == TYPE_CUSTOM && spec->registered && spec->registered->coerce) {
        val = spec->registered->coerce(aTHX_ val);
    }

    /* Type check using helper (handles both C and Perl callbacks) */
    if (spec->has_type) {
        if (!check_slot_type(aTHX_ val, spec)) {
            const char *type_name = (spec->type_id == TYPE_CUSTOM && spec->registered)
                ? spec->registered->name
                : type_id_to_name(spec->type_id);
            croak("Type constraint failed for '%s': expected %s",
                  spec->name, type_name);
        }
    }

    /* Trigger callback (old, new) */
    if (spec->has_trigger && spec->trigger_cb) {
        SV *oldval = *av_fetch(av, idx, 0);
        dSP;
        PUSHMARK(SP);
        XPUSHs(obj);
        XPUSHs(oldval);
        XPUSHs(val);
        PUTBACK;
        call_sv(spec->trigger_cb, G_DISCARD);
    }

    av_store(av, idx, newSVsv(val));
    SETs(val);
    RETURN;
}

/* ============================================
   Call checker for accessor
   ============================================ */

static OP* accessor_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    IV idx = SvIV(ckobj);
    OP *pushop, *cvop, *selfop, *argop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    selfop = OpSIBLING(pushop);
    cvop = selfop;
    argop = selfop;
    while (OpHAS_SIBLING(cvop)) {
        argop = cvop;
        cvop = OpSIBLING(cvop);
    }

    /* Check if there's an argument after self (setter call) */
    if (argop != selfop) {
        /* Setter: $obj->name($value) */
        OP *valop = OpSIBLING(selfop);
        
        /* Detach self and val */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(valop, NULL);
        OpLASTSIB_set(selfop, NULL);
        
        /* Create binop with self and val */
        newop = newBINOP(OP_CUSTOM, 0, selfop, valop);
        newop->op_ppaddr = pp_object_set;
        newop->op_targ = idx;
        
        op_free(entersubop);
        return newop;
    } else {
        /* Getter: $obj->name */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(selfop, NULL);
        
        newop = newUNOP(OP_CUSTOM, 0, selfop);
        newop->op_ppaddr = pp_object_get;
        newop->op_targ = idx;
        
        op_free(entersubop);
        return newop;
    }
}

/* ============================================
   XS Fallback functions
   ============================================ */

/* XS fallback for new (when call checker can't optimize) */
static XS(xs_object_new_fallback) {
    dXSARGS;
    ClassMeta *meta = INT2PTR(ClassMeta*, CvXSUBANY(cv).any_iv);
    AV *obj_av;
    SV *obj_sv;
    IV i;
    IV start_arg = 0;
    IV arg_count;
    int is_named = 0;

    /* Skip class name if passed as invocant (Cat->new or new Cat) */
    if (items > 0 && SvPOK(ST(0)) && !SvROK(ST(0))) {
        STRLEN len;
        const char *pv = SvPV(ST(0), len);
        if (strEQ(pv, meta->class_name)) {
            start_arg = 1;
        }
    }

    arg_count = items - start_arg;

    /* Detect named pairs: even count and first arg is a known property name */
    if (arg_count > 0 && (arg_count % 2) == 0 && SvPOK(ST(start_arg))) {
        STRLEN len;
        const char *pv = SvPV(ST(start_arg), len);
        if (hv_exists(meta->prop_to_idx, pv, len)) {
            is_named = 1;
        }
    }

    obj_av = newAV();
    av_extend(obj_av, meta->slot_count - 1);
    av_store(obj_av, 0, &PL_sv_undef);

    if (is_named) {
        /* Named pairs: name => value, name => value */
        for (i = start_arg; i < items; i += 2) {
            SV *key_sv = ST(i);
            SV *val_sv = (i + 1 < items) ? ST(i + 1) : &PL_sv_undef;
            STRLEN key_len;
            const char *key = SvPV(key_sv, key_len);
            SV **idx_svp = hv_fetch(meta->prop_to_idx, key, key_len, 0);
            if (idx_svp && SvIOK(*idx_svp)) {
                IV idx = SvIV(*idx_svp);
                
                /* Type check on construction if slot has type */
                if (meta->slots && meta->slots[idx]) {
                    SlotSpec *spec = meta->slots[idx];
                    if (!check_slot_type(aTHX_ val_sv, spec)) {
                        const char *type_name = (spec->type_id == TYPE_CUSTOM && spec->registered) 
                            ? spec->registered->name 
                            : type_id_to_name(spec->type_id);
                        croak("Type constraint failed for '%s' in new(): expected %s",
                              spec->name, type_name);
                    }
                }
                av_store(obj_av, idx, newSVsv(val_sv));
            }
        }
    } else {
        /* Positional fallback - skip class name if present */
        for (i = start_arg; i < items && (i - start_arg) < meta->slot_count - 1; i++) {
            IV idx = (i - start_arg) + 1;
            SV *val_sv = ST(i);
            
            /* Type check on construction if slot has type */
            if (meta->slots && meta->slots[idx]) {
                SlotSpec *spec = meta->slots[idx];
                if (!check_slot_type(aTHX_ val_sv, spec)) {
                    const char *type_name = (spec->type_id == TYPE_CUSTOM && spec->registered) 
                        ? spec->registered->name 
                        : type_id_to_name(spec->type_id);
                    croak("Type constraint failed for '%s' in new(): expected %s",
                          spec->name, type_name);
                }
            }
            av_store(obj_av, idx, newSVsv(val_sv));
        }
    }

    /* Fill unset slots with defaults or undef, check required */
    for (i = 1; i < meta->slot_count; i++) {
        SV **existing = av_fetch(obj_av, i, 0);
        if (!existing || !SvOK(*existing)) {
            SlotSpec *spec = (meta->slots) ? meta->slots[i] : NULL;
            
            if (spec && spec->is_required) {
                croak("Required slot '%s' not provided in new()", spec->name);
            }
            
            if (spec && spec->has_default && spec->default_sv) {
                /* Clone the default value (in case it's a reference) */
                if (SvROK(spec->default_sv)) {
                    /* For refs, create fresh copy each time */
                    if (SvTYPE(SvRV(spec->default_sv)) == SVt_PVAV) {
                        av_store(obj_av, i, newRV_noinc((SV*)newAV()));
                    } else if (SvTYPE(SvRV(spec->default_sv)) == SVt_PVHV) {
                        av_store(obj_av, i, newRV_noinc((SV*)newHV()));
                    } else {
                        av_store(obj_av, i, newSVsv(spec->default_sv));
                    }
                } else {
                    av_store(obj_av, i, newSVsv(spec->default_sv));
                }
            } else {
                av_store(obj_av, i, newSV(0));
            }
        }
    }

    obj_sv = newRV_noinc((SV*)obj_av);
    sv_bless(obj_sv, meta->stash);
    /* Magic for lock/freeze is added lazily when first needed */

    ST(0) = sv_2mortal(obj_sv);
    XSRETURN(1);
}

/* XS fallback accessor */
static XS(xs_accessor_fallback) {
    dXSARGS;
    IV idx = CvXSUBANY(cv).any_iv;
    SV *self = ST(0);
    AV *av;

    if (!SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVAV) {
        croak("Not an object");
    }
    av = (AV*)SvRV(self);

    if (items > 1) {
        /* Setter */
        MAGIC *mg = get_object_magic(aTHX_ self);
        if (mg && (mg->mg_private & OBJ_FLAG_FROZEN)) {
            croak("Cannot modify frozen object");
        }
        av_store(av, idx, newSVsv(ST(1)));
        ST(0) = ST(1);
        XSRETURN(1);
    } else {
        /* Getter */
        SV **svp = av_fetch(av, idx, 0);
        if (svp && SvOK(*svp)) {
            ST(0) = *svp;
        } else {
            ST(0) = &PL_sv_undef;
        }
        XSRETURN(1);
    }
}

/* ============================================
   Install constructor into class
   ============================================ */

static void install_constructor(pTHX_ const char *class_name, ClassMeta *meta) {
    char full_name[256];
    CV *cv;

    snprintf(full_name, sizeof(full_name), "%s::new", class_name);
    
    /* Create a minimal CV that will be replaced by call checker */
    cv = newXS(full_name, xs_object_new_fallback, __FILE__);
    CvXSUBANY(cv).any_iv = PTR2IV(meta);
}

/* ============================================
   Custom OP: fast function-style getter
   op_targ = idx, reads object from stack
   ============================================ */
static XOP object_func_get_xop;
static XOP object_func_set_xop;

static OP* pp_object_func_get(pTHX) {
    dSP;
    SV *obj = TOPs;  /* peek, don't pop */
    IV idx = PL_op->op_targ;
    AV *av = (AV*)SvRV(obj);  /* Skip check - trust call checker */
    SV **svp = AvARRAY(av) + idx;  /* Direct array access */
    SETs((*svp && SvOK(*svp)) ? *svp : &PL_sv_undef);
    RETURN;
}

static OP* pp_object_func_set(pTHX) {
    dSP;
    SV *val = TOPs;  /* value on top */
    SV *obj = TOPm1s;  /* object below */
    IV idx = PL_op->op_targ;
    AV *av = (AV*)SvRV(obj);  /* Skip check - trust call checker */
    SV **slot = AvARRAY(av) + idx;
    SV *old = *slot;
    
    *slot = SvREFCNT_inc_simple_NN(val);  /* Inc refcount in place */
    if (old) SvREFCNT_dec(old);
    
    TOPm1s = val;  /* Replace object with value */
    SP--;          /* Pop top, leaving value */
    RETURN;
}

/* Call checker for function-style accessor: name($obj) or name($obj, $val) */
static OP* func_accessor_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    IV idx = SvIV(ckobj);
    OP *pushop, *cvop, *objop, *valop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    objop = OpSIBLING(pushop);
    cvop = objop;
    valop = NULL;
    
    while (OpHAS_SIBLING(cvop)) {
        valop = cvop;
        cvop = OpSIBLING(cvop);
    }

    if (valop && valop != objop) {
        /* Setter: name($obj, $val) */
        valop = OpSIBLING(objop);
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(valop, NULL);
        OpLASTSIB_set(objop, NULL);
        
        newop = newBINOP(OP_CUSTOM, 0, objop, valop);
        newop->op_ppaddr = pp_object_func_set;
        newop->op_targ = idx;
    } else {
        /* Getter: name($obj) */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(objop, NULL);
        
        newop = newUNOP(OP_CUSTOM, 0, objop);
        newop->op_ppaddr = pp_object_func_get;
        newop->op_targ = idx;
    }
    
    op_free(entersubop);
    return newop;
}

/* XS fallback for function-style accessor */
static XS(xs_func_accessor_fallback) {
    dXSARGS;
    IV idx = CvXSUBANY(cv).any_iv;
    SV *obj = ST(0);
    AV *av;

    if (!SvROK(obj) || SvTYPE(SvRV(obj)) != SVt_PVAV) {
        croak("Not an object");
    }
    av = (AV*)SvRV(obj);

    if (items > 1) {
        av_store(av, idx, newSVsv(ST(1)));
        ST(0) = ST(1);
    } else {
        SV **svp = av_fetch(av, idx, 0);
        ST(0) = (svp && SvOK(*svp)) ? *svp : &PL_sv_undef;
    }
    XSRETURN(1);
}

/* Install function-style accessor in caller's namespace */
static void install_func_accessor(pTHX_ const char *pkg, const char *prop_name, IV idx) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, prop_name);
    
    cv = newXS(full_name, xs_func_accessor_fallback, __FILE__);
    CvXSUBANY(cv).any_iv = idx;
    
    ckobj = newSViv(idx);
    cv_set_call_checker(cv, func_accessor_call_checker, ckobj);
}

/* object::import_accessors("Class", "targetpkg") - import fast accessors */
static XS(xs_import_accessors) {
    dXSARGS;
    STRLEN class_len, pkg_len;
    const char *class_pv, *pkg_pv;
    ClassMeta *meta;
    IV i;
    
    if (items < 1) croak("Usage: object::import_accessors($class [, $package])");
    
    class_pv = SvPV(ST(0), class_len);
    
    if (items > 1) {
        pkg_pv = SvPV(ST(1), pkg_len);
    } else {
        /* Default to caller's package */
        pkg_pv = CopSTASHPV(PL_curcop);
    }
    
    meta = get_class_meta(aTHX_ class_pv, class_len);
    if (!meta) {
        croak("Class '%s' not defined with object::define", class_pv);
    }
    
    /* Install function-style accessors for each property */
    for (i = 1; i < meta->slot_count; i++) {
        if (meta->idx_to_prop[i]) {
            install_func_accessor(aTHX_ pkg_pv, meta->idx_to_prop[i], i);
        }
    }
    
    XSRETURN_EMPTY;
}

/* object::import_accessor("Class", "prop", "alias") - import single accessor with alias */
static XS(xs_import_accessor) {
    dXSARGS;
    STRLEN class_len, prop_len, alias_len, pkg_len;
    const char *class_pv, *prop_pv, *alias_pv, *pkg_pv;
    ClassMeta *meta;
    SV **idx_svp;
    IV idx;
    
    if (items < 2) croak("Usage: object::import_accessor($class, $prop [, $alias [, $package]])");
    
    class_pv = SvPV(ST(0), class_len);
    prop_pv = SvPV(ST(1), prop_len);
    
    /* Alias defaults to property name */
    if (items > 2 && SvOK(ST(2))) {
        alias_pv = SvPV(ST(2), alias_len);
    } else {
        alias_pv = prop_pv;
    }
    
    /* Package defaults to caller */
    if (items > 3) {
        pkg_pv = SvPV(ST(3), pkg_len);
    } else {
        pkg_pv = CopSTASHPV(PL_curcop);
    }
    
    meta = get_class_meta(aTHX_ class_pv, class_len);
    if (!meta) {
        croak("Class '%s' not defined with object::define", class_pv);
    }
    
    /* Look up property index */
    idx_svp = hv_fetch(meta->prop_to_idx, prop_pv, prop_len, 0);
    if (!idx_svp) {
        croak("Property '%s' not defined in class '%s'", prop_pv, class_pv);
    }
    idx = SvIV(*idx_svp);
    
    /* Install with alias name */
    install_func_accessor(aTHX_ pkg_pv, alias_pv, idx);
    
    XSRETURN_EMPTY;
}

/* ============================================
   Install accessor into class
   ============================================ */

static void install_accessor(pTHX_ const char *class_name, const char *prop_name, IV idx) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    snprintf(full_name, sizeof(full_name), "%s::%s", class_name, prop_name);
    
    cv = newXS(full_name, xs_accessor_fallback, __FILE__);
    CvXSUBANY(cv).any_iv = idx;
    
    ckobj = newSViv(idx);
    cv_set_call_checker(cv, accessor_call_checker, ckobj);
}

/* XS fallback accessor with type checking */
static XS(xs_accessor_typed_fallback) {
    dXSARGS;
    SlotOpData *data = INT2PTR(SlotOpData*, CvXSUBANY(cv).any_iv);
    IV idx = data->slot_idx;
    ClassMeta *meta = data->meta;
    SlotSpec *spec = meta->slots[idx];
    SV *self = ST(0);
    AV *av;

    if (!SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVAV) {
        croak("Not an object");
    }
    av = (AV*)SvRV(self);

    if (items > 1) {
        /* Setter with type check */
        SV *val = ST(1);
        MAGIC *mg = get_object_magic(aTHX_ self);
        if (mg && (mg->mg_private & OBJ_FLAG_FROZEN)) {
            croak("Cannot modify frozen object");
        }
        
        if (spec->is_readonly) {
            croak("Cannot modify readonly slot '%s'", spec->name);
        }
        
        /* Type check */
        if (spec->has_type) {
            if (!check_slot_type(aTHX_ val, spec)) {
                const char *type_name = (spec->type_id == TYPE_CUSTOM && spec->registered)
                    ? spec->registered->name
                    : type_id_to_name(spec->type_id);
                croak("Type constraint failed for '%s': expected %s",
                      spec->name, type_name);
            }
        }
        
        av_store(av, idx, newSVsv(val));
        ST(0) = val;
        XSRETURN(1);
    } else {
        /* Getter */
        SV **svp = av_fetch(av, idx, 0);
        ST(0) = (svp && SvOK(*svp)) ? *svp : &PL_sv_undef;
        XSRETURN(1);
    }
}

/* Call checker for typed accessor */
static OP* accessor_typed_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    SlotOpData *data = INT2PTR(SlotOpData*, SvIV(ckobj));
    IV idx = data->slot_idx;
    OP *pushop, *cvop, *selfop, *argop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    selfop = OpSIBLING(pushop);
    cvop = selfop;
    argop = selfop;
    while (OpHAS_SIBLING(cvop)) {
        argop = cvop;
        cvop = OpSIBLING(cvop);
    }

    /* Check if there's an argument after self (setter call) */
    if (argop != selfop) {
        /* Setter: $obj->name($value) - use typed setter */
        OP *valop = OpSIBLING(selfop);
        
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(valop, NULL);
        OpLASTSIB_set(selfop, NULL);
        
        newop = newBINOP(OP_CUSTOM, 0, selfop, valop);
        newop->op_ppaddr = pp_object_set_typed;
        newop->op_targ = PTR2IV(data);
        
        op_free(entersubop);
        return newop;
    } else {
        /* Getter: $obj->name - plain getter (no type check needed) */
        OpMORESIB_set(pushop, cvop);
        OpLASTSIB_set(selfop, NULL);
        
        newop = newUNOP(OP_CUSTOM, 0, selfop);
        newop->op_ppaddr = pp_object_get;
        newop->op_targ = idx;
        
        op_free(entersubop);
        return newop;
    }
}

/* Install typed accessor (with type check, triggers, etc.) */
static void install_accessor_typed(pTHX_ const char *class_name, const char *prop_name, IV idx, ClassMeta *meta) {
    char full_name[256];
    CV *cv;
    SV *ckobj;
    SlotOpData *data;

    snprintf(full_name, sizeof(full_name), "%s::%s", class_name, prop_name);
    
    /* Allocate persistent data for this slot */
    Newx(data, 1, SlotOpData);
    data->slot_idx = idx;
    data->meta = meta;
    
    cv = newXS(full_name, xs_accessor_typed_fallback, __FILE__);
    CvXSUBANY(cv).any_iv = PTR2IV(data);
    
    ckobj = newSViv(PTR2IV(data));
    cv_set_call_checker(cv, accessor_typed_call_checker, ckobj);
}

/* ============================================
   XS API Functions
   ============================================ */

static XS(xs_define) {
    dXSARGS;
    STRLEN class_len;
    const char *class_pv;
    ClassMeta *meta;
    IV i;
    
    if (items < 1) croak("Usage: object::define($class, @properties)");
    
    class_pv = SvPV(ST(0), class_len);

    /* Get or create class meta */
    meta = get_class_meta(aTHX_ class_pv, class_len);
    if (!meta) {
        meta = create_class_meta(aTHX_ class_pv, class_len);
        register_class_meta(aTHX_ class_pv, class_len, meta);
    }

    /* Allocate property name array and slots array */
    Renew(meta->idx_to_prop, items, char*);
    Renew(meta->slots, items, SlotSpec*);
    for (i = 0; i < items; i++) {
        meta->slots[i] = NULL;
    }

    /* Register each property */
    for (i = 1; i < items; i++) {
        STRLEN spec_len;
        const char *spec_pv = SvPV(ST(i), spec_len);
        SlotSpec *spec;
        IV idx = meta->slot_count++;
        
        /* Parse the slot spec (e.g., "name:Str:required" or just "name") */
        spec = parse_slot_spec(aTHX_ spec_pv, spec_len);
        meta->slots[idx] = spec;
        
        /* Update class-level flags for fast path checks */
        if (spec->has_type) meta->has_any_types = 1;
        if (spec->has_default) meta->has_any_defaults = 1;
        if (spec->has_trigger) meta->has_any_triggers = 1;
        if (spec->is_required) meta->has_any_required = 1;

        /* Store name -> idx mapping (use parsed name, not full spec) */
        hv_store(meta->prop_to_idx, spec->name, strlen(spec->name), newSViv(idx), 0);

        /* Store idx -> name mapping */
        meta->idx_to_prop[idx] = spec->name;  /* Already allocated in parse_slot_spec */

        /* Install accessor method - typed or plain depending on spec */
        if (spec->has_type || spec->has_trigger || spec->has_coerce || spec->is_readonly) {
            install_accessor_typed(aTHX_ class_pv, spec->name, idx, meta);
        } else {
            install_accessor(aTHX_ class_pv, spec->name, idx);
        }
    }

    /* Install constructor */
    install_constructor(aTHX_ class_pv, meta);
    
    XSRETURN_EMPTY;
}

static XS(xs_prototype) {
    dXSARGS;
    AV *av;
    SV **svp;
    
    if (items < 1) croak("Usage: object::prototype($obj)");
    
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("Not an object");
    }
    av = (AV*)SvRV(ST(0));
    svp = av_fetch(av, 0, 0);
    if (svp && SvOK(*svp)) {
        ST(0) = SvREFCNT_inc(*svp);
    } else {
        ST(0) = &PL_sv_undef;
    }
    XSRETURN(1);
}

static XS(xs_set_prototype) {
    dXSARGS;
    AV *av;
    MAGIC *mg;
    
    if (items < 2) croak("Usage: object::set_prototype($obj, $proto)");
    
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("Not an object");
    }
    av = (AV*)SvRV(ST(0));

    mg = get_object_magic(aTHX_ ST(0));
    if (mg && (mg->mg_private & OBJ_FLAG_FROZEN)) {
        croak("Cannot modify frozen object");
    }

    av_store(av, 0, newSVsv(ST(1)));
    XSRETURN_EMPTY;
}

static XS(xs_lock) {
    dXSARGS;
    MAGIC *mg;
    
    if (items < 1) croak("Usage: object::lock($obj)");
    
    mg = get_object_magic(aTHX_ ST(0));
    if (!mg) mg = add_object_magic(aTHX_ ST(0));
    if (mg->mg_private & OBJ_FLAG_FROZEN) {
        croak("Object is frozen");
    }
    mg->mg_private |= OBJ_FLAG_LOCKED;
    XSRETURN_EMPTY;
}

static XS(xs_unlock) {
    dXSARGS;
    MAGIC *mg;
    
    if (items < 1) croak("Usage: object::unlock($obj)");
    
    mg = get_object_magic(aTHX_ ST(0));
    if (mg) {
        if (mg->mg_private & OBJ_FLAG_FROZEN) {
            croak("Cannot unlock frozen object");
        }
        mg->mg_private &= ~OBJ_FLAG_LOCKED;
    }
    XSRETURN_EMPTY;
}

static XS(xs_freeze) {
    dXSARGS;
    MAGIC *mg;
    
    if (items < 1) croak("Usage: object::freeze($obj)");
    
    mg = get_object_magic(aTHX_ ST(0));
    if (!mg) mg = add_object_magic(aTHX_ ST(0));
    mg->mg_private |= (OBJ_FLAG_FROZEN | OBJ_FLAG_LOCKED);
    XSRETURN_EMPTY;
}

static XS(xs_is_frozen) {
    dXSARGS;
    MAGIC *mg;
    
    if (items < 1) croak("Usage: object::is_frozen($obj)");
    
    mg = get_object_magic(aTHX_ ST(0));
    if (mg && (mg->mg_private & OBJ_FLAG_FROZEN)) {
        XSRETURN_YES;
    }
    XSRETURN_NO;
}

static XS(xs_is_locked) {
    dXSARGS;
    MAGIC *mg;
    
    if (items < 1) croak("Usage: object::is_locked($obj)");
    
    mg = get_object_magic(aTHX_ ST(0));
    if (mg && (mg->mg_private & OBJ_FLAG_LOCKED)) {
        XSRETURN_YES;
    }
    XSRETURN_NO;
}

/* ============================================
   Type Registry API
   ============================================ */

/* C-level registration for external XS modules (called from BOOT) 
   This is the fast path - no Perl callback overhead */
PERL_CALLCONV void object_register_type_xs(pTHX_ const char *name, 
                                           ObjectTypeCheckFunc check,
                                           ObjectTypeCoerceFunc coerce) {
    RegisteredType *type;
    STRLEN name_len = strlen(name);
    
    if (!g_type_registry) {
        g_type_registry = newHV();
    }
    
    /* Check if already registered */
    SV **existing = hv_fetch(g_type_registry, name, name_len, 0);
    if (existing) {
        croak("Type '%s' is already registered", name);
    }
    
    Newxz(type, 1, RegisteredType);
    Newx(type->name, name_len + 1, char);
    Copy(name, type->name, name_len, char);
    type->name[name_len] = '\0';
    
    type->check = check;    /* Direct C function pointer - no Perl overhead */
    type->coerce = coerce;  /* Direct C function pointer - no Perl overhead */
    type->perl_check = NULL;
    type->perl_coerce = NULL;
    
    hv_store(g_type_registry, name, name_len, newSViv(PTR2IV(type)), 0);
}

/* Getter for external modules to look up a registered type */
PERL_CALLCONV RegisteredType* object_get_registered_type(pTHX_ const char *name) {
    STRLEN name_len = strlen(name);
    if (!g_type_registry) return NULL;
    
    SV **svp = hv_fetch(g_type_registry, name, name_len, 0);
    if (svp && SvIOK(*svp)) {
        return INT2PTR(RegisteredType*, SvIV(*svp));
    }
    return NULL;
}

/* object::register_type($name, $check_cb [, $coerce_cb]) */
static XS(xs_register_type) {
    dXSARGS;
    STRLEN name_len;
    const char *name;
    RegisteredType *type;
    
    if (items < 2) croak("Usage: object::register_type($name, $check_cb [, $coerce_cb])");
    
    name = SvPV(ST(0), name_len);
    
    /* Check if already registered */
    if (g_type_registry) {
        SV **existing = hv_fetch(g_type_registry, name, name_len, 0);
        if (existing) {
            croak("Type '%s' is already registered", name);
        }
    } else {
        g_type_registry = newHV();
    }
    
    Newxz(type, 1, RegisteredType);
    Newx(type->name, name_len + 1, char);
    Copy(name, type->name, name_len, char);
    type->name[name_len] = '\0';
    
    /* Store Perl check callback */
    type->perl_check = newSVsv(ST(1));
    SvREFCNT_inc(type->perl_check);
    
    /* Store Perl coerce callback if provided */
    if (items > 2 && SvOK(ST(2))) {
        type->perl_coerce = newSVsv(ST(2));
        SvREFCNT_inc(type->perl_coerce);
    }
    
    hv_store(g_type_registry, name, name_len, newSViv(PTR2IV(type)), 0);
    
    XSRETURN_YES;
}

/* object::has_type($name) - check if a type is registered */
static XS(xs_has_type) {
    dXSARGS;
    STRLEN name_len;
    const char *name;
    
    if (items < 1) croak("Usage: object::has_type($name)");
    
    name = SvPV(ST(0), name_len);
    
    /* Check built-in types */
    BuiltinTypeID builtin = parse_builtin_type(name, name_len);
    if (builtin != TYPE_NONE) {
        XSRETURN_YES;
    }
    
    /* Check registry */
    if (g_type_registry) {
        SV **existing = hv_fetch(g_type_registry, name, name_len, 0);
        if (existing) {
            XSRETURN_YES;
        }
    }
    
    XSRETURN_NO;
}

/* object::list_types() - return list of registered type names */
static XS(xs_list_types) {
    dXSARGS;
    AV *result = newAV();
    
    PERL_UNUSED_ARG(items);
    
    /* Add built-in types */
    av_push(result, newSVpvs("Any"));
    av_push(result, newSVpvs("Defined"));
    av_push(result, newSVpvs("Str"));
    av_push(result, newSVpvs("Int"));
    av_push(result, newSVpvs("Num"));
    av_push(result, newSVpvs("Bool"));
    av_push(result, newSVpvs("ArrayRef"));
    av_push(result, newSVpvs("HashRef"));
    av_push(result, newSVpvs("CodeRef"));
    av_push(result, newSVpvs("Object"));
    
    /* Add registered types */
    if (g_type_registry) {
        HE *he;
        hv_iterinit(g_type_registry);
        while ((he = hv_iternext(g_type_registry))) {
            av_push(result, newSVsv(hv_iterkeysv(he)));
        }
    }
    
    ST(0) = newRV_noinc((SV*)result);
    sv_2mortal(ST(0));
    XSRETURN(1);
}

/* ============================================
   Boot
   ============================================ */

XS_EXTERNAL(boot_object) {
    dXSBOOTARGSXSAPIVERCHK;
    PERL_UNUSED_VAR(items);

    /* Register custom ops */
    XopENTRY_set(&object_new_xop, xop_name, "object_new");
    XopENTRY_set(&object_new_xop, xop_desc, "object constructor");
    Perl_custom_op_register(aTHX_ pp_object_new, &object_new_xop);
    
    XopENTRY_set(&object_get_xop, xop_name, "object_get");
    XopENTRY_set(&object_get_xop, xop_desc, "object property get");
    Perl_custom_op_register(aTHX_ pp_object_get, &object_get_xop);
    
    XopENTRY_set(&object_set_xop, xop_name, "object_set");
    XopENTRY_set(&object_set_xop, xop_desc, "object property set");
    Perl_custom_op_register(aTHX_ pp_object_set, &object_set_xop);

    XopENTRY_set(&object_set_typed_xop, xop_name, "object_set_typed");
    XopENTRY_set(&object_set_typed_xop, xop_desc, "object property set with type check");
    Perl_custom_op_register(aTHX_ pp_object_set_typed, &object_set_typed_xop);

    XopENTRY_set(&object_func_get_xop, xop_name, "object_func_get");
    XopENTRY_set(&object_func_get_xop, xop_desc, "object function-style get");
    Perl_custom_op_register(aTHX_ pp_object_func_get, &object_func_get_xop);
    
    XopENTRY_set(&object_func_set_xop, xop_name, "object_func_set");
    XopENTRY_set(&object_func_set_xop, xop_desc, "object function-style set");
    Perl_custom_op_register(aTHX_ pp_object_func_set, &object_func_set_xop);

    /* Initialize registries */
    g_class_registry = newHV();
    g_type_registry = newHV();

    /* Install XS functions */
    newXS("object::define", xs_define, __FILE__);
    newXS("object::import_accessors", xs_import_accessors, __FILE__);
    newXS("object::import_accessor", xs_import_accessor, __FILE__);
    newXS("object::prototype", xs_prototype, __FILE__);
    newXS("object::set_prototype", xs_set_prototype, __FILE__);
    newXS("object::lock", xs_lock, __FILE__);
    newXS("object::unlock", xs_unlock, __FILE__);
    newXS("object::freeze", xs_freeze, __FILE__);
    newXS("object::is_frozen", xs_is_frozen, __FILE__);
    newXS("object::is_locked", xs_is_locked, __FILE__);
    
    /* Type registry API */
    newXS("object::register_type", xs_register_type, __FILE__);
    newXS("object::has_type", xs_has_type, __FILE__);
    newXS("object::list_types", xs_list_types, __FILE__);

    Perl_xs_boot_epilog(aTHX_ ax);
}

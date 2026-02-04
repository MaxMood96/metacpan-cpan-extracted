#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <math.h>
#include <string.h>

/*
 * Stefo - Optree walker and bytecode compiler
 *
 * Walks Perl optrees to extract simple patterns, compiles them to
 * a bytecode IR that can be executed in pure C without call_sv overhead.
 *
 * Supported on Perl 5.10+
 */

/* ═══════════════════════════════════════════════════════════════════════════
   Version and Compatibility
   ═══════════════════════════════════════════════════════════════════════════ */

#ifndef PERL_VERSION_GE
#  define PERL_VERSION_GE(r,v,s) \
      (PERL_REVISION > (r) || (PERL_REVISION == (r) && \
       (PERL_VERSION > (v) || (PERL_VERSION == (v) && PERL_SUBVERSION >= (s)))))
#endif

/* C23/C99/C89 bool compatibility */
#if __STDC_VERSION__ >= 202311L
   /* C23: bool, true, false are keywords */
#elif defined(__bool_true_false_are_defined)
   /* stdbool.h included */
#else
   #ifndef bool
       typedef int bool;
   #endif
   #ifndef true
       #define true 1
   #endif
   #ifndef false
       #define false 0
   #endif
#endif

/* OpSIBLING compatibility (5.22+) */
#ifndef OpSIBLING
#  define OpSIBLING(o) ((o)->op_sibling)
#endif

/* cGVOPo_gv compatibility */
#ifndef cGVOPo_gv
#  ifdef USE_ITHREADS
#    define cGVOPo_gv ((GV*)PAD_SVl(cGVOPo->op_padix))
#  else
#    define cGVOPo_gv (cGVOPo->op_gv)
#  endif
#endif

/* PM_GETRE compatibility */
#ifndef PM_GETRE
#  define PM_GETRE(o) ((o)->op_pmregexp)
#endif

/* ReREFCNT compatibility */
#ifndef ReREFCNT_inc
#  define ReREFCNT_inc(re) ((void)(re && SvREFCNT_inc((SV*)(re))), (re))
#endif
#ifndef ReREFCNT_dec
#  define ReREFCNT_dec(re) SvREFCNT_dec((SV*)(re))
#endif

/* DEFSV compatibility */
#ifndef DEFSV
#  define DEFSV GvSV(PL_defgv)
#endif

/* OP_FC compatibility (5.16+) - OP_FC is an enum, not a macro, so we use version check */
#if !PERL_VERSION_GE(5,16,0)
#  define STEFO_OP_FC 0xFFFF
#else
#  define STEFO_OP_FC OP_FC
#endif

/* OP_AELEMFAST_LEX compatibility (5.16+) */
#ifndef OP_AELEMFAST_LEX
#  define OP_AELEMFAST_LEX OP_AELEMFAST
#endif

/* SVt_REGEXP compatibility (5.12+) */
#if !PERL_VERSION_GE(5,12,0)
#  define SVt_REGEXP SVt_PVMG

#endif

/* ═══════════════════════════════════════════════════════════════════════════
   Bytecode IR - Simple stack-based VM
   ═══════════════════════════════════════════════════════════════════════════ */

/* Opcode types - prefixed to avoid collision with Perl's OP_* */
typedef enum {
    /* Stack operations */
    COPS_PUSH_VAL,       /* Push the input value */
    COPS_PUSH_IV,        /* Push integer constant */
    COPS_PUSH_NV,        /* Push float constant */
    COPS_PUSH_PV,        /* Push string constant */
    
    /* Comparisons (pop 2, push bool) */
    COPS_GT,             /* > */
    COPS_GE,             /* >= */
    COPS_LT,             /* < */
    COPS_LE,             /* <= */
    COPS_EQ_NUM,         /* == */
    COPS_NE_NUM,         /* != */
    COPS_EQ_STR,         /* eq */
    COPS_NE_STR,         /* ne */
    COPS_CMP_NUM,        /* <=> */
    COPS_CMP_STR,        /* cmp */
    
    /* Unary (pop 1, push result) */
    COPS_DEFINED,        /* defined */
    COPS_NOT,            /* ! */
    COPS_LENGTH,         /* length() */
    COPS_IS_REF,         /* ref() as bool */
    COPS_IS_ARRAY,       /* ref eq 'ARRAY' */
    COPS_IS_HASH,        /* ref eq 'HASH' */
    COPS_IS_CODE,        /* ref eq 'CODE' */
    COPS_IS_SCALAR,      /* ref eq 'SCALAR' */
    COPS_IS_REGEXP,      /* ref eq 'Regexp' */
    COPS_IS_GLOB,        /* ref eq 'GLOB' */
    COPS_IS_BLESSED,     /* blessed() - any object */
    COPS_LOOKS_LIKE_NUM, /* Scalar::Util::looks_like_number */
    COPS_IS_INT,         /* int($_) == $_ */
    COPS_IS_POSITIVE,    /* $_ > 0 */
    COPS_IS_NEGATIVE,    /* $_ < 0 */
    COPS_IS_ZERO,        /* $_ == 0 */
    COPS_IS_TRUE,        /* truthy (just $_) */
    COPS_IS_FALSE,       /* falsy (!$_) */
    COPS_IS_EMPTY_STR,   /* $_ eq '' */
    COPS_IS_NONEMPTY_STR,/* $_ ne '' */
    COPS_ABS,            /* abs() */
    COPS_INT,            /* int() */
    COPS_UC,             /* uc() */
    COPS_LC,             /* lc() */
    COPS_UCFIRST,        /* ucfirst() */
    COPS_LCFIRST,        /* lcfirst() */
    COPS_CHOMP,          /* chomp - for string ending with \n */
    
    /* Binary operations (pop 2, push result) */
    COPS_ADD,            /* + */
    COPS_SUB,            /* - */
    COPS_MUL,            /* * */
    COPS_DIV,            /* / */
    COPS_MOD,            /* % */
    COPS_POW,            /* ** */
    COPS_CONCAT,         /* . */
    COPS_INDEX,          /* index() - returns position */
    COPS_RINDEX,         /* rindex() - returns position */
    COPS_SUBSTR,         /* substr() */
    COPS_REPEAT,         /* x */
    
    /* Array/Hash operations (for references) */
    COPS_ARRAY_LEN,      /* scalar(@{$_}) */
    COPS_HASH_SIZE,      /* scalar(keys %{$_}) */
    COPS_ARRAY_EMPTY,    /* !@{$_} */
    COPS_HASH_EMPTY,     /* !%{$_} */
    COPS_EXISTS,         /* exists in hash/array */
    COPS_ARRAY_ELEM,     /* $_->[N] */
    COPS_HASH_ELEM,      /* $_->{key} */
    
    /* String tests (character classes) */
    COPS_IS_ALPHA,       /* /^[a-zA-Z]+$/ */
    COPS_IS_ALNUM,       /* /^[a-zA-Z0-9]+$/ */
    COPS_IS_DIGIT,       /* /^\d+$/ */
    COPS_IS_SPACE,       /* /^\s+$/ */
    COPS_IS_WORD,        /* /^\w+$/ */
    COPS_IS_UPPER,       /* /^[A-Z]+$/ */
    COPS_IS_LOWER,       /* /^[a-z]+$/ */
    COPS_IS_ASCII,       /* all ASCII chars */
    COPS_IS_PRINTABLE,   /* all printable */
    COPS_STARTS_WITH,    /* index == 0 */
    COPS_ENDS_WITH,      /* substr(-len) eq str */
    COPS_CONTAINS,       /* index >= 0 */
    
    /* Numeric range checks */
    COPS_IN_RANGE,       /* N <= $_ <= M */
    COPS_IN_RANGE_EX,    /* N < $_ < M (exclusive) */
    COPS_DIVISIBLE_BY,   /* $_ % N == 0 */
    COPS_IS_EVEN,        /* $_ % 2 == 0 */
    COPS_IS_ODD,         /* $_ % 2 != 0 */
    
    /* Regex (uses stored rx) */
    COPS_MATCH,          /* =~ /regex/ */
    COPS_NOT_MATCH,      /* !~ /regex/ */
    
    /* Logic (short-circuit) */
    COPS_AND,            /* && - jump if false */
    COPS_OR,             /* || - jump if true */
    COPS_DOR,            /* // - defined-or */
    COPS_TERNARY,        /* ?: conditional */
    
    /* Control */
    COPS_RETURN,         /* return top of stack */
    COPS_DUP,            /* duplicate top of stack */
    COPS_POP,            /* discard top of stack */
    COPS_SWAP,           /* swap top two stack elements */
    
    /* Additional opcodes for new patterns */
    COPS_NEGATE,         /* unary minus -$_ */
    COPS_STRINGIFY,      /* "" . $_ */
    COPS_INDEX_POS,      /* index with position arg */
    COPS_RINDEX_POS,     /* rindex with position arg */
    COPS_SUBSTR3,        /* substr with 3 args */
    COPS_ARRAY_ELEM_DYN, /* dynamic array access */
    COPS_HASH_ELEM_DYN,  /* dynamic hash access */
    COPS_RV2AV,          /* @{$_} */
    COPS_RV2HV,          /* %{$_} */
    COPS_KEYS,           /* keys %hash */
    COPS_VALUES,         /* values %hash */
    COPS_EACH,           /* each %hash */
    COPS_DELETE,         /* delete */
    COPS_SLT,            /* lt */
    COPS_SGT,            /* gt */
    COPS_SLE,            /* le */
    COPS_SGE,            /* ge */
    COPS_SCMP,           /* cmp */
    COPS_NCMP,           /* <=> */
    COPS_BIT_AND,        /* & */
    COPS_BIT_OR,         /* | */
    COPS_BIT_XOR,        /* ^ */
    COPS_BIT_NOT,        /* ~ */
    COPS_LEFT_SHIFT,     /* << */
    COPS_RIGHT_SHIFT,    /* >> */
    COPS_JUMP,           /* unconditional jump */
    COPS_JUMP_UNLESS,    /* jump if false */
    COPS_REVERSE,        /* reverse */
    COPS_SORT,           /* sort */
    COPS_LIST_SLICE,     /* list slice */
    COPS_ARRAY_SLICE,    /* array slice */
    COPS_HASH_SLICE,     /* hash slice */
    COPS_SPRINTF,        /* sprintf */
    COPS_JOIN,           /* join */
    COPS_SPLIT,          /* split */
    COPS_SPLIT3,         /* split with limit */
    COPS_ORD,            /* ord */
    COPS_CHR,            /* chr */
    COPS_HEX,            /* hex */
    COPS_OCT,            /* oct */
    COPS_SQRT,           /* sqrt */
    COPS_SIN,            /* sin */
    COPS_COS,            /* cos */
    COPS_EXP,            /* exp */
    COPS_LOG,            /* log */
    COPS_ATAN2,          /* atan2 */
    COPS_RAND,           /* rand */
    COPS_SRAND,          /* srand */
    COPS_QUOTEMETA,      /* quotemeta */
    COPS_WANTARRAY,      /* wantarray */
    COPS_CALLER,         /* caller */
    COPS_SCALAR,         /* scalar */
    COPS_PROTOTYPE,      /* prototype */
    COPS_BLESS,          /* bless */
    COPS_PUSH_UNDEF,     /* push undef */
    COPS_PUSH_CALLER_PKG,/* push caller's package */
    COPS_INDEX_BOOL,     /* index() with BOOL flag - true if found */
    COPS_INDEX_BOOL_NEG, /* index() with BOOL flag - true if NOT found */
    COPS_INDEX_POS_BOOL, /* index() with pos and BOOL flag - true if found */
    COPS_INDEX_POS_BOOL_NEG, /* index() with pos and BOOL flag - true if NOT found */
    COPS_RINDEX_BOOL,    /* rindex() with BOOL flag - true if found */
    COPS_RINDEX_BOOL_NEG,/* rindex() with BOOL flag - true if NOT found */
    COPS_RINDEX_POS_BOOL,/* rindex() with pos and BOOL flag - true if found */
    COPS_RINDEX_POS_BOOL_NEG, /* rindex() with pos and BOOL flag - true if NOT found */
    COPS_FC,             /* fc() - Unicode fold case */
    COPS_CHOP,           /* chop() - remove last character */
    COPS_POS,            /* pos() - position in last m//g match */
} CopsOpcode;

/* Single bytecode instruction */
typedef struct {
    CopsOpcode opcode;
    union {
        IV iv;
        NV nv;
        struct {
            char *pv;
            STRLEN len;
        } str;
        REGEXP *rx;
        int jump_offset;
    } arg;
} CopsInstruction;

/* Compiled bytecode program */
typedef struct {
    CopsInstruction *code;
    int len;
    int capacity;
    SV *original_cv;
    bool optimized;
} CopsProgram;

/* ═══════════════════════════════════════════════════════════════════════════
   Compiler State
   ═══════════════════════════════════════════════════════════════════════════ */

typedef struct {
    CopsProgram *prog;
    CV *cv;           /* CV being compiled, for pad access */
    bool failed;
    const char *fail_reason;
} CopsCompiler;

/* Emit instructions */
static void
cops_emit(CopsCompiler *c, CopsOpcode op) {
    CopsProgram *p = c->prog;
    if (p->len >= p->capacity) {
        p->capacity = p->capacity ? p->capacity * 2 : 16;
        Renew(p->code, p->capacity, CopsInstruction);
    }
    p->code[p->len].opcode = op;
    p->len++;
}

static void
cops_emit_iv(CopsCompiler *c, CopsOpcode op, IV val) {
    cops_emit(c, op);
    c->prog->code[c->prog->len - 1].arg.iv = val;
}

static void
cops_emit_nv(CopsCompiler *c, CopsOpcode op, NV val) {
    cops_emit(c, op);
    c->prog->code[c->prog->len - 1].arg.nv = val;
}

static void
cops_emit_pv(CopsCompiler *c, CopsOpcode op, const char *pv, STRLEN len) {
    char *copy;
    cops_emit(c, op);
    Newx(copy, len + 1, char);
    Copy(pv, copy, len, char);
    copy[len] = '\0';
    c->prog->code[c->prog->len - 1].arg.str.pv = copy;
    c->prog->code[c->prog->len - 1].arg.str.len = len;
}

static void
cops_emit_rx(CopsCompiler *c, CopsOpcode op, REGEXP *rx) {
    cops_emit(c, op);
    c->prog->code[c->prog->len - 1].arg.rx = rx;
    ReREFCNT_inc(rx);
}

static void
cops_fail(CopsCompiler *c, const char *reason) {
    c->failed = true;
    c->fail_reason = reason;
}

/* Check if op is $_ (gvsv for *_) 
 * For threaded Perl, we need to access the CV's pad, not the current pad */
static bool
cops_is_gv_underscore(pTHX_ OP *o, CV *cv) {
    GV *gv = NULL;
    if (!o || o->op_type != OP_GVSV) {
        return false;
    }
    
#ifdef USE_ITHREADS
    /* Threaded Perl: GV is in the CV's pad at op_padix */
    {
        PADLIST *padlist = CvPADLIST(cv);
        if (padlist && ((PADOP*)o)->op_padix) {
            PAD *pad = PadlistARRAY(padlist)[1];  /* Runtime pad */
            if (pad) {
                gv = (GV*)PadARRAY(pad)[((PADOP*)o)->op_padix];
            }
        }
    }
#else
    gv = cGVOPo_gv;
#endif
    
    if (!gv) return false;
    return (GvNAMELEN(gv) == 1 && *GvNAME(gv) == '_');
}

/* Forward declaration */
static void cops_compile_op(pTHX_ CopsCompiler *c, OP *o);

/* Compile a single op */
static void
cops_compile_op(pTHX_ CopsCompiler *c, OP *o) {
    if (c->failed || !o) return;
    
    switch (o->op_type) {
        case OP_NULL:
        case OP_LEAVESUB:
        case OP_LEAVE:
        case OP_SCOPE:
        case OP_LINESEQ:
            /* Walk children */
            if (o->op_flags & OPf_KIDS) {
                OP *kid = cUNOPo->op_first;
                while (kid) {
                    cops_compile_op(aTHX_ c, kid);
                    kid = OpSIBLING(kid);
                }
            }
            break;
            
        case OP_NEXTSTATE:
        case OP_DBSTATE:
            break;
            
        case OP_GVSV:
            if (!cops_is_gv_underscore(aTHX_ o, c->cv)) {
                cops_fail(c, "variable other than $_");
                return;
            }
            cops_emit(c, COPS_PUSH_VAL);
            break;
            
        case OP_CONST: {
            SV *sv = NULL;
            
            /* For threaded Perl, constants are stored in the pad */
#ifdef USE_ITHREADS
            if (o->op_targ) {
                /* Get SV from CV's pad */
                PADLIST *padlist = CvPADLIST(c->cv);
                if (padlist) {
                    PAD *pad = PadlistARRAY(padlist)[1];  /* Runtime pad */
                    if (pad && o->op_targ <= PadMAX(pad)) {
                        sv = PadARRAY(pad)[o->op_targ];
                    }
                }
            } else {
                sv = cSVOPx(o)->op_sv;
            }
#else
            sv = cSVOPo_sv;
#endif
            
            /* Handle special SVs (PL_sv_no, PL_sv_yes, etc.) and pad constants */
            if (!sv || sv == &PL_sv_undef) {
                cops_emit_iv(c, COPS_PUSH_IV, 0);
            } else if (sv == &PL_sv_no) {
                cops_emit_iv(c, COPS_PUSH_IV, 0);
            } else if (sv == &PL_sv_yes) {
                cops_emit_iv(c, COPS_PUSH_IV, 1);
            } else if (SvIOK(sv)) {
                cops_emit_iv(c, COPS_PUSH_IV, SvIV(sv));
            } else if (SvNOK(sv)) {
                cops_emit_nv(c, COPS_PUSH_NV, SvNV(sv));
            } else if (SvPOK(sv)) {
                STRLEN len;
                const char *pv = SvPV(sv, len);
                cops_emit_pv(c, COPS_PUSH_PV, pv, len);
            } else {
                /* Try to get a numeric value anyway */
                cops_emit_nv(c, COPS_PUSH_NV, SvNV(sv));
            }
            break;
        }
        
        case OP_GT:
        case OP_LT:
        case OP_GE:
        case OP_LE:
        case OP_EQ:
        case OP_NE:
        case OP_SEQ:
        case OP_SNE: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            
            /* Special case: ref($_) eq 'TYPE' - optimize to IS_ARRAY/IS_HASH/IS_CODE etc */
            if ((o->op_type == OP_SEQ || o->op_type == OP_SNE) && 
                left->op_type == OP_REF && right->op_type == OP_CONST) {
                OP *ref_arg = cUNOPx(left)->op_first;
                SV *type_sv = NULL;
                
                /* Get the type string from const */
#ifdef USE_ITHREADS
                if (right->op_targ) {
                    PADLIST *padlist = CvPADLIST(c->cv);
                    if (padlist) {
                        PAD *pad = PadlistARRAY(padlist)[1];
                        if (pad && right->op_targ <= PadMAX(pad)) {
                            type_sv = PadARRAY(pad)[right->op_targ];
                        }
                    }
                } else {
                    type_sv = cSVOPx(right)->op_sv;
                }
#else
                type_sv = cSVOPx_sv(right);
#endif
                
                if (type_sv && SvPOK(type_sv)) {
                    STRLEN len;
                    const char *type = SvPV(type_sv, len);
                    CopsOpcode emit_op = 0;
                    
                    if (len == 5 && strEQ(type, "ARRAY")) {
                        emit_op = (o->op_type == OP_SEQ) ? COPS_IS_ARRAY : COPS_NOT;
                        cops_compile_op(aTHX_ c, ref_arg);
                        cops_emit(c, COPS_IS_ARRAY);
                        if (o->op_type == OP_SNE) cops_emit(c, COPS_NOT);
                        break;
                    } else if (len == 4 && strEQ(type, "HASH")) {
                        cops_compile_op(aTHX_ c, ref_arg);
                        cops_emit(c, COPS_IS_HASH);
                        if (o->op_type == OP_SNE) cops_emit(c, COPS_NOT);
                        break;
                    } else if (len == 4 && strEQ(type, "CODE")) {
                        cops_compile_op(aTHX_ c, ref_arg);
                        cops_emit(c, COPS_IS_CODE);
                        if (o->op_type == OP_SNE) cops_emit(c, COPS_NOT);
                        break;
                    } else if (len == 6 && strEQ(type, "SCALAR")) {
                        cops_compile_op(aTHX_ c, ref_arg);
                        cops_emit(c, COPS_IS_SCALAR);
                        if (o->op_type == OP_SNE) cops_emit(c, COPS_NOT);
                        break;
                    } else if (len == 6 && strEQ(type, "Regexp")) {
                        cops_compile_op(aTHX_ c, ref_arg);
                        cops_emit(c, COPS_IS_REGEXP);
                        if (o->op_type == OP_SNE) cops_emit(c, COPS_NOT);
                        break;
                    } else if (len == 4 && strEQ(type, "GLOB")) {
                        cops_compile_op(aTHX_ c, ref_arg);
                        cops_emit(c, COPS_IS_GLOB);
                        if (o->op_type == OP_SNE) cops_emit(c, COPS_NOT);
                        break;
                    }
                }
            }
            
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            
            switch (o->op_type) {
                case OP_GT:  cops_emit(c, COPS_GT); break;
                case OP_LT:  cops_emit(c, COPS_LT); break;
                case OP_GE:  cops_emit(c, COPS_GE); break;
                case OP_LE:  cops_emit(c, COPS_LE); break;
                case OP_EQ:  cops_emit(c, COPS_EQ_NUM); break;
                case OP_NE:  cops_emit(c, COPS_NE_NUM); break;
                case OP_SEQ: cops_emit(c, COPS_EQ_STR); break;
                case OP_SNE: cops_emit(c, COPS_NE_STR); break;
                default: break;
            }
            break;
        }
        
        case OP_DEFINED: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_DEFINED);
            break;
        }
        
        case OP_NOT: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_NOT);
            break;
        }
        
        case OP_LENGTH: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_LENGTH);
            break;
        }
        
        case OP_REF: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_IS_REF);
            break;
        }
        
        case OP_ABS: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_ABS);
            break;
        }
        
        case OP_INT: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_INT);
            break;
        }
        
        case OP_ADD: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_ADD);
            break;
        }
        
        case OP_SUBTRACT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_SUB);
            break;
        }
        
        case OP_MULTIPLY: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_MUL);
            break;
        }
        
        case OP_DIVIDE: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_DIV);
            break;
        }
        
        case OP_MODULO: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_MOD);
            break;
        }
        
        case OP_POW: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_POW);
            break;
        }
        
        case OP_NEGATE: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_NEGATE);
            break;
        }
        
        case OP_UC: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_UC);
            break;
        }
        
        case OP_LC: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_LC);
            break;
        }
        
        case OP_UCFIRST: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_UCFIRST);
            break;
        }
        
        case OP_LCFIRST: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_LCFIRST);
            break;
        }

        /* OP_FC only exists on Perl 5.16+; on older Perls STEFO_OP_FC is 0xFFFF and never matches */
        case STEFO_OP_FC: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_FC);
            break;
        }

        case OP_CHOP:
        case OP_SCHOP: {
            /* chop() or scalar chop - return last character */
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_CHOP);
            break;
        }

        case OP_CHOMP:
        case OP_SCHOMP: {
            /* chomp() or scalar chomp - return count of removed chars */
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_CHOMP);
            break;
        }

        case OP_POS: {
            /* pos($_) - get position from last m//g match */
            OP *kid = cUNOPo->op_first;
            if (kid) {
                cops_compile_op(aTHX_ c, kid);
            } else {
                cops_emit(c, COPS_PUSH_VAL);
            }
            cops_emit(c, COPS_POS);
            break;
        }

        case OP_CONCAT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_CONCAT);
            break;
        }
        
        case OP_REPEAT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_REPEAT);
            break;
        }
        
        case OP_STRINGIFY: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_STRINGIFY);
            break;
        }
        
        case OP_INDEX: {
            /* index($str, $substr) or index($str, $substr, $pos) */
            OP *str_op = cLISTOPo->op_first;
            /* Skip OP_PUSHMARK or OP_NULL that was OP_PUSHMARK (ex-pushmark) */
            if (str_op && (str_op->op_type == OP_PUSHMARK ||
                (str_op->op_type == OP_NULL && str_op->op_targ == OP_PUSHMARK)))
                str_op = OpSIBLING(str_op);
            OP *substr_op = str_op ? OpSIBLING(str_op) : NULL;
            OP *pos_op = substr_op ? OpSIBLING(substr_op) : NULL;

            /* Check for Perl's BOOL optimization (index() >= 0 or index() < 0) */
            int is_bool = o->op_private & 0x20;  /* OPpTRUEBOOL */
            int is_neg = o->op_private & 0x40;   /* OPpINDEX_BOOLNEG */

            cops_compile_op(aTHX_ c, str_op);
            cops_compile_op(aTHX_ c, substr_op);
            if (pos_op) {
                cops_compile_op(aTHX_ c, pos_op);
                if (is_bool) {
                    cops_emit(c, is_neg ? COPS_INDEX_POS_BOOL_NEG : COPS_INDEX_POS_BOOL);
                } else {
                    cops_emit(c, COPS_INDEX_POS);
                }
            } else {
                if (is_bool) {
                    cops_emit(c, is_neg ? COPS_INDEX_BOOL_NEG : COPS_INDEX_BOOL);
                } else {
                    cops_emit(c, COPS_INDEX);
                }
            }
            break;
        }
        
        case OP_RINDEX: {
            OP *str_op = cLISTOPo->op_first;
            /* Skip OP_PUSHMARK or OP_NULL that was OP_PUSHMARK (ex-pushmark) */
            if (str_op && (str_op->op_type == OP_PUSHMARK ||
                (str_op->op_type == OP_NULL && str_op->op_targ == OP_PUSHMARK)))
                str_op = OpSIBLING(str_op);
            OP *substr_op = str_op ? OpSIBLING(str_op) : NULL;
            OP *pos_op = substr_op ? OpSIBLING(substr_op) : NULL;

            /* Check for Perl's BOOL optimization (rindex() >= 0 or rindex() < 0) */
            int is_bool = o->op_private & 0x20;  /* OPpTRUEBOOL */
            int is_neg = o->op_private & 0x40;   /* OPpINDEX_BOOLNEG */

            cops_compile_op(aTHX_ c, str_op);
            cops_compile_op(aTHX_ c, substr_op);
            if (pos_op) {
                cops_compile_op(aTHX_ c, pos_op);
                if (is_bool) {
                    cops_emit(c, is_neg ? COPS_RINDEX_POS_BOOL_NEG : COPS_RINDEX_POS_BOOL);
                } else {
                    cops_emit(c, COPS_RINDEX_POS);
                }
            } else {
                if (is_bool) {
                    cops_emit(c, is_neg ? COPS_RINDEX_BOOL_NEG : COPS_RINDEX_BOOL);
                } else {
                    cops_emit(c, COPS_RINDEX);
                }
            }
            break;
        }
        
        case OP_SUBSTR: {
            OP *str_op = cLISTOPo->op_first;
            /* Skip OP_PUSHMARK or OP_NULL that was OP_PUSHMARK (ex-pushmark) */
            if (str_op && (str_op->op_type == OP_PUSHMARK ||
                (str_op->op_type == OP_NULL && str_op->op_targ == OP_PUSHMARK)))
                str_op = OpSIBLING(str_op);
            OP *pos_op = str_op ? OpSIBLING(str_op) : NULL;
            OP *len_op = pos_op ? OpSIBLING(pos_op) : NULL;
            
            cops_compile_op(aTHX_ c, str_op);
            cops_compile_op(aTHX_ c, pos_op);
            if (len_op) {
                cops_compile_op(aTHX_ c, len_op);
                cops_emit(c, COPS_SUBSTR3);
            } else {
                cops_emit(c, COPS_SUBSTR);
            }
            break;
        }
        
        case OP_AELEMFAST:
        #if OP_AELEMFAST_LEX != OP_AELEMFAST
        case OP_AELEMFAST_LEX:
#endif
        {
            /* Fast array access $_->[N] where N is small constant */
            cops_emit(c, COPS_PUSH_VAL);
            cops_emit_iv(c, COPS_ARRAY_ELEM, o->op_private);
            break;
        }
        
        case OP_AELEM: {
            OP *av_op = cBINOPo->op_first;
            OP *idx_op = OpSIBLING(av_op);
            cops_compile_op(aTHX_ c, av_op);
            cops_compile_op(aTHX_ c, idx_op);
            cops_emit(c, COPS_ARRAY_ELEM_DYN);
            break;
        }
        
        case OP_HELEM: {
            OP *hv_op = cBINOPo->op_first;
            OP *key_op = OpSIBLING(hv_op);
            cops_compile_op(aTHX_ c, hv_op);
            cops_compile_op(aTHX_ c, key_op);
            cops_emit(c, COPS_HASH_ELEM_DYN);
            break;
        }
        
        case OP_RV2AV: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_RV2AV);
            break;
        }
        
        case OP_RV2HV: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_RV2HV);
            break;
        }
        
        case OP_KEYS: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_KEYS);
            break;
        }
        
        case OP_VALUES: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_VALUES);
            break;
        }
        
        case OP_EACH: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_EACH);
            break;
        }
        
        case OP_EXISTS: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_EXISTS);
            break;
        }
        
        case OP_DELETE: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_DELETE);
            break;
        }
        
        case OP_SLT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_SLT);
            break;
        }
        
        case OP_SGT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_SGT);
            break;
        }
        
        case OP_SLE: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_SLE);
            break;
        }
        
        case OP_SGE: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_SGE);
            break;
        }
        
        case OP_SCMP: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_SCMP);
            break;
        }
        
        case OP_NCMP: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_NCMP);
            break;
        }
        
        case OP_BIT_AND: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_BIT_AND);
            break;
        }
        
        case OP_BIT_OR: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_BIT_OR);
            break;
        }
        
        case OP_BIT_XOR: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_BIT_XOR);
            break;
        }
        
        case OP_COMPLEMENT: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_BIT_NOT);
            break;
        }
        
        case OP_LEFT_SHIFT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_LEFT_SHIFT);
            break;
        }
        
        case OP_RIGHT_SHIFT: {
            OP *left = cBINOPo->op_first;
            OP *right = OpSIBLING(left);
            cops_compile_op(aTHX_ c, left);
            cops_compile_op(aTHX_ c, right);
            cops_emit(c, COPS_RIGHT_SHIFT);
            break;
        }
        
        case OP_COND_EXPR: {
            /* Ternary: $cond ? $true : $false */
            OP *cond = cLOGOPo->op_first;
            OP *true_op = OpSIBLING(cond);
            OP *false_op = OpSIBLING(true_op);
            
            cops_compile_op(aTHX_ c, cond);
            int jump_false = c->prog->len;
            cops_emit(c, COPS_JUMP_UNLESS);
            cops_compile_op(aTHX_ c, true_op);
            int jump_end = c->prog->len;
            cops_emit(c, COPS_JUMP);
            c->prog->code[jump_false].arg.jump_offset = c->prog->len - jump_false;
            cops_compile_op(aTHX_ c, false_op);
            c->prog->code[jump_end].arg.jump_offset = c->prog->len - jump_end;
            break;
        }
        
        case OP_REVERSE: {
            OP *kid = cUNOPo->op_first;
            if (kid->op_type == OP_PUSHMARK) kid = OpSIBLING(kid);
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_REVERSE);
            break;
        }
        
        case OP_SORT: {
            /* Basic sort without custom comparator */
            OP *kid = cLISTOPo->op_first;
            if (kid->op_type == OP_PUSHMARK) kid = OpSIBLING(kid);
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_SORT);
            break;
        }
        
        case OP_LSLICE: {
            /* List slice */
            OP *list_op = cLISTOPo->op_first;
            OP *subscript = OpSIBLING(list_op);
            cops_compile_op(aTHX_ c, list_op);
            cops_compile_op(aTHX_ c, subscript);
            cops_emit(c, COPS_LIST_SLICE);
            break;
        }
        
        case OP_ASLICE: {
            /* Array slice */
            OP *av_op = cLISTOPo->op_first;
            OP *subscript = OpSIBLING(av_op);
            cops_compile_op(aTHX_ c, av_op);
            cops_compile_op(aTHX_ c, subscript);
            cops_emit(c, COPS_ARRAY_SLICE);
            break;
        }
        
        case OP_HSLICE: {
            /* Hash slice */
            OP *hv_op = cLISTOPo->op_first;
            OP *subscript = OpSIBLING(hv_op);
            cops_compile_op(aTHX_ c, hv_op);
            cops_compile_op(aTHX_ c, subscript);
            cops_emit(c, COPS_HASH_SLICE);
            break;
        }
        
        case OP_SPRINTF: {
            /* sprintf format, args... */
            OP *kid = cLISTOPo->op_first;
            if (kid->op_type == OP_PUSHMARK) kid = OpSIBLING(kid);
            /* Count and compile all arguments */
            int argc = 0;
            OP *arg;
            for (arg = kid; arg; arg = OpSIBLING(arg)) {
                cops_compile_op(aTHX_ c, arg);
                argc++;
            }
            cops_emit_iv(c, COPS_SPRINTF, argc);
            break;
        }
        
        case OP_JOIN: {
            OP *kid = cLISTOPo->op_first;
            if (kid->op_type == OP_PUSHMARK) kid = OpSIBLING(kid);
            /* First arg is separator, rest is list */
            OP *sep = kid;
            OP *list = OpSIBLING(sep);
            cops_compile_op(aTHX_ c, sep);
            cops_compile_op(aTHX_ c, list);
            cops_emit(c, COPS_JOIN);
            break;
        }
        
        case OP_SPLIT: {
            OP *kid = cLISTOPo->op_first;
            if (kid->op_type == OP_PUSHMARK) kid = OpSIBLING(kid);
            /* Pattern, string, optional limit */
            OP *pattern = kid;
            OP *str_op = OpSIBLING(pattern);
            OP *limit = str_op ? OpSIBLING(str_op) : NULL;
            
            cops_compile_op(aTHX_ c, pattern);
            if (str_op) cops_compile_op(aTHX_ c, str_op);
            else cops_emit(c, COPS_PUSH_VAL);
            
            if (limit) {
                cops_compile_op(aTHX_ c, limit);
                cops_emit(c, COPS_SPLIT3);
            } else {
                cops_emit(c, COPS_SPLIT);
            }
            break;
        }
        
        case OP_ORD: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_ORD);
            break;
        }
        
        case OP_CHR: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_CHR);
            break;
        }
        
        case OP_HEX: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_HEX);
            break;
        }
        
        case OP_OCT: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_OCT);
            break;
        }
        
        case OP_SQRT: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_SQRT);
            break;
        }
        
        case OP_SIN: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_SIN);
            break;
        }
        
        case OP_COS: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_COS);
            break;
        }
        
        case OP_EXP: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_EXP);
            break;
        }
        
        case OP_LOG: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_LOG);
            break;
        }
        
        case OP_ATAN2: {
            OP *y = cLISTOPo->op_first;
            if (y->op_type == OP_PUSHMARK) y = OpSIBLING(y);
            OP *x = OpSIBLING(y);
            cops_compile_op(aTHX_ c, y);
            cops_compile_op(aTHX_ c, x);
            cops_emit(c, COPS_ATAN2);
            break;
        }
        
        case OP_RAND: {
            OP *kid = cUNOPo->op_first;
            if (kid) {
                cops_compile_op(aTHX_ c, kid);
                cops_emit(c, COPS_RAND);
            } else {
                cops_emit_nv(c, COPS_PUSH_NV, 1.0);
                cops_emit(c, COPS_RAND);
            }
            break;
        }
        
        case OP_SRAND: {
            OP *kid = cUNOPo->op_first;
            if (kid) {
                cops_compile_op(aTHX_ c, kid);
            } else {
                cops_emit(c, COPS_PUSH_UNDEF);
            }
            cops_emit(c, COPS_SRAND);
            break;
        }
        
        case OP_QUOTEMETA: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_QUOTEMETA);
            break;
        }
        
        case OP_MATCH: {
            REGEXP *rx = NULL;
#ifdef USE_ITHREADS
            /* In ithreads, regex is in PL_regex_pad */
            {
                UV offset = cPMOPo->op_pmoffset;
                SV *rsv = PL_regex_pad[offset];
                if (rsv && SvTYPE(rsv) == SVt_REGEXP) {
                    rx = (REGEXP*)rsv;
                }
            }
#elif PERL_VERSION_GE(5,10,0)
            rx = PM_GETRE(cPMOPo);
#else
            rx = cPMOPo->op_pmregexp;
#endif
            if (!rx) {
                cops_fail(c, "match without compiled regex");
                return;
            }
            cops_emit(c, COPS_PUSH_VAL);
            cops_emit_rx(c, COPS_MATCH, rx);
            break;
        }
        case OP_AND: {
            OP *left = cLOGOPo->op_first;
            OP *right = OpSIBLING(left);
            
            cops_compile_op(aTHX_ c, left);
            int jump_pos = c->prog->len;
            cops_emit(c, COPS_AND);
            cops_compile_op(aTHX_ c, right);
            c->prog->code[jump_pos].arg.jump_offset = c->prog->len - jump_pos;
            break;
        }
        
        case OP_OR: {
            OP *left = cLOGOPo->op_first;
            OP *right = OpSIBLING(left);
            
            cops_compile_op(aTHX_ c, left);
            int jump_pos = c->prog->len;
            cops_emit(c, COPS_OR);
            cops_compile_op(aTHX_ c, right);
            c->prog->code[jump_pos].arg.jump_offset = c->prog->len - jump_pos;
            break;
        }
        
        case OP_DOR: {
            /* Defined-or: $a // $b */
            OP *left = cLOGOPo->op_first;
            OP *right = OpSIBLING(left);
            
            cops_compile_op(aTHX_ c, left);
            int jump_pos = c->prog->len;
            cops_emit(c, COPS_DOR);
            cops_compile_op(aTHX_ c, right);
            c->prog->code[jump_pos].arg.jump_offset = c->prog->len - jump_pos;
            break;
        }
        
        case OP_WANTARRAY: {
            cops_emit(c, COPS_WANTARRAY);
            break;
        }
        
        case OP_CALLER: {
            OP *kid = cUNOPo->op_first;
            if (kid) {
                cops_compile_op(aTHX_ c, kid);
            } else {
                cops_emit_iv(c, COPS_PUSH_IV, 0);
            }
            cops_emit(c, COPS_CALLER);
            break;
        }
        
        case OP_SCALAR: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_SCALAR);
            break;
        }
        
        case OP_PROTOTYPE: {
            OP *kid = cUNOPo->op_first;
            cops_compile_op(aTHX_ c, kid);
            cops_emit(c, COPS_PROTOTYPE);
            break;
        }
        
        case OP_BLESS: {
            OP *kid = cLISTOPo->op_first;
            if (kid->op_type == OP_PUSHMARK) kid = OpSIBLING(kid);
            OP *ref = kid;
            OP *class_op = OpSIBLING(ref);
            cops_compile_op(aTHX_ c, ref);
            if (class_op) {
                cops_compile_op(aTHX_ c, class_op);
            } else {
                cops_emit(c, COPS_PUSH_CALLER_PKG);
            }
            cops_emit(c, COPS_BLESS);
            break;
        }
        
        case OP_TIE:
        case OP_UNTIE:
        case OP_TIED: {
            cops_fail(c, "tie operations not supported");
            break;
        }
        
        default:
            cops_fail(c, PL_op_name[o->op_type]);
            break;
    }
}


/* ═══════════════════════════════════════════════════════════════════════════
   Peephole Optimizer - fuse common patterns into specialized ops
   ═══════════════════════════════════════════════════════════════════════════ */

static void
cops_peephole_optimize(CopsProgram *prog) {
    CopsInstruction *code = prog->code;
    int len = prog->len;
    int i;
    
    for (i = 0; i < len; i++) {
        /* Pattern: PUSH_VAL, PUSH_IV 0, GT -> PUSH_VAL, IS_POSITIVE */
        if (i < len - 2 &&
            code[i].opcode == COPS_PUSH_VAL &&
            code[i+1].opcode == COPS_PUSH_IV &&
            code[i+1].arg.iv == 0 &&
            code[i+2].opcode == COPS_GT) {
            /* Keep PUSH_VAL, replace rest with IS_POSITIVE */
            code[i+1].opcode = COPS_IS_POSITIVE;
            code[i+2].opcode = COPS_POP;
        }
        
        /* Pattern: PUSH_VAL, PUSH_IV 0, LT -> PUSH_VAL, IS_NEGATIVE */
        if (i < len - 2 &&
            code[i].opcode == COPS_PUSH_VAL &&
            code[i+1].opcode == COPS_PUSH_IV &&
            code[i+1].arg.iv == 0 &&
            code[i+2].opcode == COPS_LT) {
            code[i+1].opcode = COPS_IS_NEGATIVE;
            code[i+2].opcode = COPS_POP;
        }
        
        /* Pattern: PUSH_VAL, PUSH_IV 0, EQ_NUM -> PUSH_VAL, IS_ZERO */
        if (i < len - 2 &&
            code[i].opcode == COPS_PUSH_VAL &&
            code[i+1].opcode == COPS_PUSH_IV &&
            code[i+1].arg.iv == 0 &&
            code[i+2].opcode == COPS_EQ_NUM) {
            code[i+1].opcode = COPS_IS_ZERO;
            code[i+2].opcode = COPS_POP;
        }
        
        /* Pattern: PUSH_VAL, PUSH_IV 2, MOD, PUSH_IV 0, EQ_NUM -> PUSH_VAL, IS_EVEN */
        if (i < len - 4 &&
            code[i].opcode == COPS_PUSH_VAL &&
            code[i+1].opcode == COPS_PUSH_IV &&
            code[i+1].arg.iv == 2 &&
            code[i+2].opcode == COPS_MOD &&
            code[i+3].opcode == COPS_PUSH_IV &&
            code[i+3].arg.iv == 0 &&
            code[i+4].opcode == COPS_EQ_NUM) {
            /* PUSH_VAL, IS_EVEN, POP, POP, POP */
            code[i+1].opcode = COPS_IS_EVEN;
            code[i+2].opcode = COPS_POP;
            code[i+3].opcode = COPS_POP;
            code[i+4].opcode = COPS_POP;
        }
        
        /* Pattern: PUSH_VAL, PUSH_IV 2, MOD, PUSH_IV 0, NE_NUM -> PUSH_VAL, IS_ODD */
        if (i < len - 4 &&
            code[i].opcode == COPS_PUSH_VAL &&
            code[i+1].opcode == COPS_PUSH_IV &&
            code[i+1].arg.iv == 2 &&
            code[i+2].opcode == COPS_MOD &&
            code[i+3].opcode == COPS_PUSH_IV &&
            code[i+3].arg.iv == 0 &&
            code[i+4].opcode == COPS_NE_NUM) {
            code[i+1].opcode = COPS_IS_ODD;
            code[i+2].opcode = COPS_POP;
            code[i+3].opcode = COPS_POP;
            code[i+4].opcode = COPS_POP;
        }
    }
    
    /* Compaction pass - remove POPs */
    int write_idx = 0;
    for (i = 0; i < len; i++) {
        if (code[i].opcode != COPS_POP) {
            if (write_idx != i) {
                code[write_idx] = code[i];
            }
            write_idx++;
        }
    }
    prog->len = write_idx;
}

/* Compile a CV to bytecode */
static CopsProgram*
cops_compile_cv(pTHX_ CV *cv) {
    CopsCompiler c;
    CopsProgram *prog;
    OP *root;
    
    Newxz(prog, 1, CopsProgram);
    prog->original_cv = SvREFCNT_inc((SV*)cv);
    prog->optimized = false;
    
    c.prog = prog;
    c.cv = cv;
    c.failed = false;
    c.fail_reason = NULL;
    
    root = CvROOT(cv);
    if (!root) {
        c.failed = true;
        c.fail_reason = "no optree (XS sub?)";
    } else {
        cops_compile_op(aTHX_ &c, root);
    }
    
    if (c.failed) {
        prog->optimized = false;
    } else {
        cops_emit(&c, COPS_RETURN);
        cops_peephole_optimize(prog);
        prog->optimized = true;
    }
    
    return prog;
}

/* ═══════════════════════════════════════════════════════════════════════════
   Bytecode Executor
   ═══════════════════════════════════════════════════════════════════════════ */

#define COPS_STACK_SIZE 32

typedef struct {
    SV *sv;
    IV iv;
    NV nv;
    enum { STACK_SV, STACK_IV, STACK_NV, STACK_BOOL } type;
} CopsStackVal;

static bool
cops_execute(pTHX_ CopsProgram *prog, SV *input) {
    CopsStackVal stack[COPS_STACK_SIZE];
    int sp = 0;
    int pc = 0;
    
    if (!prog->optimized) {
        /* Fallback to Perl */
        dSP;
        int count;
        bool result = false;
        
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        SAVE_DEFSV;
        DEFSV = input;
        PUTBACK;
        
        count = call_sv(prog->original_cv, G_SCALAR);
        SPAGAIN;
        
        if (count > 0) {
            SV *ret = POPs;
            result = SvTRUE(ret);
        }
        
        PUTBACK;
        FREETMPS;
        LEAVE;
        
        return result;
    }
    
    /* Execute bytecode */
    while (pc < prog->len) {
        CopsInstruction *inst = &prog->code[pc];
        
        switch (inst->opcode) {
            case COPS_PUSH_VAL:
                stack[sp].sv = input;
                stack[sp].type = STACK_SV;
                sp++;
                break;
                
            case COPS_PUSH_IV:
                stack[sp].iv = inst->arg.iv;
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_PUSH_NV:
                stack[sp].nv = inst->arg.nv;
                stack[sp].type = STACK_NV;
                sp++;
                break;
                
            case COPS_PUSH_PV:
                stack[sp].sv = sv_2mortal(newSVpvn(inst->arg.str.pv, inst->arg.str.len));
                stack[sp].type = STACK_SV;
                sp++;
                break;
                
            case COPS_GT: case COPS_GE: case COPS_LT: case COPS_LE:
            case COPS_EQ_NUM: case COPS_NE_NUM: {
                NV left, right;
                bool result;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                
                switch (inst->opcode) {
                    case COPS_GT:     result = left > right; break;
                    case COPS_GE:     result = left >= right; break;
                    case COPS_LT:     result = left < right; break;
                    case COPS_LE:     result = left <= right; break;
                    case COPS_EQ_NUM: result = left == right; break;
                    case COPS_NE_NUM: result = left != right; break;
                    default: result = false;
                }
                stack[sp].iv = result;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_EQ_STR: case COPS_NE_STR: {
                SV *left_sv, *right_sv;
                bool result;
                sp--;
                right_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                           sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                left_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                          sv_2mortal(newSViv(stack[sp].iv));
                result = sv_eq(left_sv, right_sv);
                if (inst->opcode == COPS_NE_STR) result = !result;
                stack[sp].iv = result;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_DEFINED:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV) ? SvOK(stack[sp].sv) : 1;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_NOT:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = !SvTRUE(stack[sp].sv);
                } else {
                    stack[sp].iv = !stack[sp].iv;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_LENGTH:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    SvPV(stack[sp].sv, len);
                    stack[sp].iv = (IV)len;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_IS_REF:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV && SvROK(stack[sp].sv));
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_ARRAY:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvTYPE(SvRV(stack[sp].sv)) == SVt_PVAV);
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_HASH:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvTYPE(SvRV(stack[sp].sv)) == SVt_PVHV);
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_CODE:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvTYPE(SvRV(stack[sp].sv)) == SVt_PVCV);
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_SCALAR:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvTYPE(SvRV(stack[sp].sv)) < SVt_PVAV);
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_REGEXP:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvTYPE(SvRV(stack[sp].sv)) == SVt_REGEXP);
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_GLOB:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvTYPE(SvRV(stack[sp].sv)) == SVt_PVGV);
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_BLESSED:
                sp--;
                stack[sp].iv = (stack[sp].type == STACK_SV &&
                               SvROK(stack[sp].sv) &&
                               SvOBJECT(SvRV(stack[sp].sv)));
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_LOOKS_LIKE_NUM:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = looks_like_number(stack[sp].sv);
                } else {
                    stack[sp].iv = 1;  /* IVs and NVs are numbers */
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_INT:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = 1;
                } else if (stack[sp].type == STACK_NV) {
                    NV nv = stack[sp].nv;
                    stack[sp].iv = (nv == (NV)(IV)nv);
                } else if (stack[sp].type == STACK_SV) {
                    NV nv = SvNV(stack[sp].sv);
                    stack[sp].iv = (nv == (NV)(IV)nv);
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_POSITIVE:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = stack[sp].iv > 0;
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].iv = stack[sp].nv > 0;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = SvNV(stack[sp].sv) > 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_NEGATIVE:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = stack[sp].iv < 0;
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].iv = stack[sp].nv < 0;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = SvNV(stack[sp].sv) < 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_ZERO:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = stack[sp].iv == 0;
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].iv = stack[sp].nv == 0;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = SvNV(stack[sp].sv) == 0;
                } else {
                    stack[sp].iv = 1;  /* undef/null is zero */
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_TRUE:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = SvTRUE(stack[sp].sv);
                } else if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = stack[sp].iv != 0;
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].iv = stack[sp].nv != 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_FALSE:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = !SvTRUE(stack[sp].sv);
                } else if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = stack[sp].iv == 0;
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].iv = stack[sp].nv == 0;
                } else {
                    stack[sp].iv = 1;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_EMPTY_STR:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    SvPV(stack[sp].sv, len);
                    stack[sp].iv = (len == 0);
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_NONEMPTY_STR:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    SvPV(stack[sp].sv, len);
                    stack[sp].iv = (len > 0);
                } else {
                    stack[sp].iv = 1;  /* numbers are non-empty */
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_ABS:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    IV v = stack[sp].iv;
                    stack[sp].iv = (v < 0) ? -v : v;
                } else if (stack[sp].type == STACK_NV) {
                    NV v = stack[sp].nv;
                    stack[sp].nv = (v < 0) ? -v : v;
                } else if (stack[sp].type == STACK_SV) {
                    NV v = SvNV(stack[sp].sv);
                    stack[sp].nv = (v < 0) ? -v : v;
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_INT:
                sp--;
                if (stack[sp].type == STACK_NV) {
                    stack[sp].iv = (IV)stack[sp].nv;
                    stack[sp].type = STACK_IV;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = SvIV(stack[sp].sv);
                    stack[sp].type = STACK_IV;
                }
                /* IV stays as IV */
                sp++;
                break;
                
            case COPS_IS_EVEN:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = (stack[sp].iv % 2) == 0;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = (SvIV(stack[sp].sv) % 2) == 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_ODD:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = (stack[sp].iv % 2) != 0;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = (SvIV(stack[sp].sv) % 2) != 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_MOD: {
                IV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                stack[sp].iv = (right != 0) ? (left % right) : 0;
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_ADD: {
                NV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = left + right;
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_SUB: {
                NV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = left - right;
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_MUL: {
                NV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = left * right;
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_DIV: {
                NV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = (right != 0) ? (left / right) : 0;
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_ARRAY_LEN:
                sp--;
                if (stack[sp].type == STACK_SV && SvROK(stack[sp].sv) &&
                    SvTYPE(SvRV(stack[sp].sv)) == SVt_PVAV) {
                    stack[sp].iv = av_len((AV*)SvRV(stack[sp].sv)) + 1;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_HASH_SIZE:
                sp--;
                if (stack[sp].type == STACK_SV && SvROK(stack[sp].sv) &&
                    SvTYPE(SvRV(stack[sp].sv)) == SVt_PVHV) {
                    stack[sp].iv = HvKEYS((HV*)SvRV(stack[sp].sv));
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_ARRAY_EMPTY:
                sp--;
                if (stack[sp].type == STACK_SV && SvROK(stack[sp].sv) &&
                    SvTYPE(SvRV(stack[sp].sv)) == SVt_PVAV) {
                    stack[sp].iv = (av_len((AV*)SvRV(stack[sp].sv)) < 0);
                } else {
                    stack[sp].iv = 1;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_HASH_EMPTY:
                sp--;
                if (stack[sp].type == STACK_SV && SvROK(stack[sp].sv) &&
                    SvTYPE(SvRV(stack[sp].sv)) == SVt_PVHV) {
                    stack[sp].iv = (HvKEYS((HV*)SvRV(stack[sp].sv)) == 0);
                } else {
                    stack[sp].iv = 1;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_CONTAINS: {
                /* Pop haystack, use stored needle from arg */
                char *needle = inst->arg.str.pv;
                STRLEN needle_len = inst->arg.str.len;
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN haystack_len;
                    char *haystack = SvPV(stack[sp].sv, haystack_len);
                    char *found = (needle_len <= haystack_len) ?
                        strstr(haystack, needle) : NULL;
                    stack[sp].iv = (found != NULL);
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_STARTS_WITH: {
                char *prefix = inst->arg.str.pv;
                STRLEN prefix_len = inst->arg.str.len;
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN str_len;
                    char *str = SvPV(stack[sp].sv, str_len);
                    stack[sp].iv = (str_len >= prefix_len &&
                                   memcmp(str, prefix, prefix_len) == 0);
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_ENDS_WITH: {
                char *suffix = inst->arg.str.pv;
                STRLEN suffix_len = inst->arg.str.len;
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN str_len;
                    char *str = SvPV(stack[sp].sv, str_len);
                    stack[sp].iv = (str_len >= suffix_len &&
                                   memcmp(str + str_len - suffix_len, suffix, suffix_len) == 0);
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_IS_ALPHA:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isALPHA((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_ALNUM:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isALNUM((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_DIGIT:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isDIGIT((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_SPACE:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isSPACE((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_WORD:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        unsigned char c = (unsigned char)str[i];
                        ok = (isALNUM(c) || c == '_');
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_UPPER:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isUPPER((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_LOWER:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = (len > 0);
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isLOWER((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_ASCII:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    unsigned char *str = (unsigned char*)SvPV(stack[sp].sv, len);
                    bool ok = 1;
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = (str[i] < 128);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 1;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_IS_PRINTABLE:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    bool ok = 1;
                    STRLEN i;
                    for (i = 0; ok && i < len; i++) {
                        ok = isPRINT((unsigned char)str[i]);
                    }
                    stack[sp].iv = ok;
                } else {
                    stack[sp].iv = 1;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_DOR: {
                /* Defined-or: if defined, skip right side */
                sp--;
                bool is_defined = (stack[sp].type == STACK_SV) ? SvOK(stack[sp].sv) : 1;
                if (is_defined) {
                    /* Push the value back and skip right operand */
                    sp++;
                    pc += inst->arg.jump_offset;
                    continue;
                }
                break;
            }
            
            case COPS_DUP:
                /* Duplicate top of stack */
                if (sp > 0) {
                    stack[sp] = stack[sp-1];
                    sp++;
                }
                break;
                
            case COPS_POP:
                if (sp > 0) sp--;
                break;
                
            case COPS_SWAP:
                if (sp >= 2) {
                    CopsStackVal tmp = stack[sp-1];
                    stack[sp-1] = stack[sp-2];
                    stack[sp-2] = tmp;
                }
                break;

            case COPS_MATCH: {
                bool result = false;
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    REGEXP *rx = inst->arg.rx;
                    result = (pregexec(rx, str, str + len, str, 1, stack[sp].sv, 1) != 0);
                }
                stack[sp].iv = result;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_NOT_MATCH: {
                bool result = true;
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    REGEXP *rx = inst->arg.rx;
                    result = (pregexec(rx, str, str + len, str, 1, stack[sp].sv, 1) == 0);
                }
                stack[sp].iv = result;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_AND: {
                bool val;
                sp--;
                val = (stack[sp].type == STACK_SV) ? SvTRUE(stack[sp].sv) : stack[sp].iv != 0;
                if (!val) {
                    stack[sp].iv = 0;
                    stack[sp].type = STACK_BOOL;
                    sp++;
                    pc += inst->arg.jump_offset;
                    continue;
                }
                break;
            }
            
            case COPS_OR: {
                bool val;
                sp--;
                val = (stack[sp].type == STACK_SV) ? SvTRUE(stack[sp].sv) : stack[sp].iv != 0;
                if (val) {
                    stack[sp].iv = 1;
                    stack[sp].type = STACK_BOOL;
                    sp++;
                    pc += inst->arg.jump_offset;
                    continue;
                }
                break;
            }
            
            /* New opcodes for additional patterns */
            
            case COPS_NEGATE:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].iv = -stack[sp].iv;
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].nv = -stack[sp].nv;
                } else if (stack[sp].type == STACK_SV) {
                    stack[sp].nv = -SvNV(stack[sp].sv);
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_STRINGIFY:
                sp--;
                if (stack[sp].type == STACK_IV) {
                    stack[sp].sv = sv_2mortal(newSViv(stack[sp].iv));
                } else if (stack[sp].type == STACK_NV) {
                    stack[sp].sv = sv_2mortal(newSVnv(stack[sp].nv));
                }
                /* SV stays as SV */
                stack[sp].type = STACK_SV;
                sp++;
                break;
                
            case COPS_UC:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    SV *result = sv_2mortal(newSVpvn(str, len));
                    char *p = SvPV_nolen(result);
                    STRLEN i;
                    for (i = 0; i < len; i++) {
                        p[i] = toUPPER((unsigned char)p[i]);
                    }
                    stack[sp].sv = result;
                }
                sp++;
                break;
                
            case COPS_LC:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    SV *result = sv_2mortal(newSVpvn(str, len));
                    char *p = SvPV_nolen(result);
                    STRLEN i;
                    for (i = 0; i < len; i++) {
                        p[i] = toLOWER((unsigned char)p[i]);
                    }
                    stack[sp].sv = result;
                }
                sp++;
                break;
                
            case COPS_UCFIRST:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    SV *result = sv_2mortal(newSVpvn(str, len));
                    if (len > 0) {
                        char *p = SvPV_nolen(result);
                        p[0] = toUPPER((unsigned char)p[0]);
                    }
                    stack[sp].sv = result;
                }
                sp++;
                break;
                
            case COPS_LCFIRST:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    SV *result = sv_2mortal(newSVpvn(str, len));
                    if (len > 0) {
                        char *p = SvPV_nolen(result);
                        p[0] = toLOWER((unsigned char)p[0]);
                    }
                    stack[sp].sv = result;
                }
                sp++;
                break;

            case COPS_FC:
                /* fc() - Unicode fold case (simple ASCII version) */
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    SV *result = sv_2mortal(newSVpvn(str, len));
                    char *p = SvPV_nolen(result);
                    STRLEN i;
                    for (i = 0; i < len; i++) {
                        /* fc() is like lc() but handles special cases for case-folding */
                        p[i] = toLOWER((unsigned char)p[i]);
                    }
                    stack[sp].sv = result;
                }
                sp++;
                break;

            case COPS_CHOP: {
                /* chop() - remove and return last character */
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    if (len > 0) {
                        /* Return the chopped character */
                        stack[sp].sv = sv_2mortal(newSVpvn(str + len - 1, 1));
                    } else {
                        stack[sp].sv = sv_2mortal(newSVpvn("", 0));
                    }
                }
                sp++;
                break;
            }

            case COPS_CHOMP: {
                /* chomp() - remove trailing newline, return count of removed chars */
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    IV removed = 0;
                    if (len > 0 && str[len - 1] == '\n') {
                        removed = 1;
                    }
                    stack[sp].iv = removed;
                    stack[sp].type = STACK_IV;
                } else {
                    stack[sp].iv = 0;
                    stack[sp].type = STACK_IV;
                }
                sp++;
                break;
            }

            case COPS_POS: {
                /* pos() - get position in string from last m//g match */
                /* In predicate context, pos() typically returns undef/0 since
                   we're checking against fresh input without regex state */
                sp--;
                if (stack[sp].type == STACK_SV && stack[sp].sv && SvMAGICAL(stack[sp].sv)) {
                    SV *sv = stack[sp].sv;
                    MAGIC *mg = mg_find(sv, PERL_MAGIC_regex_global);
                    if (mg) {
                        stack[sp].iv = (IV)mg->mg_len;
                        stack[sp].type = STACK_IV;
                        sp++;
                        break;
                    }
                }
                /* No pos set, return 0 (effectively undef in numeric context) */
                stack[sp].iv = 0;
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }

            case COPS_CONCAT: {
                SV *right_sv, *left_sv, *result;
                sp--;
                right_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                           sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                left_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                          sv_2mortal(newSViv(stack[sp].iv));
                result = sv_2mortal(newSVsv(left_sv));
                sv_catsv(result, right_sv);
                stack[sp].sv = result;
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_REPEAT: {
                IV count;
                SV *str_sv;
                sp--;
                count = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                if (count > 0) {
                    STRLEN len;
                    char *str = SvPV(str_sv, len);
                    SV *result = sv_2mortal(newSVpvn("", 0));
                    IV i;
                    for (i = 0; i < count; i++) {
                        sv_catpvn(result, str, len);
                    }
                    stack[sp].sv = result;
                } else {
                    stack[sp].sv = sv_2mortal(newSVpvn("", 0));
                }
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_POW: {
                NV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = pow(left, right);
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_INDEX: {
                SV *str_sv, *substr_sv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                char *found = (sub_len <= str_len) ? strstr(str, sub) : NULL;
                stack[sp].iv = found ? (IV)(found - str) : -1;
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_INDEX_POS: {
                IV pos;
                SV *str_sv, *substr_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                if (pos < 0) pos = 0;
                if ((STRLEN)pos >= str_len) {
                    stack[sp].iv = -1;
                } else {
                    char *found = strstr(str + pos, sub);
                    stack[sp].iv = found ? (IV)(found - str) : -1;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_RINDEX: {
                SV *str_sv, *substr_sv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                IV result = -1;
                if (sub_len <= str_len) {
                    IV i;
                    for (i = (IV)(str_len - sub_len); i >= 0; i--) {
                        if (memcmp(str + i, sub, sub_len) == 0) {
                            result = i;
                            break;
                        }
                    }
                }
                stack[sp].iv = result;
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_RINDEX_POS: {
                IV pos;
                SV *str_sv, *substr_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                IV result = -1;
                if (pos >= (IV)str_len) pos = (IV)str_len - 1;
                if (sub_len <= str_len && pos >= 0) {
                    IV i;
                    IV start = pos;
                    if (start > (IV)(str_len - sub_len)) start = (IV)(str_len - sub_len);
                    for (i = start; i >= 0; i--) {
                        if (memcmp(str + i, sub, sub_len) == 0) {
                            result = i;
                            break;
                        }
                    }
                }
                stack[sp].iv = result;
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }

            /* Boolean versions of index - return true/false instead of position */
            case COPS_INDEX_BOOL: {
                /* index() >= 0: true if found */
                SV *str_sv, *substr_sv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                char *found = (sub_len <= str_len) ? strstr(str, sub) : NULL;
                stack[sp].iv = found ? 1 : 0;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_INDEX_BOOL_NEG: {
                /* index() < 0: true if NOT found */
                SV *str_sv, *substr_sv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                char *found = (sub_len <= str_len) ? strstr(str, sub) : NULL;
                stack[sp].iv = found ? 0 : 1;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_INDEX_POS_BOOL: {
                /* index($str, $sub, $pos) >= 0: true if found */
                IV pos;
                SV *str_sv, *substr_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                int found = 0;
                if (pos < 0) pos = 0;
                if ((STRLEN)pos < str_len) {
                    found = strstr(str + pos, sub) != NULL;
                }
                stack[sp].iv = found ? 1 : 0;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_INDEX_POS_BOOL_NEG: {
                /* index($str, $sub, $pos) < 0: true if NOT found */
                IV pos;
                SV *str_sv, *substr_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                int found = 0;
                if (pos < 0) pos = 0;
                if ((STRLEN)pos < str_len) {
                    found = strstr(str + pos, sub) != NULL;
                }
                stack[sp].iv = found ? 0 : 1;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_RINDEX_BOOL: {
                /* rindex() >= 0: true if found */
                SV *str_sv, *substr_sv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                int found = 0;
                if (sub_len <= str_len) {
                    IV i;
                    for (i = (IV)(str_len - sub_len); i >= 0; i--) {
                        if (memcmp(str + i, sub, sub_len) == 0) {
                            found = 1;
                            break;
                        }
                    }
                }
                stack[sp].iv = found ? 1 : 0;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_RINDEX_BOOL_NEG: {
                /* rindex() < 0: true if NOT found */
                SV *str_sv, *substr_sv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                int found = 0;
                if (sub_len <= str_len) {
                    IV i;
                    for (i = (IV)(str_len - sub_len); i >= 0; i--) {
                        if (memcmp(str + i, sub, sub_len) == 0) {
                            found = 1;
                            break;
                        }
                    }
                }
                stack[sp].iv = found ? 0 : 1;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_RINDEX_POS_BOOL: {
                /* rindex($str, $sub, $pos) >= 0: true if found */
                IV pos;
                SV *str_sv, *substr_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                int found = 0;
                if (pos >= (IV)str_len) pos = (IV)str_len - 1;
                if (sub_len <= str_len && pos >= 0) {
                    IV i;
                    IV start = pos;
                    if (start > (IV)(str_len - sub_len)) start = (IV)(str_len - sub_len);
                    for (i = start; i >= 0; i--) {
                        if (memcmp(str + i, sub, sub_len) == 0) {
                            found = 1;
                            break;
                        }
                    }
                }
                stack[sp].iv = found ? 1 : 0;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_RINDEX_POS_BOOL_NEG: {
                /* rindex($str, $sub, $pos) < 0: true if NOT found */
                IV pos;
                SV *str_sv, *substr_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                substr_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                            sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len, sub_len;
                char *str = SvPV(str_sv, str_len);
                char *sub = SvPV(substr_sv, sub_len);
                int found = 0;
                if (pos >= (IV)str_len) pos = (IV)str_len - 1;
                if (sub_len <= str_len && pos >= 0) {
                    IV i;
                    IV start = pos;
                    if (start > (IV)(str_len - sub_len)) start = (IV)(str_len - sub_len);
                    for (i = start; i >= 0; i--) {
                        if (memcmp(str + i, sub, sub_len) == 0) {
                            found = 1;
                            break;
                        }
                    }
                }
                stack[sp].iv = found ? 0 : 1;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }

            case COPS_SUBSTR: {
                IV pos;
                SV *str_sv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len;
                char *str = SvPV(str_sv, str_len);
                if (pos < 0) pos = (IV)str_len + pos;
                if (pos < 0) pos = 0;
                if ((STRLEN)pos >= str_len) {
                    stack[sp].sv = sv_2mortal(newSVpvn("", 0));
                } else {
                    stack[sp].sv = sv_2mortal(newSVpvn(str + pos, str_len - pos));
                }
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_SUBSTR3: {
                IV pos, len;
                SV *str_sv;
                sp--;
                len = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                pos = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                str_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                STRLEN str_len;
                char *str = SvPV(str_sv, str_len);
                if (pos < 0) pos = (IV)str_len + pos;
                if (pos < 0) pos = 0;
                if ((STRLEN)pos >= str_len) {
                    stack[sp].sv = sv_2mortal(newSVpvn("", 0));
                } else {
                    if (len < 0) len = (IV)(str_len - pos) + len;
                    if (len < 0) len = 0;
                    if ((STRLEN)(pos + len) > str_len) len = (IV)(str_len - pos);
                    stack[sp].sv = sv_2mortal(newSVpvn(str + pos, len));
                }
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_ARRAY_ELEM: {
                IV idx = inst->arg.iv;
                sp--;
                if (stack[sp].type == STACK_SV && SvROK(stack[sp].sv) &&
                    SvTYPE(SvRV(stack[sp].sv)) == SVt_PVAV) {
                    AV *av = (AV*)SvRV(stack[sp].sv);
                    SV **svp = av_fetch(av, idx, 0);
                    stack[sp].sv = svp ? *svp : &PL_sv_undef;
                } else {
                    stack[sp].sv = &PL_sv_undef;
                }
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_ARRAY_ELEM_DYN: {
                IV idx;
                SV *av_sv;
                sp--;
                idx = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                av_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv : &PL_sv_undef;
                if (SvROK(av_sv) && SvTYPE(SvRV(av_sv)) == SVt_PVAV) {
                    AV *av = (AV*)SvRV(av_sv);
                    SV **svp = av_fetch(av, idx, 0);
                    stack[sp].sv = svp ? *svp : &PL_sv_undef;
                } else {
                    stack[sp].sv = &PL_sv_undef;
                }
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_HASH_ELEM_DYN: {
                SV *key_sv, *hv_sv;
                sp--;
                key_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                         sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                hv_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv : &PL_sv_undef;
                if (SvROK(hv_sv) && SvTYPE(SvRV(hv_sv)) == SVt_PVHV) {
                    HV *hv = (HV*)SvRV(hv_sv);
                    STRLEN key_len;
                    char *key = SvPV(key_sv, key_len);
                    SV **svp = hv_fetch(hv, key, key_len, 0);
                    stack[sp].sv = svp ? *svp : &PL_sv_undef;
                } else {
                    stack[sp].sv = &PL_sv_undef;
                }
                stack[sp].type = STACK_SV;
                sp++;
                break;
            }
            
            case COPS_RV2AV:
            case COPS_RV2HV:
                /* Just pass through - the value should already be an RV */
                break;
                
            case COPS_KEYS:
                sp--;
                if (stack[sp].type == STACK_SV && SvROK(stack[sp].sv) &&
                    SvTYPE(SvRV(stack[sp].sv)) == SVt_PVHV) {
                    stack[sp].iv = HvKEYS((HV*)SvRV(stack[sp].sv));
                    stack[sp].type = STACK_IV;
                } else {
                    stack[sp].iv = 0;
                    stack[sp].type = STACK_IV;
                }
                sp++;
                break;
                
            case COPS_VALUES:
            case COPS_EACH:
                /* These return lists - fall back for now */
                sp--;
                stack[sp].sv = &PL_sv_undef;
                stack[sp].type = STACK_SV;
                sp++;
                break;
                
            case COPS_EXISTS:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    SV *ref = stack[sp].sv;
                    /* Check if the ref contains an existing element */
                    stack[sp].iv = SvOK(ref) ? 1 : 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_DELETE:
                /* Delete returns the deleted value - pass through for now */
                break;
                
            case COPS_SLT: case COPS_SGT: case COPS_SLE: case COPS_SGE: {
                SV *left_sv, *right_sv;
                int cmp;
                sp--;
                right_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                           sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                left_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                          sv_2mortal(newSViv(stack[sp].iv));
                cmp = sv_cmp(left_sv, right_sv);
                switch (inst->opcode) {
                    case COPS_SLT: stack[sp].iv = (cmp < 0); break;
                    case COPS_SGT: stack[sp].iv = (cmp > 0); break;
                    case COPS_SLE: stack[sp].iv = (cmp <= 0); break;
                    case COPS_SGE: stack[sp].iv = (cmp >= 0); break;
                    default: stack[sp].iv = 0;
                }
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
            }
            
            case COPS_SCMP: {
                SV *left_sv, *right_sv;
                sp--;
                right_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                           sv_2mortal(newSViv(stack[sp].iv));
                sp--;
                left_sv = (stack[sp].type == STACK_SV) ? stack[sp].sv :
                          sv_2mortal(newSViv(stack[sp].iv));
                stack[sp].iv = sv_cmp(left_sv, right_sv);
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_NCMP: {
                NV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].iv = (left < right) ? -1 : (left > right) ? 1 : 0;
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_BIT_AND: {
                UV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                stack[sp].iv = (IV)(left & right);
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_BIT_OR: {
                UV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                stack[sp].iv = (IV)(left | right);
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_BIT_XOR: {
                UV left, right;
                sp--;
                right = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                sp--;
                left = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                       (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                stack[sp].iv = (IV)(left ^ right);
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_BIT_NOT:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    stack[sp].iv = (IV)~SvUV(stack[sp].sv);
                } else {
                    stack[sp].iv = ~stack[sp].iv;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_LEFT_SHIFT: {
                UV val;
                IV shift;
                sp--;
                shift = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                val = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                stack[sp].iv = (IV)(val << shift);
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_RIGHT_SHIFT: {
                UV val;
                IV shift;
                sp--;
                shift = (stack[sp].type == STACK_SV) ? SvIV(stack[sp].sv) :
                        (stack[sp].type == STACK_IV) ? stack[sp].iv : (IV)stack[sp].nv;
                sp--;
                val = (stack[sp].type == STACK_SV) ? SvUV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? (UV)stack[sp].iv : (UV)stack[sp].nv;
                stack[sp].iv = (IV)(val >> shift);
                stack[sp].type = STACK_IV;
                sp++;
                break;
            }
            
            case COPS_JUMP:
                pc += inst->arg.jump_offset;
                continue;
                
            case COPS_JUMP_UNLESS: {
                bool val;
                sp--;
                val = (stack[sp].type == STACK_SV) ? SvTRUE(stack[sp].sv) : stack[sp].iv != 0;
                if (!val) {
                    pc += inst->arg.jump_offset;
                    continue;
                }
                break;
            }
            
            case COPS_REVERSE:
                /* For strings, reverse characters; for arrays, reverse elements */
                sp--;
                if (stack[sp].type == STACK_SV) {
                    if (SvROK(stack[sp].sv) && SvTYPE(SvRV(stack[sp].sv)) == SVt_PVAV) {
                        /* Array reverse - fall back for now */
                        sp++;
                    } else {
                        /* String reverse */
                        STRLEN len;
                        char *str = SvPV(stack[sp].sv, len);
                        SV *result = sv_2mortal(newSVpvn("", 0));
                        if (len > 0) {
                            STRLEN i;
                            SvGROW(result, len + 1);
                            char *dst = SvPVX(result);
                            for (i = 0; i < len; i++) {
                                dst[i] = str[len - 1 - i];
                            }
                            dst[len] = '\0';
                            SvCUR_set(result, len);
                        }
                        stack[sp].sv = result;
                        sp++;
                    }
                } else {
                    sp++;
                }
                break;
                
            case COPS_SORT:
            case COPS_LIST_SLICE:
            case COPS_ARRAY_SLICE:
            case COPS_HASH_SLICE:
            case COPS_SPRINTF:
            case COPS_JOIN:
            case COPS_SPLIT:
            case COPS_SPLIT3:
                /* Complex operations - fall back */
                break;
                
            case COPS_ORD:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    unsigned char *str = (unsigned char*)SvPV(stack[sp].sv, len);
                    stack[sp].iv = (len > 0) ? str[0] : 0;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_CHR:
                sp--;
                {
                    IV code;
                    if (stack[sp].type == STACK_SV) {
                        code = SvIV(stack[sp].sv);
                    } else if (stack[sp].type == STACK_IV) {
                        code = stack[sp].iv;
                    } else {
                        code = (IV)stack[sp].nv;
                    }
                    char c = (char)(code & 0xFF);
                    stack[sp].sv = sv_2mortal(newSVpvn(&c, 1));
                    stack[sp].type = STACK_SV;
                }
                sp++;
                break;
                
            case COPS_HEX:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    UV uv;
                    int flags = PERL_SCAN_ALLOW_UNDERSCORES;
                    uv = grok_hex(str, &len, &flags, NULL);
                    stack[sp].iv = (IV)uv;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_OCT:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    UV uv;
                    int flags = PERL_SCAN_ALLOW_UNDERSCORES;
                    uv = grok_oct(str, &len, &flags, NULL);
                    stack[sp].iv = (IV)uv;
                } else {
                    stack[sp].iv = 0;
                }
                stack[sp].type = STACK_IV;
                sp++;
                break;
                
            case COPS_SQRT:
                sp--;
                {
                    NV val;
                    if (stack[sp].type == STACK_SV) {
                        val = SvNV(stack[sp].sv);
                    } else if (stack[sp].type == STACK_IV) {
                        val = (NV)stack[sp].iv;
                    } else {
                        val = stack[sp].nv;
                    }
                    stack[sp].nv = sqrt(val);
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_SIN:
                sp--;
                {
                    NV val;
                    if (stack[sp].type == STACK_SV) {
                        val = SvNV(stack[sp].sv);
                    } else if (stack[sp].type == STACK_IV) {
                        val = (NV)stack[sp].iv;
                    } else {
                        val = stack[sp].nv;
                    }
                    stack[sp].nv = sin(val);
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_COS:
                sp--;
                {
                    NV val;
                    if (stack[sp].type == STACK_SV) {
                        val = SvNV(stack[sp].sv);
                    } else if (stack[sp].type == STACK_IV) {
                        val = (NV)stack[sp].iv;
                    } else {
                        val = stack[sp].nv;
                    }
                    stack[sp].nv = cos(val);
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_EXP:
                sp--;
                {
                    NV val;
                    if (stack[sp].type == STACK_SV) {
                        val = SvNV(stack[sp].sv);
                    } else if (stack[sp].type == STACK_IV) {
                        val = (NV)stack[sp].iv;
                    } else {
                        val = stack[sp].nv;
                    }
                    stack[sp].nv = exp(val);
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_LOG:
                sp--;
                {
                    NV val;
                    if (stack[sp].type == STACK_SV) {
                        val = SvNV(stack[sp].sv);
                    } else if (stack[sp].type == STACK_IV) {
                        val = (NV)stack[sp].iv;
                    } else {
                        val = stack[sp].nv;
                    }
                    stack[sp].nv = (val > 0) ? log(val) : 0;
                    stack[sp].type = STACK_NV;
                }
                sp++;
                break;
                
            case COPS_ATAN2: {
                NV y, x;
                sp--;
                x = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                    (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                sp--;
                y = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                    (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = atan2(y, x);
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_RAND: {
                NV max;
                sp--;
                max = (stack[sp].type == STACK_SV) ? SvNV(stack[sp].sv) :
                      (stack[sp].type == STACK_IV) ? (NV)stack[sp].iv : stack[sp].nv;
                stack[sp].nv = Drand01() * max;
                stack[sp].type = STACK_NV;
                sp++;
                break;
            }
            
            case COPS_SRAND:
                sp--;
                /* srand is a side-effect, just consume the argument */
                break;
                
            case COPS_QUOTEMETA:
                sp--;
                if (stack[sp].type == STACK_SV) {
                    STRLEN len;
                    char *str = SvPV(stack[sp].sv, len);
                    SV *result = sv_2mortal(newSVpvn("", 0));
                    STRLEN i;
                    for (i = 0; i < len; i++) {
                        unsigned char c = (unsigned char)str[i];
                        if (!isALNUM(c)) {
                            sv_catpvn(result, "\\", 1);
                        }
                        sv_catpvn(result, (char*)&c, 1);
                    }
                    stack[sp].sv = result;
                }
                sp++;
                break;
                
            case COPS_WANTARRAY:
                /* In this context, always return scalar */
                stack[sp].iv = 0;
                stack[sp].type = STACK_BOOL;
                sp++;
                break;
                
            case COPS_CALLER:
            case COPS_SCALAR:
            case COPS_PROTOTYPE:
            case COPS_BLESS:
            case COPS_PUSH_UNDEF:
            case COPS_PUSH_CALLER_PKG:
                /* Complex operations - fall back or simple handling */
                if (inst->opcode == COPS_PUSH_UNDEF) {
                    stack[sp].sv = &PL_sv_undef;
                    stack[sp].type = STACK_SV;
                    sp++;
                }
                break;
            
            case COPS_RETURN:
                if (sp > 0) {
                    sp--;
                    return (stack[sp].type == STACK_SV) ? SvTRUE(stack[sp].sv) : stack[sp].iv != 0;
                }
                return false;
        }
        
        pc++;
    }
    
    if (sp > 0) {
        sp--;
        return (stack[sp].type == STACK_SV) ? SvTRUE(stack[sp].sv) : stack[sp].iv != 0;
    }
    return false;
}

/* Free a compiled program */
static void
cops_free_program(pTHX_ CopsProgram *prog) {
    int i;
    if (!prog) return;
    
    for (i = 0; i < prog->len; i++) {
        CopsInstruction *inst = &prog->code[i];
        if (inst->opcode == COPS_PUSH_PV && inst->arg.str.pv) {
            Safefree(inst->arg.str.pv);
        }
        if ((inst->opcode == COPS_MATCH || inst->opcode == COPS_NOT_MATCH) && inst->arg.rx) {
            ReREFCNT_dec(inst->arg.rx);
        }
    }
    
    if (prog->code) Safefree(prog->code);
    if (prog->original_cv) SvREFCNT_dec(prog->original_cv);
    Safefree(prog);
}

/* Magic vtable for cleanup */
static int
cops_program_free_magic(pTHX_ SV *sv, MAGIC *mg) {
    CopsProgram *prog = (CopsProgram *)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);
    cops_free_program(aTHX_ prog);
    return 0;
}

static MGVTBL cops_program_vtbl = {
    NULL,                     /* get */
    NULL,                     /* set */
    NULL,                     /* len */
    NULL,                     /* clear */
    cops_program_free_magic,  /* free */
    NULL,                     /* copy */
    NULL,                     /* dup */
    NULL                      /* local */
};

/* ═══════════════════════════════════════════════════════════════════════════
   XS Interface
   ═══════════════════════════════════════════════════════════════════════════ */

MODULE = Stefo  PACKAGE = Stefo

PROTOTYPES: DISABLE

SV *
compile(sub_ref)
    SV *sub_ref
CODE:
{
    CV *cv;
    CopsProgram *prog;
    SV *wrapper;
    
    if (!SvROK(sub_ref) || SvTYPE(SvRV(sub_ref)) != SVt_PVCV) {
        croak("Stefo::compile requires a CODE reference");
    }
    
    cv = (CV*)SvRV(sub_ref);
    prog = cops_compile_cv(aTHX_ cv);
    
    wrapper = newSViv(PTR2IV(prog));
    sv_magicext(wrapper, NULL, PERL_MAGIC_ext, &cops_program_vtbl, (char*)prog, 0);
    RETVAL = sv_bless(newRV_noinc(wrapper), gv_stashpv("Stefo::Compiled", GV_ADD));
}
OUTPUT:
    RETVAL

bool
check(compiled, value)
    SV *compiled
    SV *value
CODE:
{
    CopsProgram *prog;
    SV *inner;
    
    if (!SvROK(compiled)) {
        croak("Stefo::check requires a compiled program");
    }
    
    inner = SvRV(compiled);
    prog = INT2PTR(CopsProgram*, SvIV(inner));
    RETVAL = cops_execute(aTHX_ prog, value);
}
OUTPUT:
    RETVAL

bool
is_optimized(compiled)
    SV *compiled
CODE:
{
    if (!SvROK(compiled)) {
        RETVAL = false;
    } else {
        SV *inner = SvRV(compiled);
        CopsProgram *prog = INT2PTR(CopsProgram*, SvIV(inner));
        RETVAL = prog->optimized;
    }
}
OUTPUT:
    RETVAL

int
instruction_count(compiled)
    SV *compiled
CODE:
{
    if (!SvROK(compiled)) {
        RETVAL = 0;
    } else {
        SV *inner = SvRV(compiled);
        CopsProgram *prog = INT2PTR(CopsProgram*, SvIV(inner));
        RETVAL = prog->len;
    }
}
OUTPUT:
    RETVAL

#
# Direct helper functions - no compile needed
#

bool
is_array(val)
    SV *val
CODE:
    RETVAL = SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV;
OUTPUT:
    RETVAL

bool
is_hash(val)
    SV *val
CODE:
    RETVAL = SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVHV;
OUTPUT:
    RETVAL

bool
is_code(val)
    SV *val
CODE:
    RETVAL = SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVCV;
OUTPUT:
    RETVAL

bool
is_ref(val)
    SV *val
CODE:
    RETVAL = SvROK(val) ? 1 : 0;
OUTPUT:
    RETVAL

bool
is_scalar(val)
    SV *val
CODE:
{
    if (SvROK(val)) {
        SV *rv = SvRV(val);
        svtype t = SvTYPE(rv);
        RETVAL = (t == SVt_NULL || t == SVt_IV || t == SVt_NV || t == SVt_PV || t == SVt_PVIV || t == SVt_PVNV || t == SVt_PVMG);
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
is_regexp(val)
    SV *val
CODE:
    RETVAL = SvROK(val) && SvTYPE(SvRV(val)) == SVt_REGEXP;
OUTPUT:
    RETVAL

bool
is_glob(val)
    SV *val
CODE:
    RETVAL = SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVGV;
OUTPUT:
    RETVAL

bool
is_blessed(val)
    SV *val
CODE:
    RETVAL = SvROK(val) && sv_isobject(val);
OUTPUT:
    RETVAL

bool
is_defined(val)
    SV *val
CODE:
    RETVAL = SvOK(val) ? 1 : 0;
OUTPUT:
    RETVAL

bool
is_undef(val)
    SV *val
CODE:
    RETVAL = SvOK(val) ? 0 : 1;
OUTPUT:
    RETVAL

bool
is_true(val)
    SV *val
CODE:
    RETVAL = SvTRUE(val) ? 1 : 0;
OUTPUT:
    RETVAL

bool
is_false(val)
    SV *val
CODE:
    RETVAL = SvTRUE(val) ? 0 : 1;
OUTPUT:
    RETVAL

bool
looks_like_number(val)
    SV *val
CODE:
    RETVAL = looks_like_number(val) ? 1 : 0;
OUTPUT:
    RETVAL

bool
is_integer(val)
    SV *val
CODE:
{
    if (SvIOK(val) && !SvNOK(val)) {
        RETVAL = 1;
    } else if (looks_like_number(val)) {
        NV nv = SvNV(val);
        RETVAL = (nv == (NV)(IV)nv);
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
is_positive(val)
    SV *val
CODE:
    RETVAL = looks_like_number(val) && SvNV(val) > 0;
OUTPUT:
    RETVAL

bool
is_negative(val)
    SV *val
CODE:
    RETVAL = looks_like_number(val) && SvNV(val) < 0;
OUTPUT:
    RETVAL

bool
is_zero(val)
    SV *val
CODE:
    RETVAL = looks_like_number(val) && SvNV(val) == 0;
OUTPUT:
    RETVAL

bool
is_even(val)
    SV *val
CODE:
{
    if (looks_like_number(val)) {
        IV iv = SvIV(val);
        RETVAL = (iv % 2) == 0;
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
is_odd(val)
    SV *val
CODE:
{
    if (looks_like_number(val)) {
        IV iv = SvIV(val);
        RETVAL = (iv % 2) != 0;
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
is_empty_string(val)
    SV *val
CODE:
{
    if (SvOK(val)) {
        STRLEN len;
        SvPV(val, len);
        RETVAL = len == 0;
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
is_nonempty_string(val)
    SV *val
CODE:
{
    if (SvOK(val)) {
        STRLEN len;
        SvPV(val, len);
        RETVAL = len > 0;
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

IV
array_length(val)
    SV *val
CODE:
{
    if (SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV) {
        RETVAL = av_len((AV*)SvRV(val)) + 1;
    } else {
        RETVAL = -1;
    }
}
OUTPUT:
    RETVAL

IV
hash_size(val)
    SV *val
CODE:
{
    if (SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVHV) {
        RETVAL = HvUSEDKEYS((HV*)SvRV(val));
    } else {
        RETVAL = -1;
    }
}
OUTPUT:
    RETVAL

bool
is_array_empty(val)
    SV *val
CODE:
{
    if (SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVAV) {
        RETVAL = av_len((AV*)SvRV(val)) < 0;
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
is_hash_empty(val)
    SV *val
CODE:
{
    if (SvROK(val) && SvTYPE(SvRV(val)) == SVt_PVHV) {
        RETVAL = HvUSEDKEYS((HV*)SvRV(val)) == 0;
    } else {
        RETVAL = 0;
    }
}
OUTPUT:
    RETVAL

bool
string_contains(haystack, needle)
    SV *haystack
    SV *needle
CODE:
{
    STRLEN hlen, nlen;
    const char *h = SvPV(haystack, hlen);
    const char *n = SvPV(needle, nlen);
    if (nlen == 0) {
        RETVAL = 1;
    } else if (nlen > hlen) {
        RETVAL = 0;
    } else {
        RETVAL = strstr(h, n) != NULL;
    }
}
OUTPUT:
    RETVAL

bool
string_starts_with(str, prefix)
    SV *str
    SV *prefix
CODE:
{
    STRLEN slen, plen;
    const char *s = SvPV(str, slen);
    const char *p = SvPV(prefix, plen);
    if (plen > slen) {
        RETVAL = 0;
    } else {
        RETVAL = memcmp(s, p, plen) == 0;
    }
}
OUTPUT:
    RETVAL

bool
string_ends_with(str, suffix)
    SV *str
    SV *suffix
CODE:
{
    STRLEN slen, xlen;
    const char *s = SvPV(str, slen);
    const char *x = SvPV(suffix, xlen);
    if (xlen > slen) {
        RETVAL = 0;
    } else {
        RETVAL = memcmp(s + slen - xlen, x, xlen) == 0;
    }
}
OUTPUT:
    RETVAL

#if PERL_VERSION_GE(5,14,0)

bool
is_alpha(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isALPHA(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_alnum(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isALNUM(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_digit(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isDIGIT(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_space(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isSPACE(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_word_char(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            char c = *p++;
            if (!isALNUM(c) && c != '_') { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_upper(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isUPPER(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_lower(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 0;
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isLOWER(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_ascii(val)
    SV *val
CODE:
{
    STRLEN len;
    const unsigned char *p = (const unsigned char *)SvPV(val, len);
    if (len == 0) {
        RETVAL = 1;  /* Empty string is ASCII */
    } else {
        RETVAL = 1;
        while (len--) {
            if (*p++ > 127) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

bool
is_printable(val)
    SV *val
CODE:
{
    STRLEN len;
    const char *p = SvPV(val, len);
    if (len == 0) {
        RETVAL = 1;  /* Empty string is printable */
    } else {
        RETVAL = 1;
        while (len--) {
            if (!isPRINT(*p++)) { RETVAL = 0; break; }
        }
    }
}
OUTPUT:
    RETVAL

#endif

SV *
typeof(val)
    SV *val
CODE:
{
    if (!SvOK(val)) {
        RETVAL = newSVpvs("UNDEF");
    } else if (SvROK(val)) {
        SV *rv = SvRV(val);
        svtype t = SvTYPE(rv);
        if (sv_isobject(val)) {
            RETVAL = newSVpvs("OBJECT");
        } else if (t == SVt_PVAV) {
            RETVAL = newSVpvs("ARRAY");
        } else if (t == SVt_PVHV) {
            RETVAL = newSVpvs("HASH");
        } else if (t == SVt_PVCV) {
            RETVAL = newSVpvs("CODE");
        } else if (t == SVt_REGEXP) {
            RETVAL = newSVpvs("REGEXP");
        } else if (t == SVt_PVGV) {
            RETVAL = newSVpvs("GLOB");
        } else {
            RETVAL = newSVpvs("SCALAR");
        }
    } else if (SvIOK(val) && !SvNOK(val) && !SvPOK(val)) {
        RETVAL = newSVpvs("INTEGER");
    } else if (SvNOK(val)) {
        RETVAL = newSVpvs("NUMBER");
    } else if (SvPOK(val)) {
        RETVAL = newSVpvs("STRING");
    } else {
        RETVAL = newSVpvs("UNKNOWN");
    }
}
OUTPUT:
    RETVAL

SV *
reftype(val)
    SV *val
CODE:
{
    if (!SvROK(val)) {
        RETVAL = &PL_sv_undef;
    } else {
        SV *rv = SvRV(val);
        svtype t = SvTYPE(rv);
        if (t == SVt_PVAV) {
            RETVAL = newSVpvs("ARRAY");
        } else if (t == SVt_PVHV) {
            RETVAL = newSVpvs("HASH");
        } else if (t == SVt_PVCV) {
            RETVAL = newSVpvs("CODE");
        } else if (t == SVt_REGEXP) {
            RETVAL = newSVpvs("Regexp");
        } else if (t == SVt_PVGV) {
            RETVAL = newSVpvs("GLOB");
        } else {
            RETVAL = newSVpvs("SCALAR");
        }
    }
}
OUTPUT:
    RETVAL

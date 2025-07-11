/*    sv.h
 *
 *    Copyright (C) 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000,
 *    2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#ifdef sv_flags
#undef sv_flags		/* Convex has this in <signal.h> for sigvec() */
#endif

/*
=for apidoc_section $SV_flags

=for apidoc Ay||svtype
An enum of flags for Perl types.  These are found in the file F<sv.h>
in the C<svtype> enum.  Test these flags with the C<SvTYPE> macro.

The types are:

    SVt_NULL
    SVt_IV
    SVt_NV
    SVt_RV
    SVt_PV
    SVt_PVIV
    SVt_PVNV
    SVt_PVMG
    SVt_INVLIST
    SVt_REGEXP
    SVt_PVGV
    SVt_PVLV
    SVt_PVAV
    SVt_PVHV
    SVt_PVCV
    SVt_PVFM
    SVt_PVIO
    SVt_PVOBJ

These are most easily explained from the bottom up.

C<SVt_PVOBJ> is for object instances of the new `use feature 'class'` kind.
C<SVt_PVIO> is for I/O objects, C<SVt_PVFM> for formats, C<SVt_PVCV> for
subroutines, C<SVt_PVHV> for hashes and C<SVt_PVAV> for arrays.

All the others are scalar types, that is, things that can be bound to a
C<$> variable.  For these, the internal types are mostly orthogonal to
types in the Perl language.

Hence, checking C<< SvTYPE(sv) < SVt_PVAV >> is the best way to see whether
something is a scalar.

C<SVt_PVGV> represents a typeglob.  If C<!SvFAKE(sv)>, then it is a real,
incoercible typeglob.  If C<SvFAKE(sv)>, then it is a scalar to which a
typeglob has been assigned.  Assigning to it again will stop it from being
a typeglob.  C<SVt_PVLV> represents a scalar that delegates to another scalar
behind the scenes.  It is used, e.g., for the return value of C<substr> and
for tied hash and array elements.  It can hold any scalar value, including
a typeglob.  C<SVt_REGEXP> is for regular
expressions.  C<SVt_INVLIST> is for Perl
core internal use only.

C<SVt_PVMG> represents a "normal" scalar (not a typeglob, regular expression,
or delegate).  Since most scalars do not need all the internal fields of a
PVMG, we save memory by allocating smaller structs when possible.  All the
other types are just simpler forms of C<SVt_PVMG>, with fewer internal fields.
C<SVt_NULL> can only hold undef.  C<SVt_IV> can hold undef, an integer, or a
reference.  (C<SVt_RV> is an alias for C<SVt_IV>, which exists for backward
compatibility.)  C<SVt_NV> can hold undef or a double. (In builds that support
headless NVs, these could also hold a reference via a suitable offset, in the
same way that SVt_IV does, but this is not currently supported and seems to
be a rare use case.) C<SVt_PV> can hold C<undef>, a string, or a reference.
C<SVt_PVIV> is a superset of C<SVt_PV> and C<SVt_IV>. C<SVt_PVNV> is a
superset of C<SVt_PV> and C<SVt_NV>. C<SVt_PVMG> can hold anything C<SVt_PVNV>
can hold, but it may also be blessed or magical.

=for apidoc AmnU||SVt_NULL
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_IV
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_NV
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_PV
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_PVIV
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_PVNV
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_PVMG
Type flag for scalars.  See L</svtype>.

=for apidoc CmnU||SVt_INVLIST
Type flag for scalars.  See L<perlapi/svtype>.

=for apidoc AmnU||SVt_REGEXP
Type flag for regular expressions.  See L</svtype>.

=for apidoc AmnU||SVt_PVGV
Type flag for typeglobs.  See L</svtype>.

=for apidoc AmnU||SVt_PVLV
Type flag for scalars.  See L</svtype>.

=for apidoc AmnU||SVt_PVAV
Type flag for arrays.  See L</svtype>.

=for apidoc AmnU||SVt_PVHV
Type flag for hashes.  See L</svtype>.

=for apidoc AmnU||SVt_PVCV
Type flag for subroutines.  See L</svtype>.

=for apidoc AmnU||SVt_PVFM
Type flag for formats.  See L</svtype>.

=for apidoc AmnU||SVt_PVIO
Type flag for I/O objects.  See L</svtype>.

=for apidoc AmnUx||SVt_PVOBJ
Type flag for object instances.  See L</svtype>.

=cut

  These are ordered so that the simpler types have a lower value; SvUPGRADE
  doesn't allow you to upgrade from a higher numbered type to a lower numbered
  one; also there is code that assumes that anything that has as a PV component
  has a type numbered >= SVt_PV.
*/


typedef enum {
        SVt_NULL,	/* 0 */
        /* BIND was here, before INVLIST replaced it.  */
        SVt_IV,		/* 1 */
        SVt_NV,		/* 2 */
        /* RV was here, before it was merged with IV.  */
        SVt_PV,		/* 3 */
        SVt_INVLIST,	/* 4, implemented as a PV */
        SVt_PVIV,	/* 5 */
        SVt_PVNV,	/* 6 */
        SVt_PVMG,	/* 7 */
        SVt_REGEXP,	/* 8 */
        /* PVBM was here, before BIND replaced it.  */
        SVt_PVGV,	/* 9 */
        SVt_PVLV,	/* 10 */
        SVt_PVAV,	/* 11 */
        SVt_PVHV,	/* 12 */
        SVt_PVCV,	/* 13 */
        SVt_PVFM,	/* 14 */
        SVt_PVIO,	/* 15 */
        SVt_PVOBJ,      /* 16 */
                        /* 17-31: Unused, though one should be reserved for a
                         * freed sv, if the other 3 bits below the flags ones
                         * get allocated */
        SVt_LAST	/* keep last in enum. used to size arrays */
} svtype;

/* *** any alterations to the SV types above need to be reflected in
 * SVt_MASK and the various PL_valid_types_* tables.  As of this writing those
 * tables are in perl.h.  There are also two affected names tables in dump.c,
 * one in B.xs, and 'bodies_by_type[]' in sv_inline.h.
 *
 * The bits that match 0xe0 are CURRENTLY UNUSED
 * The bits above that are for flags, like SVf_IOK */

#define SVt_MASK 0x1f	/* smallest bitmask that covers all types */

#ifndef PERL_CORE
/* Fast Boyer Moore tables are now stored in magic attached to PVMGs */
#  define SVt_PVBM	SVt_PVMG
/* Anything wanting to create a reference from clean should ensure that it has
   a scalar of type SVt_IV now:  */
#  define SVt_RV	SVt_IV
#endif

/* The array of arena roots for SV bodies is indexed by SvTYPE. SVt_NULL doesn't
 * use a body, so that arena root is re-used for HEs. SVt_IV also doesn't, so
 * that arena root is used for HVs with struct xpvhv_aux. */

#if defined(PERL_IN_HV_C) || defined(PERL_IN_XS_APITEST)
#  define HE_ARENA_ROOT_IX      SVt_NULL
#endif
#if defined(PERL_IN_HV_C) || defined(PERL_IN_SV_C)
#  define HVAUX_ARENA_ROOT_IX   SVt_IV
#endif
#ifdef PERL_IN_SV_C
#  define SVt_FIRST SVt_NULL	/* the type of SV that new_SV() in sv_inline.h returns */
#endif

#define PERL_ARENA_ROOTS_SIZE	(SVt_LAST)

/* typedefs to eliminate some typing */
typedef struct he HE;
typedef struct hek HEK;

/* Using C's structural equivalence to help emulate C++ inheritance here... */

/* start with 2 sv-head building blocks */
#define _SV_HEAD(ptrtype) \
    ptrtype	sv_any;		/* pointer to body */	\
    U32		sv_refcnt;	/* how many references to us */	\
    U32		sv_flags	/* what we are */

#if NVSIZE <= IVSIZE
#  define _NV_BODYLESS_UNION NV svu_nv;
#else
#  define _NV_BODYLESS_UNION
#endif

#define _SV_HEAD_UNION \
    union {				\
        char*   svu_pv;		/* pointer to malloced string */	\
        IV      svu_iv;			\
        UV      svu_uv;			\
        _NV_BODYLESS_UNION		\
        SV*     svu_rv;		/* pointer to another SV */		\
        SV**    svu_array;		\
        HE**	svu_hash;		\
        GP*	svu_gp;			\
        PerlIO *svu_fp;			\
    }	sv_u				\
    _SV_HEAD_DEBUG

#ifdef DEBUG_LEAKING_SCALARS
#define _SV_HEAD_DEBUG ;\
    PERL_BITFIELD32 sv_debug_optype:9;	/* the type of OP that allocated us */ \
    PERL_BITFIELD32 sv_debug_inpad:1;	/* was allocated in a pad for an OP */ \
    PERL_BITFIELD32 sv_debug_line:16;	/* the line where we were allocated */ \
    UV		    sv_debug_serial;	/* serial number of sv allocation   */ \
    char *	    sv_debug_file;	/* the file where we were allocated */ \
    SV *	    sv_debug_parent	/* what we were cloned from (ithreads)*/
#else
#define _SV_HEAD_DEBUG
#endif

struct STRUCT_SV {		/* struct sv { */
    _SV_HEAD(void*);
    _SV_HEAD_UNION;
};

struct gv {
    _SV_HEAD(XPVGV*);		/* pointer to xpvgv body */
    _SV_HEAD_UNION;
};

struct cv {
    _SV_HEAD(XPVCV*);		/* pointer to xpvcv body */
    _SV_HEAD_UNION;
};

struct av {
    _SV_HEAD(XPVAV*);		/* pointer to xpvav body */
    _SV_HEAD_UNION;
};

struct hv {
    _SV_HEAD(XPVHV*);		/* pointer to xpvhv body */
    _SV_HEAD_UNION;
};

struct io {
    _SV_HEAD(XPVIO*);		/* pointer to xpvio body */
    _SV_HEAD_UNION;
};

struct p5rx {
    _SV_HEAD(struct regexp*);	/* pointer to regexp body */
    _SV_HEAD_UNION;
};

struct invlist {
    _SV_HEAD(XINVLIST*);       /* pointer to xpvinvlist body */
    _SV_HEAD_UNION;
};

struct object {
    _SV_HEAD(XPVOBJ*);          /* pointer to xobject body */
    _SV_HEAD_UNION;
};

#undef _SV_HEAD
#undef _SV_HEAD_UNION		/* ensure no pollution */

/*
=for apidoc_section $SV

=for apidoc Am|U32|SvREFCNT|SV* sv
Returns the value of the object's reference count. Exposed
to perl code via Internals::SvREFCNT().

=for apidoc      SvREFCNT_inc
=for apidoc_item SvREFCNT_inc_NN
=for apidoc_item SvREFCNT_inc_simple
=for apidoc_item SvREFCNT_inc_simple_NN
=for apidoc_item SvREFCNT_inc_simple_void
=for apidoc_item SvREFCNT_inc_simple_void_NN
=for apidoc_item SvREFCNT_inc_void
=for apidoc_item SvREFCNT_inc_void_NN

These all increment the reference count of the given SV.
The ones without C<void> in their names return the SV.

C<SvREFCNT_inc> is the base operation; the rest are optimizations if various
input constraints are known to be true; hence, all can be replaced with
C<SvREFCNT_inc>.

C<SvREFCNT_inc_NN> can only be used if you know C<sv> is not C<NULL>.  Since we
don't have to check the NULLness, it's faster and smaller.

C<SvREFCNT_inc_void> can only be used if you don't need the
return value.  The macro doesn't need to return a meaningful value.

C<SvREFCNT_inc_void_NN> can only be used if you both don't need the return
value, and you know that C<sv> is not C<NULL>.  The macro doesn't need to
return a meaningful value, or check for NULLness, so it's smaller and faster.

C<SvREFCNT_inc_simple> can only be used with expressions without side
effects.  Since we don't have to store a temporary value, it's faster.

C<SvREFCNT_inc_simple_NN> can only be used with expressions without side
effects and you know C<sv> is not C<NULL>.  Since we don't have to store a
temporary value, nor check for NULLness, it's faster and smaller.

C<SvREFCNT_inc_simple_void> can only be used with expressions without side
effects and you don't need the return value.

C<SvREFCNT_inc_simple_void_NN> can only be used with expressions without side
effects, you don't need the return value, and you know C<sv> is not C<NULL>.

=for apidoc      SvREFCNT_dec
=for apidoc_item SvREFCNT_dec_set_NULL
=for apidoc_item SvREFCNT_dec_ret_NULL
=for apidoc_item SvREFCNT_dec_NN

These decrement the reference count of the given SV.

C<SvREFCNT_dec_NN> may only be used when C<sv> is known to not be C<NULL>.

The function C<SvREFCNT_dec_ret_NULL()> is identical to the
C<SvREFCNT_dec()> except it returns a NULL C<SV *>.  It is used by
C<SvREFCNT_dec_set_NULL()> which is a macro which will, when passed a
non-NULL argument, decrement the reference count of its argument and
then set it to NULL. You can replace code of the following form:

    if (sv) {
       SvREFCNT_dec_NN(sv);
       sv = NULL;
    }

with

    SvREFCNT_dec_set_NULL(sv);

=for apidoc Am|svtype|SvTYPE|SV* sv
Returns the type of the SV.  See C<L</svtype>>.

=for apidoc Am|void|SvUPGRADE|SV* sv|svtype type
Used to upgrade an SV to a more complex form.  Uses C<sv_upgrade> to
perform the upgrade if necessary.  See C<L</svtype>>.

=cut
*/

#define SvANY(sv)	(sv)->sv_any
#define SvFLAGS(sv)	(sv)->sv_flags
#define SvREFCNT(sv)	(sv)->sv_refcnt

/*
=for apidoc_defn Am|SV *|SvREFCNT_inc_simple|SV *sv
=cut
*/
#define SvREFCNT_inc(sv)		Perl_SvREFCNT_inc(MUTABLE_SV(sv))
#define SvREFCNT_inc_simple(sv)		SvREFCNT_inc(sv)
#define SvREFCNT_inc_NN(sv)		Perl_SvREFCNT_inc_NN(MUTABLE_SV(sv))
#define SvREFCNT_inc_void(sv)		Perl_SvREFCNT_inc_void(MUTABLE_SV(sv))

/*
=for apidoc_defn Am|void|SvREFCNT_inc_simple_void|SV *sv

These guys don't need the curly blocks

=cut
*/
#define SvREFCNT_inc_simple_void(sv)	                                \
        STMT_START {                                                    \
            SV * sv_ = MUTABLE_SV(sv);                                  \
            if (sv_)                                                    \
                SvREFCNT(sv_)++;                                        \
        } STMT_END

/*
=for apidoc_defn Am|SV *|SvREFCNT_inc_simple_NN|SV *sv
=for apidoc_defn Am|void|SvREFCNT_inc_void_NN|SV *sv
=for apidoc_defn Am|void|SvREFCNT_inc_simple_void_NN|SV *sv
=cut
*/
#define SvREFCNT_inc_simple_NN(sv)	(++(SvREFCNT(sv)),MUTABLE_SV(sv))
#define SvREFCNT_inc_void_NN(sv)	(void)(++SvREFCNT(MUTABLE_SV(sv)))
#define SvREFCNT_inc_simple_void_NN(sv)	(void)(++SvREFCNT(MUTABLE_SV(sv)))

#define SvREFCNT_dec(sv)	Perl_SvREFCNT_dec(aTHX_ MUTABLE_SV(sv))
#define SvREFCNT_dec_set_NULL(sv)                               \
    STMT_START {                                                \
        sv = Perl_SvREFCNT_dec_ret_NULL(aTHX_ MUTABLE_SV(sv));  \
    } STMT_END
#define SvREFCNT_dec_NN(sv)	Perl_SvREFCNT_dec_NN(aTHX_ MUTABLE_SV(sv))

#define SVTYPEMASK	0xff
#define SvTYPE(sv)	((svtype)((sv)->sv_flags & SVTYPEMASK))

/* Sadly there are some parts of the core that have pointers to already-freed
   SV heads, and rely on being able to tell that they are now free. So mark
   them all by using a consistent macro.  */
#define SvIS_FREED(sv)	UNLIKELY(((sv)->sv_flags == SVTYPEMASK))

/* this is defined in this peculiar way to avoid compiler warnings.
 * See the <20121213131428.GD1842@iabyn.com> thread in p5p */
#define SvUPGRADE(sv, mt) \
    ((void)(SvTYPE(sv) >= (mt) || (sv_upgrade(sv, mt),1)))

#define SVf_IOK		0x00000100  /* has valid public integer value */
#define SVf_NOK		0x00000200  /* has valid public numeric value */
#define SVf_POK		0x00000400  /* has valid public pointer value */
#define SVf_ROK		0x00000800  /* has a valid reference pointer */

#define SVp_IOK		0x00001000  /* has valid non-public integer value */
#define SVp_NOK		0x00002000  /* has valid non-public numeric value */
#define SVp_POK		0x00004000  /* has valid non-public pointer value */
#define SVp_SCREAM	0x00008000  /* currently unused on plain scalars */
#define SVphv_CLONEABLE	SVp_SCREAM  /* PVHV (stashes) clone its objects */
#define SVpgv_GP	SVp_SCREAM  /* GV has a valid GP */
#define SVprv_PCS_IMPORTED  SVp_SCREAM  /* RV is a proxy for a constant
                                       subroutine in another package. Set the
                                       GvIMPORTED_CV_on() if it needs to be
                                       expanded to a real GV */

/* SVf_PROTECT is what SVf_READONLY should have been: i.e. modifying
 * this SV is completely illegal. However, SVf_READONLY (via
 * Internals::SvREADONLY()) has come to be seen as a flag that can be
 * temporarily set and unset by the user to indicate e.g. whether a hash
 * is "locked". Now, Hash::Util et al only set SVf_READONLY, while core
 * sets both (SVf_READONLY|SVf_PROTECT) to indicate both to core and user
 * code that this SV should not be messed with.
 */
#define SVf_PROTECT	0x00010000  /* very read-only */
#define SVs_PADTMP	0x00020000  /* in use as tmp */
#define SVs_PADSTALE	0x00040000  /* lexical has gone out of scope;
                                        only used when !PADTMP */
#define SVs_TEMP	0x00080000  /* mortal (implies string is stealable) */
#define SVs_OBJECT	0x00100000  /* is "blessed" */
#define SVs_GMG		0x00200000  /* has magical get method */
#define SVs_SMG		0x00400000  /* has magical set method */
#define SVs_RMG		0x00800000  /* has random magical methods */

#define SVf_FAKE	0x01000000  /* 0: glob is just a copy
                                       1: SV head arena wasn't malloc()ed
                                       2: For PVCV, whether CvUNIQUE(cv)
                                          refers to an eval or once only
                                          [CvEVAL(cv), CvSPECIAL(cv)]
                                       3: HV: informally reserved by DAPM
                                          for vtables
                                       4: Together with other flags (or
                                           lack thereof) indicates a regex,
                                           including PVLV-as-regex. See
                                           isREGEXP().
                                       */
#define SVf_OOK		0x02000000  /* has valid offset value */
#define SVphv_HasAUX    SVf_OOK     /* PVHV has an additional hv_aux struct */
#define SVf_BREAK	0x04000000  /* refcnt is artificially low - used by
                                       SVs in final arena cleanup.
                                       Set in S_regtry on PL_reg_curpm, so that
                                       perl_destruct will skip it.
                                       Used for mark and sweep by OP_AASSIGN
                                       */
#define SVf_READONLY	0x08000000  /* may not be modified */




#define SVf_THINKFIRST	(SVf_READONLY|SVf_PROTECT|SVf_ROK|SVf_FAKE \
                        |SVs_RMG|SVf_IsCOW)

#define SVf_OK		(SVf_IOK|SVf_NOK|SVf_POK|SVf_ROK| \
                         SVp_IOK|SVp_NOK|SVp_POK|SVpgv_GP)

#define PRIVSHIFT 4	/* (SVp_?OK >> PRIVSHIFT) == SVf_?OK */

/* SVf_AMAGIC means that the stash *may* have overload methods. It's
 * set each time a function is compiled into a stash, and is reset by the
 * overload code when called for the first time and finds that there are
 * no overload methods. Note that this used to be set on the object; but
 * is now only set on stashes.
 */
#define SVf_AMAGIC	0x10000000  /* has magical overloaded methods */
#define SVf_IsCOW	0x10000000  /* copy on write (shared hash key if
                                       SvLEN == 0) */

/* Ensure this value does not clash with the GV_ADD* flags in gv.h, or the
   CV_CKPROTO_* flags in op.c, or the padadd_* flags in pad.h: */
#define SVf_UTF8        0x20000000  /* SvPV is UTF-8 encoded
                                       This is also set on RVs whose overloaded
                                       stringification is UTF-8. This might
                                       only happen as a side effect of SvPV() */
/* PVHV */
#define SVphv_SHAREKEYS 0x20000000  /* PVHV keys live on shared string table */

/* PVAV could probably use 0x2000000 without conflict. I assume that PVFM can
   be UTF-8 encoded, and PVCVs could well have UTF-8 prototypes. PVIOs haven't
   been restructured, so sometimes get used as string buffers.  */


/* Some private flags. */


/* scalar SVs with SVp_POK */
#define SVppv_STATIC    0x40000000 /* PV is pointer to static const; must be set with SVf_IsCOW */
/* PVAV */
#define SVpav_REAL	0x40000000  /* free old entries */
/* PVHV */
#define SVphv_LAZYDEL	0x40000000  /* entry in xhv_eiter must be deleted */

/* IV, PVIV, PVNV, PVMG, PVGV and (I assume) PVLV  */
#define SVf_IVisUV	0x80000000  /* use XPVUV instead of XPVIV */
/* PVAV */
#define SVpav_REIFY 	0x80000000  /* can become real */
/* PVHV */
#define SVphv_HASKFLAGS	0x80000000  /* keys have flag byte after hash */
/* RV upwards. However, SVf_ROK and SVp_IOK are exclusive  */
#define SVprv_WEAKREF   0x80000000  /* Weak reference */
/* pad name vars only */

#define _XPV_HEAD							\
    HV*		xmg_stash;	/* class package */			\
    union _xmgu	xmg_u;							\
    STRLEN	xpv_cur;	/* length of svu_pv as a C string */    \
    union {								\
        STRLEN	xpvlenu_len; 	/* allocated size */			\
        struct regexp* xpvlenu_rx; /* regex when SV body is XPVLV */    \
    } xpv_len_u

#define xpv_len	xpv_len_u.xpvlenu_len

union _xnvu {
    NV	    xnv_nv;		/* numeric value, if any */
    HV *    xgv_stash;
    line_t  xnv_lines;           /* used internally by S_scan_subst() */
    bool    xnv_bm_tail;        /* an SvVALID (BM) SV has an implicit "\n" */
};

union _xivu {
    IV	    xivu_iv;		/* integer value */
    UV	    xivu_uv;
    HEK *   xivu_namehek;	/* xpvlv, xpvgv: GvNAME */
    bool    xivu_eval_seen;     /* used internally by S_scan_subst() */

};

union _xmgu {
    MAGIC*  xmg_magic;		/* linked list of magicalness */
    STRLEN  xmg_hash_index;	/* used while freeing hash entries */
};

struct xpv {
    _XPV_HEAD;
};

struct xpviv {
    _XPV_HEAD;
    union _xivu xiv_u;
};

#define xiv_iv xiv_u.xivu_iv

struct xpvuv {
    _XPV_HEAD;
    union _xivu xuv_u;
};

#define xuv_uv xuv_u.xivu_uv

struct xpvnv {
    _XPV_HEAD;
    union _xivu xiv_u;
    union _xnvu xnv_u;
};

/* This structure must match the beginning of struct xpvhv in hv.h. */
struct xpvmg {
    _XPV_HEAD;
    union _xivu xiv_u;
    union _xnvu xnv_u;
};

struct xpvlv {
    _XPV_HEAD;
    union _xivu xiv_u;
    union _xnvu xnv_u;
    union {
        STRLEN	xlvu_targoff;
        SSize_t xlvu_stargoff;
    } xlv_targoff_u;
    STRLEN	xlv_targlen;
    SV*		xlv_targ;
    char	xlv_type;	/* k=keys .=pos x=substr v=vec /=join/re
                                 * y=alem/helem/iter t=tie T=tied HE */
    char	xlv_flags;	/* 1 = negative offset  2 = negative len
                                   4 = out of range (vec) */
};

#define xlv_targoff xlv_targoff_u.xlvu_targoff

struct xpvinvlist {
    _XPV_HEAD;
    IV          prev_index;     /* caches result of previous invlist_search() */
    STRLEN	iterator;       /* Stores where we are in iterating */
    bool	is_offset;	/* The data structure for all inversion lists
                                   begins with an element for code point U+0000.
                                   If this bool is set, the actual list contains
                                   that 0; otherwise, the list actually begins
                                   with the following element.  Thus to invert
                                   the list, merely toggle this flag  */
};

/* This structure works in 2 ways - regular scalar, or GV with GP */

struct xpvgv {
    _XPV_HEAD;
    union _xivu xiv_u;
    union _xnvu xnv_u;
};

typedef U32 cv_flags_t;

#define _XPVCV_COMMON								\
    HV *	xcv_stash;							\
    union {									\
        OP *	xcv_start;							\
        ANY	xcv_xsubany;							\
    }		xcv_start_u;					    		\
    union {									\
        OP *	xcv_root;							\
        void	(*xcv_xsub) (pTHX_ CV*);					\
    }		xcv_root_u;							\
    union {								\
        GV *	xcv_gv;							\
        HEK *	xcv_hek;						\
    }		xcv_gv_u;						\
    char *	xcv_file;							\
    union {									\
        PADLIST *	xcv_padlist;						\
        void *		xcv_hscxt;						\
    }		xcv_padlist_u;							\
    CV *	xcv_outside;							\
    U32		xcv_outside_seq; /* the COP sequence (at the point of our	\
                                  * compilation) in the lexically enclosing	\
                                  * sub */					\
    cv_flags_t	xcv_flags;						\
    I32	xcv_depth	/* >= 2 indicates recursive call */

/* This structure must match XPVCV in cv.h */

struct xpvfm {
    _XPV_HEAD;
    _XPVCV_COMMON;
};


struct xpvio {
    _XPV_HEAD;
    union _xivu xiv_u;
    /* ifp and ofp are normally the same, but sockets need separate streams */
    PerlIO *	xio_ofp;
    /* Cray addresses everything by word boundaries (64 bits) and
     * code and data pointers cannot be mixed (which is exactly what
     * Perl_filter_add() tries to do with the dirp), hence the
     *  following union trick (as suggested by Gurusamy Sarathy).
     * For further information see Geir Johansen's problem report
     * titled [ID 20000612.002 (#3366)] Perl problem on Cray system
     * The any pointer (known as IoANY()) will also be a good place
     * to hang any IO disciplines to.
     */
    union {
        DIR *	xiou_dirp;	/* for opendir, readdir, etc */
        void *	xiou_any;	/* for alignment */
    } xio_dirpu;
    /* IV xio_lines is now in IVX  $. */
    IV		xio_page;	/* $% */
    IV		xio_page_len;	/* $= */
    IV		xio_lines_left;	/* $- */
    char *	xio_top_name;	/* $^ */
    GV *	xio_top_gv;	/* $^ */
    char *	xio_fmt_name;	/* $~ */
    GV *	xio_fmt_gv;	/* $~ */
    char *	xio_bottom_name;/* $^B */
    GV *	xio_bottom_gv;	/* $^B */
    char	xio_type;
    U8		xio_flags;
};

#define xio_dirp	xio_dirpu.xiou_dirp
#define xio_any		xio_dirpu.xiou_any

#define IOf_ARGV	1	/* this fp iterates over ARGV */
#define IOf_START	2	/* check for null ARGV and substitute '-' */
#define IOf_FLUSH	4	/* this fp wants a flush after write op */
#define IOf_DIDTOP	8	/* just did top of form */
#define IOf_UNTAINT	16	/* consider this fp (and its data) "safe" */
#define IOf_NOLINE	32	/* slurped a pseudo-line from empty file */
#define IOf_FAKE_DIRP	64	/* xio_dirp is fake (source filters kludge)
                                   Also, when this is set, SvPVX() is valid */

struct xobject {
    HV*         xmg_stash;
    union _xmgu xmg_u;
    SSize_t     xobject_maxfield;
    SSize_t     xobject_iter_sv_at; /* this is only used by Perl_sv_clear() */
    SV**        xobject_fields;
};

#define ObjectMAXFIELD(inst)  ((XPVOBJ *)SvANY(inst))->xobject_maxfield
#define ObjectITERSVAT(inst)  ((XPVOBJ *)SvANY(inst))->xobject_iter_sv_at
#define ObjectFIELDS(inst)    ((XPVOBJ *)SvANY(inst))->xobject_fields

/* The following macros define implementation-independent predicates on SVs. */

/*
=for apidoc Am|U32|SvNIOK|SV* sv
Returns a U32 value indicating whether the SV contains a number, integer or
double.

=for apidoc Am|U32|SvNIOKp|SV* sv
Returns a U32 value indicating whether the SV contains a number, integer or
double.  Checks the B<private> setting.  Use C<SvNIOK> instead.

=for apidoc Am|void|SvNIOK_off|SV* sv
Unsets the NV/IV status of an SV.

=for apidoc Am|U32|SvOK|SV* sv
Returns a U32 value indicating whether the value is defined.  This is
only meaningful for scalars.

=for apidoc Am|U32|SvIOKp|SV* sv
Returns a U32 value indicating whether the SV contains an integer.  Checks
the B<private> setting.  Use C<SvIOK> instead.

=for apidoc Am|U32|SvNOKp|SV* sv
Returns a U32 value indicating whether the SV contains a double.  Checks the
B<private> setting.  Use C<SvNOK> instead.

=for apidoc Am|U32|SvPOKp|SV* sv
Returns a U32 value indicating whether the SV contains a character string.
Checks the B<private> setting.  Use C<SvPOK> instead.

=for apidoc Am|U32|SvIOK|SV* sv
Returns a U32 value indicating whether the SV contains an integer.

=for apidoc Am|void|SvIOK_on|SV* sv
Tells an SV that it is an integer.

=for apidoc Am|void|SvIOK_off|SV* sv
Unsets the IV status of an SV.

=for apidoc Am|void|SvIOK_only|SV* sv
Tells an SV that it is an integer and disables all other C<OK> bits.

=for apidoc Am|void|SvIOK_only_UV|SV* sv
Tells an SV that it is an unsigned integer and disables all other C<OK> bits.

=for apidoc Am|bool|SvIOK_UV|SV* sv
Returns a boolean indicating whether the SV contains an integer that must be
interpreted as unsigned.  A non-negative integer whose value is within the
range of both an IV and a UV may be flagged as either C<SvUOK> or C<SvIOK>.

=for apidoc Am|bool|SvUOK|SV* sv
Returns a boolean indicating whether the SV contains an integer that must be
interpreted as unsigned.  A non-negative integer whose value is within the
range of both an IV and a UV may be flagged as either C<SvUOK> or C<SvIOK>.

=for apidoc Am|bool|SvIOK_notUV|SV* sv
Returns a boolean indicating whether the SV contains a signed integer.

=for apidoc Am|U32|SvNOK|SV* sv
Returns a U32 value indicating whether the SV contains a double.

=for apidoc Am|void|SvNOK_on|SV* sv
Tells an SV that it is a double.

=for apidoc Am|void|SvNOK_off|SV* sv
Unsets the NV status of an SV.

=for apidoc Am|void|SvNOK_only|SV* sv
Tells an SV that it is a double and disables all other OK bits.

=for apidoc Am|U32|SvPOK|SV* sv
Returns a U32 value indicating whether the SV contains a character
string.

=for apidoc Am|void|SvPOK_on|SV* sv
Tells an SV that it is a string.

=for apidoc Am|void|SvPOK_off|SV* sv
Unsets the PV status of an SV.

=for apidoc Am|void|SvPOK_only|SV* sv
Tells an SV that it is a string and disables all other C<OK> bits.
Will also turn off the UTF-8 status.

=for apidoc Am|U32|SvBoolFlagsOK|SV* sv
Returns a bool indicating whether the SV has the right flags set such
that it is safe to call C<BOOL_INTERNALS_sv_isbool()> or
C<BOOL_INTERNALS_sv_isbool_true()> or
C<BOOL_INTERNALS_sv_isbool_false()>. Currently equivalent to
C<SvIandPOK(sv)> or C<SvIOK(sv) && SvPOK(sv)>. Serialization may want to
unroll this check. If so you are strongly recommended to add code like
C<assert(SvBoolFlagsOK(sv));> B<before> calling using any of the
BOOL_INTERNALS macros.

=for apidoc Am|U32|SvIandPOK|SV* sv
Returns a bool indicating whether the SV is both C<SvPOK()> and
C<SvIOK()> at the same time. Equivalent to C<SvIOK(sv) && SvPOK(sv)> but
more efficient.

=for apidoc Am|void|SvIandPOK_on|SV* sv
Tells an SV that is a string and a number in one operation. Equivalent
to C<SvIOK_on(sv); SvPOK_on(sv);> but more efficient.

=for apidoc Am|void|SvIandPOK_off|SV* sv
Unsets the PV and IV status of an SV in one operation. Equivalent to
C<SvIOK_off(sv); SvPK_off(v);> but more efficient.

=for apidoc Am|bool|BOOL_INTERNALS_sv_isbool|SV* sv
Checks if a C<SvBoolFlagsOK()> sv is a bool. B<Note> that it is the
caller's responsibility to ensure that the sv is C<SvBoolFlagsOK()> before
calling this. This is only useful in specialized logic like
serialization code where performance is critical and the flags have
already been checked to be correct. Almost always you should be using
C<sv_isbool(sv)> instead.

=for apidoc Am|bool|BOOL_INTERNALS_sv_isbool_true|SV* sv
Checks if a C<SvBoolFlagsOK()> sv is a true bool. B<Note> that it is
the caller's responsibility to ensure that the sv is C<SvBoolFlagsOK()>
before calling this. This is only useful in specialized logic like
serialization code where performance is critical and the flags have
already been checked to be correct. This is B<NOT> what you should use
to check if an SV is "true", for that you should be using
C<SvTRUE(sv)> instead.

=for apidoc Am|bool|BOOL_INTERNALS_sv_isbool_false|SV* sv
Checks if a C<SvBoolFlagsOK()> sv is a false bool. B<Note> that it is
the caller's responsibility to ensure that the sv is C<SvBoolFlagsOK()>
before calling this. This is only useful in specialized logic like
serialization code where performance is critical and the flags have
already been checked to be correct. This is B<NOT> what you should use
to check if an SV is "false", for that you should be using
C<!SvTRUE(sv)> instead.

=for apidoc Am|bool|SvVOK|SV* sv
Returns a boolean indicating whether the SV contains a v-string.

=for apidoc Am|U32|SvOOK|SV* sv
Returns a U32 indicating whether the pointer to the string buffer is offset.
This hack is used internally to speed up removal of characters from the
beginning of a C<L</SvPV>>.  When C<SvOOK> is true, then the start of the
allocated string buffer is actually C<SvOOK_offset()> bytes before C<SvPVX>.
This offset used to be stored in C<SvIVX>, but is now stored within the spare
part of the buffer.

=for apidoc Am|U32|SvROK|SV* sv
Tests if the SV is an RV.

=for apidoc Am|void|SvROK_on|SV* sv
Tells an SV that it is an RV.

=for apidoc Am|void|SvROK_off|SV* sv
Unsets the RV status of an SV.

=for apidoc Am|SV*|SvRV|SV* sv
Dereferences an RV to return the SV.

=for apidoc Am|IV|SvIVX|SV* sv
Returns the raw value in the SV's IV slot, without checks or conversions.
Only use when you are sure C<SvIOK> is true.  See also C<L</SvIV>>.

=for apidoc Am|UV|SvUVX|SV* sv
Returns the raw value in the SV's UV slot, without checks or conversions.
Only use when you are sure C<SvIOK> is true.  See also C<L</SvUV>>.

=for apidoc AmD|UV|SvUVXx|SV* sv
This is an unnecessary synonym for L</SvUVX>

=for apidoc Am|NV|SvNVX|SV* sv
Returns the raw value in the SV's NV slot, without checks or conversions.
Only use when you are sure C<SvNOK> is true.  See also C<L</SvNV>>.

=for apidoc Am   |char*      |SvPVX|SV* sv
=for apidoc_item |const char*|SvPVX_const|SV* sv
=for apidoc_item |char*      |SvPVX_mutable|SV* sv
=for apidoc_item |char*      |SvPVXx|SV* sv

These return a pointer to the physical string in the SV.  The SV must contain a
string.  Prior to 5.9.3 it is not safe to execute these unless the SV's
type >= C<SVt_PV>.

These are also used to store the name of an autoloaded subroutine in an XS
AUTOLOAD routine.  See L<perlguts/Autoloading with XSUBs>.

C<SvPVXx> is identical to C<SvPVX>.

C<SvPVX_mutable> is merely a synonym for C<SvPVX>, but its name emphasizes that
the string is modifiable by the caller.

C<SvPVX_const> differs in that the return value has been cast so that the
compiler will complain if you were to try to modify the contents of the string,
(unless you cast away const yourself).

=for apidoc Am|STRLEN|SvCUR|SV* sv
Returns the length, in bytes, of the PV inside the SV.
Note that this may not match Perl's C<length>; for that, use
C<sv_len_utf8(sv)>. See C<L</SvLEN>> also.

=for apidoc Am|STRLEN|SvLEN|SV* sv
Returns the size of the string buffer in the SV, not including any part
attributable to C<SvOOK>.  See C<L</SvCUR>>.

=for apidoc Am|char*|SvEND|SV* sv
Returns a pointer to the spot just after the last character in
the string which is in the SV, where there is usually a trailing
C<NUL> character (even though Perl scalars do not strictly require it).
See C<L</SvCUR>>.  Access the character as C<*(SvEND(sv))>.

Warning: If C<SvCUR> is equal to C<SvLEN>, then C<SvEND> points to
unallocated memory.

=for apidoc Am|HV*|SvSTASH|SV* sv
Returns the stash of the SV.

=for apidoc Am|void|SvIV_set|SV* sv|IV val
Set the value of the IV pointer in sv to val.  It is possible to perform
the same function of this macro with an lvalue assignment to C<SvIVX>.
With future Perls, however, it will be more efficient to use
C<SvIV_set> instead of the lvalue assignment to C<SvIVX>.

=for apidoc Am|void|SvNV_set|SV* sv|NV val
Set the value of the NV pointer in C<sv> to val.  See C<L</SvIV_set>>.

=for apidoc Am|void|SvPV_set|SV* sv|char* val
This is probably not what you want to use, you probably wanted
L</sv_usepvn_flags> or L</sv_setpvn> or L</sv_setpvs>.

Set the value of the PV pointer in C<sv> to the Perl allocated
C<NUL>-terminated string C<val>.  See also C<L</SvIV_set>>.

Remember to free the previous PV buffer. There are many things to check.
Beware that the existing pointer may be involved in copy-on-write or other
mischief, so do C<SvOOK_off(sv)> and use C<sv_force_normal> or
C<SvPV_force> (or check the C<SvIsCOW> flag) first to make sure this
modification is safe. Then finally, if it is not a COW, call
C<L</SvPV_free>> to free the previous PV buffer.

=for apidoc Am|void|SvUV_set|SV* sv|UV val
Set the value of the UV pointer in C<sv> to val.  See C<L</SvIV_set>>.

=for apidoc Am|void|SvRV_set|SV* sv|SV* val
Set the value of the RV pointer in C<sv> to val.  See C<L</SvIV_set>>.

=for apidoc Am|void|SvMAGIC_set|SV* sv|MAGIC* val
Set the value of the MAGIC pointer in C<sv> to val.  See C<L</SvIV_set>>.

=for apidoc Am|void|SvSTASH_set|SV* sv|HV* val
Set the value of the STASH pointer in C<sv> to val.  See C<L</SvIV_set>>.

=for apidoc Am|void|SvCUR_set|SV* sv|STRLEN len
Sets the current length, in bytes, of the C string which is in the SV.
See C<L</SvCUR>> and C<SvIV_set>>.

=for apidoc Am|void|SvLEN_set|SV* sv|STRLEN len
Set the size of the string buffer for the SV. See C<L</SvLEN>>.

=cut
*/

#define SvNIOK(sv)		(SvFLAGS(sv) & (SVf_IOK|SVf_NOK))
#define SvNIOKp(sv)		(SvFLAGS(sv) & (SVp_IOK|SVp_NOK))
#define SvNIOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_IOK|SVf_NOK| \
                                                  SVp_IOK|SVp_NOK|SVf_IVisUV))

#define assert_not_ROK(sv)	assert_(!SvROK(sv) || !SvRV(sv))
#define assert_not_glob(sv)	assert_(!isGV_with_GP(sv))

#define SvOK(sv)		(SvFLAGS(sv) & SVf_OK)
#define SvOK_off(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
                                 SvFLAGS(sv) &=	~(SVf_OK|		\
                                                  SVf_IVisUV|SVf_UTF8),	\
                                                        SvOOK_off(sv))
#define SvOK_off_exc_UV(sv)	(assert_not_ROK(sv)			\
                                 SvFLAGS(sv) &=	~(SVf_OK|		\
                                                  SVf_UTF8),		\
                                                        SvOOK_off(sv))

#define SvOKp(sv)		(SvFLAGS(sv) & (SVp_IOK|SVp_NOK|SVp_POK))
#define SvIOKp(sv)		(SvFLAGS(sv) & SVp_IOK)
#define SvIOKp_on(sv)		(assert_not_glob(sv)	\
                                    SvFLAGS(sv) |= SVp_IOK)
#define SvNOKp(sv)		(SvFLAGS(sv) & SVp_NOK)
#define SvNOKp_on(sv)		(assert_not_glob(sv) SvFLAGS(sv) |= SVp_NOK)
#define SvPOKp(sv)		(SvFLAGS(sv) & SVp_POK)
#define SvPOKp_on(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
                                 SvFLAGS(sv) |= SVp_POK)

#define SvIOK(sv)		(SvFLAGS(sv) & SVf_IOK)
#define SvIOK_on(sv)		(assert_not_glob(sv)	\
                                    SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))
#define SvIOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_IOK|SVp_IOK|SVf_IVisUV))
#define SvIOK_only(sv)		(SvOK_off(sv), \
                                    SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))
#define SvIOK_only_UV(sv)	(assert_not_glob(sv) SvOK_off_exc_UV(sv), \
                                    SvFLAGS(sv) |= (SVf_IOK|SVp_IOK))

#define SvIOK_UV(sv)		((SvFLAGS(sv) & (SVf_IOK|SVf_IVisUV))	\
                                 == (SVf_IOK|SVf_IVisUV))
#define SvUOK(sv)		SvIOK_UV(sv)
#define SvIOK_notUV(sv)		((SvFLAGS(sv) & (SVf_IOK|SVf_IVisUV))	\
                                 == SVf_IOK)

#define SvIandPOK(sv)              ((SvFLAGS(sv) & (SVf_IOK|SVf_POK)) == (SVf_IOK|SVf_POK))
#define SvIandPOK_on(sv)           (assert_not_glob(sv) \
                                    (SvFLAGS(sv) |= (SVf_IOK|SVp_IOK|SVf_POK|SVp_POK)))
#define SvIandPOK_off(sv)          (SvFLAGS(sv) &= ~(SVf_IOK|SVp_IOK|SVf_IVisUV|SVf_POK|SVp_POK))

#define SvBoolFlagsOK(sv)           SvIandPOK(sv)

#define BOOL_INTERNALS_sv_isbool(sv)      (SvIsCOW_static(sv) && \
        (SvPVX_const(sv) == PL_Yes || SvPVX_const(sv) == PL_No))
#define BOOL_INTERNALS_sv_isbool_true(sv)      (SvIsCOW_static(sv) && \
        (SvPVX_const(sv) == PL_Yes))
#define BOOL_INTERNALS_sv_isbool_false(sv)      (SvIsCOW_static(sv) && \
        (SvPVX_const(sv) == PL_No))

#define SvIsUV(sv)		(SvFLAGS(sv) & SVf_IVisUV)
#define SvIsUV_on(sv)		(SvFLAGS(sv) |= SVf_IVisUV)
#define SvIsUV_off(sv)		(SvFLAGS(sv) &= ~SVf_IVisUV)

#define SvNOK(sv)		(SvFLAGS(sv) & SVf_NOK)
#define SvNOK_on(sv)		(assert_not_glob(sv) \
                                 SvFLAGS(sv) |= (SVf_NOK|SVp_NOK))
#define SvNOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_NOK|SVp_NOK))
#define SvNOK_only(sv)		(SvOK_off(sv), \
                                    SvFLAGS(sv) |= (SVf_NOK|SVp_NOK))

/*
=for apidoc Am|U32|SvUTF8|SV* sv
Returns a U32 value indicating the UTF-8 status of an SV.  If things are set-up
properly, this indicates whether or not the SV contains UTF-8 encoded data.
You should use this I<after> a call to C<L</SvPV>> or one of its variants, in
case any call to string overloading updates the internal flag.

If you want to take into account the L<bytes> pragma, use C<L</DO_UTF8>>
instead.

=for apidoc Am|void|SvUTF8_on|SV *sv
Turn on the UTF-8 status of an SV (the data is not changed, just the flag).
Do not use frivolously.

=for apidoc Am|void|SvUTF8_off|SV *sv
Unsets the UTF-8 status of an SV (the data is not changed, just the flag).
Do not use frivolously.

=for apidoc Am|void|SvPOK_only_UTF8|SV* sv
Tells an SV that it is a string and disables all other C<OK> bits,
and leaves the UTF-8 status as it was.

=cut
 */

/* Ensure the return value of this macro does not clash with the GV_ADD* flags
in gv.h: */
#define SvUTF8(sv)		(SvFLAGS(sv) & SVf_UTF8)
#define SvUTF8_on(sv)		(SvFLAGS(sv) |= (SVf_UTF8))
#define SvUTF8_off(sv)		(SvFLAGS(sv) &= ~(SVf_UTF8))

#define SvPOK(sv)		(SvFLAGS(sv) & SVf_POK)
#define SvPOK_on(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
                                 SvFLAGS(sv) |= (SVf_POK|SVp_POK))
#define SvPOK_off(sv)		(SvFLAGS(sv) &= ~(SVf_POK|SVp_POK))
#define SvPOK_only(sv)		(assert_not_ROK(sv) assert_not_glob(sv)	\
                                 SvFLAGS(sv) &= ~(SVf_OK|		\
                                                  SVf_IVisUV|SVf_UTF8),	\
                                    SvFLAGS(sv) |= (SVf_POK|SVp_POK))
#define SvPOK_only_UTF8(sv)	(assert_not_ROK(sv) assert_not_glob(sv)	\
                                 SvFLAGS(sv) &= ~(SVf_OK|		\
                                                  SVf_IVisUV),		\
                                    SvFLAGS(sv) |= (SVf_POK|SVp_POK))

#define SvVOK(sv)		(SvMAGICAL(sv)				\
                                 && mg_find(sv,PERL_MAGIC_vstring))
/*
=for apidoc Am|MAGIC*|SvVSTRING_mg|SV * sv

Returns the vstring magic, or NULL if none

=cut
*/
#define SvVSTRING_mg(sv)	(SvMAGICAL(sv) \
                                 ? mg_find(sv,PERL_MAGIC_vstring) : NULL)

#define SvOOK(sv)		(SvFLAGS(sv) & SVf_OOK)
#define SvOOK_on(sv)		(SvFLAGS(sv) |= SVf_OOK)


/*
=for apidoc Am|void|SvOOK_off|SV * sv

Remove any string offset.

=cut
*/

#define SvOOK_off(sv)		((void)(SvOOK(sv) && (sv_backoff(sv),0)))

#define SvFAKE(sv)		(SvFLAGS(sv) & SVf_FAKE)
#define SvFAKE_on(sv)		(SvFLAGS(sv) |= SVf_FAKE)
#define SvFAKE_off(sv)		(SvFLAGS(sv) &= ~SVf_FAKE)

#define SvROK(sv)		(SvFLAGS(sv) & SVf_ROK)
#define SvROK_on(sv)		(SvFLAGS(sv) |= SVf_ROK)
#define SvROK_off(sv)		(SvFLAGS(sv) &= ~(SVf_ROK))

#define SvMAGICAL(sv)		(SvFLAGS(sv) & (SVs_GMG|SVs_SMG|SVs_RMG))
#define SvMAGICAL_on(sv)	(SvFLAGS(sv) |= (SVs_GMG|SVs_SMG|SVs_RMG))
#define SvMAGICAL_off(sv)	(SvFLAGS(sv) &= ~(SVs_GMG|SVs_SMG|SVs_RMG))

#define SvGMAGICAL(sv)		(SvFLAGS(sv) & SVs_GMG)
#define SvGMAGICAL_on(sv)	(SvFLAGS(sv) |= SVs_GMG)
#define SvGMAGICAL_off(sv)	(SvFLAGS(sv) &= ~SVs_GMG)

#define SvSMAGICAL(sv)		(SvFLAGS(sv) & SVs_SMG)
#define SvSMAGICAL_on(sv)	(SvFLAGS(sv) |= SVs_SMG)
#define SvSMAGICAL_off(sv)	(SvFLAGS(sv) &= ~SVs_SMG)

#define SvRMAGICAL(sv)		(SvFLAGS(sv) & SVs_RMG)
#define SvRMAGICAL_on(sv)	(SvFLAGS(sv) |= SVs_RMG)
#define SvRMAGICAL_off(sv)	(SvFLAGS(sv) &= ~SVs_RMG)

/*
=for apidoc Am|bool|SvAMAGIC|SV * sv

Returns a boolean as to whether C<sv> has overloading (active magic) enabled or
not.

=cut
*/

#define SvAMAGIC(sv)		(SvROK(sv) && SvOBJECT(SvRV(sv)) &&	\
                                 HvAMAGIC(SvSTASH(SvRV(sv))))

/* To be used on the stashes themselves: */
#define HvAMAGIC(hv)		(SvFLAGS(hv) & SVf_AMAGIC)
#define HvAMAGIC_on(hv)		(SvFLAGS(hv) |= SVf_AMAGIC)
#define HvAMAGIC_off(hv)	(SvFLAGS(hv) &=~ SVf_AMAGIC)


/* "nog" means "doesn't have get magic" */
#define SvPOK_nog(sv)		((SvFLAGS(sv) & (SVf_POK|SVs_GMG)) == SVf_POK)
#define SvIOK_nog(sv)		((SvFLAGS(sv) & (SVf_IOK|SVs_GMG)) == SVf_IOK)
#define SvUOK_nog(sv)		((SvFLAGS(sv) & (SVf_IOK|SVf_IVisUV|SVs_GMG)) == (SVf_IOK|SVf_IVisUV))
#define SvNOK_nog(sv)		((SvFLAGS(sv) & (SVf_NOK|SVs_GMG)) == SVf_NOK)
#define SvNIOK_nog(sv)		(SvNIOK(sv) && !(SvFLAGS(sv) & SVs_GMG))

#define SvPOK_nogthink(sv)	((SvFLAGS(sv) & (SVf_POK|SVf_THINKFIRST|SVs_GMG)) == SVf_POK)
#define SvIOK_nogthink(sv)	((SvFLAGS(sv) & (SVf_IOK|SVf_THINKFIRST|SVs_GMG)) == SVf_IOK)
#define SvUOK_nogthink(sv)	((SvFLAGS(sv) & (SVf_IOK|SVf_IVisUV|SVf_THINKFIRST|SVs_GMG)) == (SVf_IOK|SVf_IVisUV))
#define SvNOK_nogthink(sv)	((SvFLAGS(sv) & (SVf_NOK|SVf_THINKFIRST|SVs_GMG)) == SVf_NOK)
#define SvNIOK_nogthink(sv)	(SvNIOK(sv) && !(SvFLAGS(sv) & (SVf_THINKFIRST|SVs_GMG)))

#define SvPOK_utf8_nog(sv)	((SvFLAGS(sv) & (SVf_POK|SVf_UTF8|SVs_GMG)) == (SVf_POK|SVf_UTF8))
#define SvPOK_utf8_nogthink(sv)	((SvFLAGS(sv) & (SVf_POK|SVf_UTF8|SVf_THINKFIRST|SVs_GMG)) == (SVf_POK|SVf_UTF8))

#define SvPOK_byte_nog(sv)	((SvFLAGS(sv) & (SVf_POK|SVf_UTF8|SVs_GMG)) == SVf_POK)
#define SvPOK_byte_nogthink(sv)	((SvFLAGS(sv) & (SVf_POK|SVf_UTF8|SVf_THINKFIRST|SVs_GMG)) == SVf_POK)

#define SvPOK_pure_nogthink(sv) \
    ((SvFLAGS(sv) & (SVf_POK|SVf_IOK|SVf_NOK|SVf_ROK|SVpgv_GP|SVf_THINKFIRST|SVs_GMG)) == SVf_POK)
#define SvPOK_utf8_pure_nogthink(sv) \
    ((SvFLAGS(sv) & (SVf_POK|SVf_UTF8|SVf_IOK|SVf_NOK|SVf_ROK|SVpgv_GP|SVf_THINKFIRST|SVs_GMG)) == (SVf_POK|SVf_UTF8))
#define SvPOK_byte_pure_nogthink(sv) \
    ((SvFLAGS(sv) & (SVf_POK|SVf_UTF8|SVf_IOK|SVf_NOK|SVf_ROK|SVpgv_GP|SVf_THINKFIRST|SVs_GMG)) == SVf_POK)

/*
=for apidoc Am|bool|SvIsBOOL|SV* sv

Returns true if the SV is one of the special boolean constants (PL_sv_yes or
PL_sv_no), or is a regular SV whose last assignment stored a copy of one.

=cut
*/

#define SvIsBOOL(sv)            Perl_sv_isbool(aTHX_ sv)

/*
=for apidoc Am|U32|SvGAMAGIC|SV* sv

Returns true if the SV has get magic or
overloading.  If either is true then
the scalar is active data, and has the potential to return a new value every
time it is accessed.  Hence you must be careful to
only read it once per user logical operation and work
with that returned value.  If neither is true then
the scalar's value cannot change unless written to.

=cut
*/

#define SvGAMAGIC(sv)           (SvGMAGICAL(sv) || SvAMAGIC(sv))

#define Gv_AMG(stash) \
        (HvNAME(stash) && Gv_AMupdate(stash,FALSE) \
            ? 1					    \
            : (HvAMAGIC_off(stash), 0))

#define SvWEAKREF(sv)		((SvFLAGS(sv) & (SVf_ROK|SVprv_WEAKREF)) \
                                  == (SVf_ROK|SVprv_WEAKREF))
#define SvWEAKREF_on(sv)	(SvFLAGS(sv) |=  (SVf_ROK|SVprv_WEAKREF))
#define SvWEAKREF_off(sv)	(SvFLAGS(sv) &= ~(SVf_ROK|SVprv_WEAKREF))

#define SvPCS_IMPORTED(sv)	((SvFLAGS(sv) & (SVf_ROK|SVprv_PCS_IMPORTED)) \
                                 == (SVf_ROK|SVprv_PCS_IMPORTED))
#define SvPCS_IMPORTED_on(sv)	(SvFLAGS(sv) |=  (SVf_ROK|SVprv_PCS_IMPORTED))
#define SvPCS_IMPORTED_off(sv)	(SvFLAGS(sv) &= ~(SVf_ROK|SVprv_PCS_IMPORTED))

/*
=for apidoc m|U32|SvTHINKFIRST|SV *sv

A quick flag check to see whether an C<sv> should be passed to C<sv_force_normal>
to be "downgraded" before C<SvIVX> or C<SvPVX> can be modified directly.

For example, if your scalar is a reference and you want to modify the C<SvIVX>
slot, you can't just do C<SvROK_off>, as that will leak the referent.

This is used internally by various sv-modifying functions, such as
C<sv_setsv>, C<sv_setiv> and C<sv_pvn_force>.

One case that this does not handle is a gv without SvFAKE set.  After

    if (SvTHINKFIRST(gv)) sv_force_normal(gv);

it will still be a gv.

C<SvTHINKFIRST> sometimes produces false positives.  In those cases
C<sv_force_normal> does nothing.

=cut
*/

#define SvTHINKFIRST(sv)	(SvFLAGS(sv) & SVf_THINKFIRST)

#define SVs_PADMY		0
#define SvPADMY(sv)		(!(SvFLAGS(sv) & SVs_PADTMP))
#ifndef PERL_CORE
# define SvPADMY_on(sv)		SvPADTMP_off(sv)
#endif

#define SvPADTMP(sv)		(SvFLAGS(sv) & (SVs_PADTMP))
#define SvPADSTALE(sv)		(SvFLAGS(sv) & (SVs_PADSTALE))

#define SvPADTMP_on(sv)		(SvFLAGS(sv) |= SVs_PADTMP)
#define SvPADTMP_off(sv)	(SvFLAGS(sv) &= ~SVs_PADTMP)
#define SvPADSTALE_on(sv)	Perl_SvPADSTALE_on(MUTABLE_SV(sv))
#define SvPADSTALE_off(sv)	Perl_SvPADSTALE_off(MUTABLE_SV(sv))

#define SvTEMP(sv)		(SvFLAGS(sv) & SVs_TEMP)
#define SvTEMP_on(sv)		(SvFLAGS(sv) |= SVs_TEMP)
#define SvTEMP_off(sv)		(SvFLAGS(sv) &= ~SVs_TEMP)

#define SvOBJECT(sv)		(SvFLAGS(sv) & SVs_OBJECT)
#define SvOBJECT_on(sv)		(SvFLAGS(sv) |= SVs_OBJECT)
#define SvOBJECT_off(sv)	(SvFLAGS(sv) &= ~SVs_OBJECT)

/*
=for apidoc Am|U32|SvREADONLY|SV* sv
Returns true if the argument is readonly, otherwise returns false.
Exposed to perl code via Internals::SvREADONLY().

=for apidoc Am|U32|SvREADONLY_on|SV* sv
Mark an object as readonly. Exactly what this means depends on the object
type. Exposed to perl code via Internals::SvREADONLY().

=for apidoc Am|U32|SvREADONLY_off|SV* sv
Mark an object as not-readonly. Exactly what this mean depends on the
object type. Exposed to perl code via Internals::SvREADONLY().

=cut
*/

#define SvREADONLY(sv)		(SvFLAGS(sv) & (SVf_READONLY|SVf_PROTECT))
#ifdef PERL_CORE
# define SvREADONLY_on(sv)	(SvFLAGS(sv) |= (SVf_READONLY|SVf_PROTECT))
# define SvREADONLY_off(sv)	(SvFLAGS(sv) &=~(SVf_READONLY|SVf_PROTECT))
#else
# define SvREADONLY_on(sv)	(SvFLAGS(sv) |= SVf_READONLY)
# define SvREADONLY_off(sv)	(SvFLAGS(sv) &= ~SVf_READONLY)
#endif

#define SvSCREAM(sv) ((SvFLAGS(sv) & (SVp_SCREAM|SVp_POK)) == (SVp_SCREAM|SVp_POK))
#define SvSCREAM_on(sv)		(SvFLAGS(sv) |= SVp_SCREAM)
#define SvSCREAM_off(sv)	(SvFLAGS(sv) &= ~SVp_SCREAM)

#ifndef PERL_CORE
#  define SvCOMPILED(sv)	0
#  define SvCOMPILED_on(sv)
#  define SvCOMPILED_off(sv)
#endif


#if defined (DEBUGGING) && defined(PERL_USE_GCC_BRACE_GROUPS)
#  define SvTAIL(sv)	({ const SV *const _svtail = (const SV *)(sv);	\
                            assert(SvTYPE(_svtail) != SVt_PVAV);	\
                            assert(SvTYPE(_svtail) != SVt_PVHV);	\
                            assert(!(SvFLAGS(_svtail) & (SVf_NOK|SVp_NOK))); \
                            assert(SvVALID(_svtail));                        \
                            ((XPVNV*)SvANY(_svtail))->xnv_u.xnv_bm_tail;     \
                        })
#else
#  define SvTAIL(_svtail)  (((XPVNV*)SvANY(_svtail))->xnv_u.xnv_bm_tail)
#endif

/* Does the SV have a Boyer-Moore table attached as magic?
 * 'VALID' is a poor name, but is kept for historical reasons.  */
#define SvVALID(_svvalid) (                                  \
               SvPOKp(_svvalid)                              \
            && SvSMAGICAL(_svvalid)                          \
            && SvMAGIC(_svvalid)                             \
            && (SvMAGIC(_svvalid)->mg_type == PERL_MAGIC_bm  \
                || mg_find(_svvalid, PERL_MAGIC_bm))         \
        )

#define SvRVx(sv) SvRV(sv)

#ifdef PERL_DEBUG_COW
/* Need -0.0 for SvNVX to preserve IEEE FP "negative zero" because
   +0.0 + -0.0 => +0.0 but -0.0 + -0.0 => -0.0 */
#  define SvIVX(sv) (0 + ((XPVIV*) SvANY(sv))->xiv_iv)
#  define SvUVX(sv) (0 + ((XPVUV*) SvANY(sv))->xuv_uv)
#  define SvNVX(sv) (-0.0 + ((XPVNV*) SvANY(sv))->xnv_u.xnv_nv)
#  define SvRV(sv) (0 + (sv)->sv_u.svu_rv)
#  define SvRV_const(sv) (0 + (sv)->sv_u.svu_rv)
/* Don't test the core XS code yet.  */
#  if defined (PERL_CORE) && PERL_DEBUG_COW > 1
#    define SvPVX(sv) (0 + (assert_(!SvREADONLY(sv)) (sv)->sv_u.svu_pv))
#  else
#  define SvPVX(sv) SvPVX_mutable(sv)
#  endif
#  define SvCUR(sv) (0 + ((XPV*) SvANY(sv))->xpv_cur)
#  define SvLEN(sv) (0 + ((XPV*) SvANY(sv))->xpv_len)
#  define SvEND(sv) ((sv)->sv_u.svu_pv + ((XPV*)SvANY(sv))->xpv_cur)

#  define SvMAGIC(sv)	(0 + *(assert_(SvTYPE(sv) >= SVt_PVMG) &((XPVMG*)  SvANY(sv))->xmg_u.xmg_magic))
#  define SvSTASH(sv)	(0 + *(assert_(SvTYPE(sv) >= SVt_PVMG) &((XPVMG*)  SvANY(sv))->xmg_stash))
#else   /* Below is not PERL_DEBUG_COW */
# ifdef PERL_CORE
#  define SvLEN(sv) (0 + ((XPV*) SvANY(sv))->xpv_len)
# else
#  define SvLEN(sv) ((XPV*) SvANY(sv))->xpv_len
# endif
#  define SvEND(sv) ((sv)->sv_u.svu_pv + ((XPV*)SvANY(sv))->xpv_cur)

#  if defined (DEBUGGING) && defined(PERL_USE_GCC_BRACE_GROUPS)
/* These get expanded inside other macros that already use a variable _sv  */
#    define SvPVX(sv)							\
        (*({ SV *const _svpvx = MUTABLE_SV(sv);				\
            assert(PL_valid_types_PVX[SvTYPE(_svpvx) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svpvx));				\
            assert(!(SvTYPE(_svpvx) == SVt_PVIO				\
                     && !(IoFLAGS(_svpvx) & IOf_FAKE_DIRP)));		\
            &((_svpvx)->sv_u.svu_pv);					\
         }))
#   ifdef PERL_CORE
#    define SvCUR(sv)							\
        ({ const SV *const _svcur = (const SV *)(sv);			\
            assert(PL_valid_types_PVX[SvTYPE(_svcur) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svcur));				\
            assert(!(SvTYPE(_svcur) == SVt_PVIO				\
                     && !(IoFLAGS(_svcur) & IOf_FAKE_DIRP)));		\
            (((XPV*) MUTABLE_PTR(SvANY(_svcur)))->xpv_cur);		\
         })
#   else
#    define SvCUR(sv)							\
        (*({ const SV *const _svcur = (const SV *)(sv);			\
            assert(PL_valid_types_PVX[SvTYPE(_svcur) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svcur));				\
            assert(!(SvTYPE(_svcur) == SVt_PVIO				\
                     && !(IoFLAGS(_svcur) & IOf_FAKE_DIRP)));		\
            &(((XPV*) MUTABLE_PTR(SvANY(_svcur)))->xpv_cur);		\
         }))
#   endif
#    define SvIVX(sv)							\
        (*({ const SV *const _svivx = (const SV *)(sv);			\
            assert(PL_valid_types_IVX[SvTYPE(_svivx) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svivx));				\
            &(((XPVIV*) MUTABLE_PTR(SvANY(_svivx)))->xiv_iv);		\
         }))
#    define SvUVX(sv)							\
        (*({ const SV *const _svuvx = (const SV *)(sv);			\
            assert(PL_valid_types_IVX[SvTYPE(_svuvx) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svuvx));				\
            &(((XPVUV*) MUTABLE_PTR(SvANY(_svuvx)))->xuv_uv);		\
         }))
#    define SvNVX(sv)							\
        (*({ const SV *const _svnvx = (const SV *)(sv);			\
            assert(PL_valid_types_NVX[SvTYPE(_svnvx) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svnvx));				\
            &(((XPVNV*) MUTABLE_PTR(SvANY(_svnvx)))->xnv_u.xnv_nv);	\
         }))
#    define SvRV(sv)							\
        (*({ SV *const _svrv = MUTABLE_SV(sv);				\
            assert(PL_valid_types_RV[SvTYPE(_svrv) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svrv));				\
            assert(!(SvTYPE(_svrv) == SVt_PVIO				\
                     && !(IoFLAGS(_svrv) & IOf_FAKE_DIRP)));		\
            &((_svrv)->sv_u.svu_rv);					\
         }))
#    define SvRV_const(sv)						\
        ({ const SV *const _svrv = (const SV *)(sv);			\
            assert(PL_valid_types_RV[SvTYPE(_svrv) & SVt_MASK]);	\
            assert(!isGV_with_GP(_svrv));				\
            assert(!(SvTYPE(_svrv) == SVt_PVIO				\
                     && !(IoFLAGS(_svrv) & IOf_FAKE_DIRP)));		\
            (_svrv)->sv_u.svu_rv;					\
         })
#    define SvMAGIC(sv)							\
        (*({ const SV *const _svmagic = (const SV *)(sv);		\
            assert(SvTYPE(_svmagic) >= SVt_PVMG);			\
            &(((XPVMG*) MUTABLE_PTR(SvANY(_svmagic)))->xmg_u.xmg_magic); \
          }))
#    define SvSTASH(sv)							\
        (*({ const SV *const _svstash = (const SV *)(sv);		\
            assert(SvTYPE(_svstash) >= SVt_PVMG);			\
            &(((XPVMG*) MUTABLE_PTR(SvANY(_svstash)))->xmg_stash);	\
          }))
#  else     /* Below is not DEBUGGING or can't use brace groups */
#    define SvPVX(sv) ((sv)->sv_u.svu_pv)
#    define SvCUR(sv) ((XPV*) SvANY(sv))->xpv_cur
#    define SvIVX(sv) ((XPVIV*) SvANY(sv))->xiv_iv
#    define SvUVX(sv) ((XPVUV*) SvANY(sv))->xuv_uv
#    define SvNVX(sv) ((XPVNV*) SvANY(sv))->xnv_u.xnv_nv
#    define SvRV(sv) ((sv)->sv_u.svu_rv)
#    define SvRV_const(sv) (0 + (sv)->sv_u.svu_rv)
#    define SvMAGIC(sv)	((XPVMG*)  SvANY(sv))->xmg_u.xmg_magic
#    define SvSTASH(sv)	((XPVMG*)  SvANY(sv))->xmg_stash
#  endif
#endif

#ifndef PERL_POISON
/* Given that these two are new, there can't be any existing code using them
 *  as LVALUEs, so prevent that from happening  */
#  define SvPVX_mutable(sv)	((char *)((sv)->sv_u.svu_pv))
#  define SvPVX_const(sv)	((const char*)((sv)->sv_u.svu_pv))
#else
/* Except for the poison code, which uses & to scribble over the pointer after
   free() is called.  */
#  define SvPVX_mutable(sv)	((sv)->sv_u.svu_pv)
#  define SvPVX_const(sv)	((const char*)((sv)->sv_u.svu_pv))
#endif

#define SvIVXx(sv) SvIVX(sv)
#define SvUVXx(sv) SvUVX(sv)
#define SvNVXx(sv) SvNVX(sv)
#define SvPVXx(sv) SvPVX(sv)
#define SvLENx(sv) SvLEN(sv)
#define SvENDx(sv) ((PL_Sv = (sv)), SvEND(PL_Sv))


/* Ask a scalar nicely to try to become an IV, if possible.
   Not guaranteed to stay returning void */
/* Macro won't actually call sv_2iv if already IOK */
#define SvIV_please(sv) \
        STMT_START {                                                        \
            SV * sv_ = MUTABLE_SV(sv);                                      \
            if (!SvIOKp(sv_) && (SvFLAGS(sv_) & (SVf_NOK|SVf_POK)))         \
                (void) SvIV(sv_);                                           \
        } STMT_END
#define SvIV_please_nomg(sv) \
        (!(SvFLAGS(sv) & (SVf_IOK|SVp_IOK)) && (SvFLAGS(sv) & (SVf_NOK|SVf_POK)) \
            ? (sv_2iv_flags(sv, 0), SvIOK(sv))	  \
            : SvIOK(sv))

#define SvIV_set(sv, val) \
        STMT_START { \
                SV * sv_ = MUTABLE_SV(sv);                                  \
                assert(PL_valid_types_IV_set[SvTYPE(sv_) & SVt_MASK]);      \
                assert(!isGV_with_GP(sv_));                                 \
                (((XPVIV*)  SvANY(sv_))->xiv_iv = (val));                   \
        } STMT_END

#define SvNV_set(sv, val) \
        STMT_START { \
                SV * sv_ = MUTABLE_SV(sv);                                  \
                assert(PL_valid_types_NV_set[SvTYPE(sv_) & SVt_MASK]);      \
                assert(!isGV_with_GP(sv_));                                 \
                (((XPVNV*)SvANY(sv_))->xnv_u.xnv_nv = (val));               \
        } STMT_END

#define SvPV_set(sv, val) \
        STMT_START { \
                SV * sv_ = MUTABLE_SV(sv);                                  \
                assert(PL_valid_types_PVX[SvTYPE(sv_) & SVt_MASK]);         \
                assert(!isGV_with_GP(sv_));		                    \
                assert(!(SvTYPE(sv_) == SVt_PVIO		            \
                     && !(IoFLAGS(sv_) & IOf_FAKE_DIRP)));                  \
                ((sv_)->sv_u.svu_pv = (val));                               \
        } STMT_END

#define SvUV_set(sv, val) \
        STMT_START { \
                SV * sv_ = MUTABLE_SV(sv);                                  \
                assert(PL_valid_types_IV_set[SvTYPE(sv_) & SVt_MASK]);	    \
                assert(!isGV_with_GP(sv_));		                    \
                (((XPVUV*)SvANY(sv_))->xuv_uv = (val));                     \
        } STMT_END

#define SvRV_set(sv, val) \
        STMT_START { \
                SV * sv_ = MUTABLE_SV(sv);                                  \
                assert(PL_valid_types_RV[SvTYPE(sv_) & SVt_MASK]);	    \
                assert(!isGV_with_GP(sv_));		                    \
                assert(!(SvTYPE(sv_) == SVt_PVIO		            \
                     && !(IoFLAGS(sv_) & IOf_FAKE_DIRP)));                  \
                ((sv_)->sv_u.svu_rv = (val));                               \
        } STMT_END
#define SvMAGIC_set(sv, val) \
        STMT_START { assert(SvTYPE(sv) >= SVt_PVMG); \
                (((XPVMG*)SvANY(sv))->xmg_u.xmg_magic = (val)); } STMT_END
#define SvSTASH_set(sv, val) \
        STMT_START { assert(SvTYPE(sv) >= SVt_PVMG); \
                (((XPVMG*)  SvANY(sv))->xmg_stash = (val)); } STMT_END
#define SvCUR_set(sv, val) \
        STMT_START { \
                assert(PL_valid_types_PVX[SvTYPE(sv) & SVt_MASK]);	\
                assert(!isGV_with_GP(sv));		\
                assert(!(SvTYPE(sv) == SVt_PVIO		\
                     && !(IoFLAGS(sv) & IOf_FAKE_DIRP))); \
                (((XPV*)  SvANY(sv))->xpv_cur = (val)); } STMT_END
#define SvLEN_set(sv, val) \
        STMT_START { \
                assert(PL_valid_types_PVX[SvTYPE(sv) & SVt_MASK]);	\
                assert(!isGV_with_GP(sv));	\
                assert(!(SvTYPE(sv) == SVt_PVIO		\
                     && !(IoFLAGS(sv) & IOf_FAKE_DIRP))); \
                (((XPV*)  SvANY(sv))->xpv_len = (val)); } STMT_END
#define SvEND_set(sv, val) \
        STMT_START { assert(SvTYPE(sv) >= SVt_PV); \
                SvCUR_set(sv, (val) - SvPVX(sv)); } STMT_END

/*
=for apidoc Am|void|SvPV_renew|SV* sv|STRLEN len
Low level micro optimization of C<L</SvGROW>>.  It is generally better to use
C<SvGROW> instead.  This is because C<SvPV_renew> ignores potential issues that
C<SvGROW> handles.  C<sv> needs to have a real C<PV> that is unencumbered by
things like COW.  Using C<SV_CHECK_THINKFIRST> or
C<SV_CHECK_THINKFIRST_COW_DROP> before calling this should clean it up, but
why not just use C<SvGROW> if you're not sure about the provenance?

=cut
*/
#define SvPV_renew(sv,n) \
        STMT_START { SvLEN_set(sv, n); \
                SvPV_set((sv), (MEM_WRAP_CHECK_(n,char)			\
                                (char*)saferealloc((Malloc_t)SvPVX(sv), \
                                                   (MEM_SIZE)((n)))));  \
                 } STMT_END
/*
=for apidoc Am|void|SvPV_shrink_to_cur|SV* sv

Trim any trailing unused memory in the PV of C<sv>, which needs to have a real
C<PV> that is unencumbered by things like COW.  Think first before using this
functionality.  Is the space saving really worth giving up COW?  Will the
needed size of C<sv> stay the same?

If the answers are both yes, then use L</C<SV_CHECK_THINKFIRST>> or
L</C<SV_CHECK_THINKFIRST_COW_DROP>> before calling this.

=cut
*/

#define SvPV_shrink_to_cur(sv) STMT_START { \
                   const STRLEN _lEnGtH = SvCUR(sv) + 1; \
                   SvPV_renew(sv, _lEnGtH); \
                 } STMT_END

/*
=for apidoc Am|void|SvPV_free|SV * sv

Frees the PV buffer in C<sv>, leaving things in a precarious state, so should
only be used as part of a larger operation

=cut
*/
#define SvPV_free(sv)							\
    STMT_START {							\
                     assert(SvTYPE(sv) >= SVt_PV);			\
                     if (SvLEN(sv)) {					\
                         assert(!SvROK(sv));				\
                         if(UNLIKELY(SvOOK(sv))) {			\
                             STRLEN zok; 				\
                             SvOOK_offset(sv, zok);			\
                             SvPV_set(sv, SvPVX_mutable(sv) - zok);	\
                             SvFLAGS(sv) &= ~SVf_OOK;			\
                         }						\
                         Safefree(SvPVX(sv));				\
                     }							\
                 } STMT_END

#ifdef PERL_CORE
/* Code that crops up in three places to take a scalar and ready it to hold
   a reference */
#  define prepare_SV_for_RV(sv)						\
    STMT_START {							\
                    if (SvTYPE(sv) < SVt_PV && SvTYPE(sv) != SVt_IV)	\
                        sv_upgrade(sv, SVt_IV);				\
                    else if (SvTYPE(sv) >= SVt_PV) {			\
                        SvPV_free(sv);					\
                        SvLEN_set(sv, 0);				\
                        SvCUR_set(sv, 0);				\
                    }							\
                 } STMT_END
#endif

#ifndef PERL_CORE
#  define BmFLAGS(sv)		(SvTAIL(sv) ? FBMcf_TAIL : 0)
#endif

#if defined (DEBUGGING) && defined(PERL_USE_GCC_BRACE_GROUPS)
#  define BmUSEFUL(sv)							\
        (*({ SV *const _bmuseful = MUTABLE_SV(sv);			\
            assert(SvTYPE(_bmuseful) >= SVt_PVIV);			\
            assert(SvVALID(_bmuseful));					\
            assert(!SvIOK(_bmuseful));					\
            &(((XPVIV*) SvANY(_bmuseful))->xiv_u.xivu_iv);              \
         }))
#else
#  define BmUSEFUL(sv)          ((XPVIV*) SvANY(sv))->xiv_u.xivu_iv

#endif

#ifndef PERL_CORE
# define BmRARE(sv)	0
# define BmPREVIOUS(sv)	0
#endif

#define FmLINES(sv)	((XPVIV*)  SvANY(sv))->xiv_iv

#define LvTYPE(sv)	((XPVLV*)  SvANY(sv))->xlv_type
#define LvTARG(sv)	((XPVLV*)  SvANY(sv))->xlv_targ
#define LvTARGOFF(sv)	((XPVLV*)  SvANY(sv))->xlv_targoff
#define LvSTARGOFF(sv)	((XPVLV*)  SvANY(sv))->xlv_targoff_u.xlvu_stargoff
#define LvTARGLEN(sv)	((XPVLV*)  SvANY(sv))->xlv_targlen
#define LvFLAGS(sv)	((XPVLV*)  SvANY(sv))->xlv_flags

#define LVf_NEG_OFF      0x1
#define LVf_NEG_LEN      0x2
#define LVf_OUT_OF_RANGE 0x4

#define IoIFP(sv)	(sv)->sv_u.svu_fp
#define IoOFP(sv)	((XPVIO*)  SvANY(sv))->xio_ofp
#define IoDIRP(sv)	((XPVIO*)  SvANY(sv))->xio_dirp
#define IoANY(sv)	((XPVIO*)  SvANY(sv))->xio_any
#define IoLINES(sv)	((XPVIO*)  SvANY(sv))->xiv_u.xivu_iv
#define IoPAGE(sv)	((XPVIO*)  SvANY(sv))->xio_page
#define IoPAGE_LEN(sv)	((XPVIO*)  SvANY(sv))->xio_page_len
#define IoLINES_LEFT(sv)((XPVIO*)  SvANY(sv))->xio_lines_left
#define IoTOP_NAME(sv)	((XPVIO*)  SvANY(sv))->xio_top_name
#define IoTOP_GV(sv)	((XPVIO*)  SvANY(sv))->xio_top_gv
#define IoFMT_NAME(sv)	((XPVIO*)  SvANY(sv))->xio_fmt_name
#define IoFMT_GV(sv)	((XPVIO*)  SvANY(sv))->xio_fmt_gv
#define IoBOTTOM_NAME(sv)((XPVIO*) SvANY(sv))->xio_bottom_name
#define IoBOTTOM_GV(sv)	((XPVIO*)  SvANY(sv))->xio_bottom_gv
#define IoTYPE(sv)	((XPVIO*)  SvANY(sv))->xio_type
#define IoFLAGS(sv)	((XPVIO*)  SvANY(sv))->xio_flags

/* IoTYPE(sv) is a single character telling the type of I/O connection. */
#define IoTYPE_RDONLY		'<'
#define IoTYPE_WRONLY		'>'
#define IoTYPE_RDWR		'+'
#define IoTYPE_APPEND 		'a'
#define IoTYPE_PIPE		'|'
#define IoTYPE_STD		'-'	/* stdin or stdout */
#define IoTYPE_SOCKET		's'
#define IoTYPE_CLOSED		' '
#define IoTYPE_IMPLICIT		'I'	/* stdin or stdout or stderr */
#define IoTYPE_NUMERIC		'#'	/* fdopen */

/*
=for apidoc_section $tainting
=for apidoc Am|bool|SvTAINTED|SV* sv
Checks to see if an SV is tainted.  Returns TRUE if it is, FALSE if
not.

=for apidoc Am|void|SvTAINTED_on|SV* sv
Marks an SV as tainted if tainting is enabled.

=for apidoc Am|void|SvTAINTED_off|SV* sv
Untaints an SV.  Be I<very> careful with this routine, as it short-circuits
some of Perl's fundamental security features.  XS module authors should not
use this function unless they fully understand all the implications of
unconditionally untainting the value.  Untainting should be done in the
standard perl fashion, via a carefully crafted regexp, rather than directly
untainting variables.

=for apidoc Am|void|SvTAINT|SV* sv
Taints an SV if tainting is enabled, and if some input to the current
expression is tainted--usually a variable, but possibly also implicit
inputs such as locale settings.  C<SvTAINT> propagates that taintedness to
the outputs of an expression in a pessimistic fashion; i.e., without paying
attention to precisely which outputs are influenced by which inputs.

=cut
*/

#define sv_taint(sv)	  sv_magic((sv), NULL, PERL_MAGIC_taint, NULL, 0)

#ifdef NO_TAINT_SUPPORT
#   define SvTAINTED(sv) 0
#else
#   define SvTAINTED(sv)	  (SvMAGICAL(sv) && sv_tainted(sv))
#endif
#define SvTAINTED_on(sv)  STMT_START{ if(UNLIKELY(TAINTING_get)){sv_taint(sv);}   }STMT_END
#define SvTAINTED_off(sv) STMT_START{ if(UNLIKELY(TAINTING_get)){sv_untaint(sv);} }STMT_END

#define SvTAINT(sv)			\
    STMT_START {			\
        assert(TAINTING_get || !TAINT_get); \
        if (UNLIKELY(TAINT_get))	\
            SvTAINTED_on(sv);	        \
    } STMT_END

/*
=for apidoc_section $SV
=for apidoc Am|char*|SvPV_force              |SV* sv|STRLEN len
=for apidoc_item   ||SvPV_force_flags        |SV * sv|STRLEN len|U32 flags
=for apidoc_item   ||SvPV_force_flags_mutable|SV * sv|STRLEN len|U32 flags
=for apidoc_item   ||SvPV_force_flags_nolen  |SV * sv           |U32 flags
=for apidoc_item   ||SvPV_force_mutable      |SV * sv|STRLEN len
=for apidoc_item   ||SvPV_force_nolen        |SV* sv
=for apidoc_item   ||SvPV_force_nomg         |SV* sv|STRLEN len
=for apidoc_item   ||SvPV_force_nomg_nolen   |SV * sv
=for apidoc_item   ||SvPVbyte_force          |SV * sv|STRLEN len
=for apidoc_item   ||SvPVbytex_force         |SV * sv|STRLEN len
=for apidoc_item   ||SvPVutf8_force          |SV * sv|STRLEN len
=for apidoc_item   ||SvPVutf8x_force         |SV * sv|STRLEN len
=for apidoc_item   ||SvPVx_force             |SV* sv|STRLEN len

These are like C<L</SvPV>>, returning the string in the SV, but will force the
SV into containing a string (C<L</SvPOK>>), and only a string
(C<L</SvPOK_only>>), by hook or by crook.  You need to use one of these
C<force> routines if you are going to update the C<L</SvPVX>> directly.

Note that coercing an arbitrary scalar into a plain PV will potentially
strip useful data from it.  For example if the SV was C<SvROK>, then the
referent will have its reference count decremented, and the SV itself may
be converted to an C<SvPOK> scalar with a string buffer containing a value
such as C<"ARRAY(0x1234)">.

The differences between the forms are:

The forms with C<flags> in their names allow you to use the C<flags> parameter
to specify to perform 'get' magic (by setting the C<SV_GMAGIC> flag) or to skip
'get' magic (by clearing it).  The other forms do perform 'get' magic, except
for the ones with C<nomg> in their names, which skip 'get' magic.

The forms that take a C<len> parameter will set that variable to the byte
length of the resultant string (these are macros, so don't use C<&len>).

The forms with C<nolen> in their names indicate they don't have a C<len>
parameter.  They should be used only when it is known that the PV is a C
string, terminated by a NUL byte, and without intermediate NUL characters; or
when you don't care about its length.

The forms with C<mutable> in their names are effectively the same as those without,
but the name emphasizes that the string is modifiable by the caller, which it is
in all the forms.

C<SvPVutf8_force> is like C<SvPV_force>, but converts C<sv> to UTF-8 first if
not already UTF-8.

C<SvPVutf8x_force> is like C<SvPVutf8_force>, but guarantees to evaluate C<sv>
only once; use the more efficient C<SvPVutf8_force> otherwise.

C<SvPVbyte_force> is like C<SvPV_force>, but converts C<sv> to byte
representation first if currently encoded as UTF-8.  If the SV cannot be
downgraded from UTF-8, this croaks.

C<SvPVbytex_force> is like C<SvPVbyte_force>, but guarantees to evaluate C<sv>
only once; use the more efficient C<SvPVbyte_force> otherwise.

=for apidoc Am   |      char*|SvPV                 |SV* sv|STRLEN len
=for apidoc_item |const char*|SvPV_const           |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPV_flags           |SV* sv|STRLEN len|U32 flags
=for apidoc_item |const char*|SvPV_flags_const     |SV* sv|STRLEN len|U32 flags
=for apidoc_item |      char*|SvPV_flags_mutable   |SV* sv|STRLEN len|U32 flags
=for apidoc_item |      char*|SvPV_mutable         |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPV_nolen           |SV* sv
=for apidoc_item |const char*|SvPV_nolen_const     |SV* sv
=for apidoc_item |      char*|SvPV_nomg            |SV* sv|STRLEN len
=for apidoc_item |const char*|SvPV_nomg_const      |SV* sv|STRLEN len
=for apidoc_item |const char*|SvPV_nomg_const_nolen|SV* sv
=for apidoc_item |      char*|SvPV_nomg_nolen      |SV* sv
=for apidoc_item |      char*|SvPVbyte             |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVbyte_nolen       |SV* sv
=for apidoc_item |      char*|SvPVbyte_nomg        |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVbyte_or_null     |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVbyte_or_null_nomg|SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVbytex            |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVbytex_nolen      |SV* sv
=for apidoc_item |      char*|SvPVutf8             |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVutf8_nolen       |SV* sv
=for apidoc_item |      char*|SvPVutf8_nomg        |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVutf8_or_null     |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVutf8_or_null_nomg|SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVutf8x            |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVx                |SV* sv|STRLEN len
=for apidoc_item |const char*|SvPVx_const          |SV* sv|STRLEN len
=for apidoc_item |      char*|SvPVx_nolen          |SV* sv
=for apidoc_item |const char*|SvPVx_nolen_const    |SV* sv

These each return a pointer to the string in C<sv>, or a stringified form of
C<sv> if it does not contain a string.  The SV may cache the stringified
version becoming C<SvPOK>.

This is a very basic and common operation, so there are lots of slightly
different versions of it.

Note that there is no guarantee that the return value of C<SvPV(sv)>, for
example, is equal to C<SvPVX(sv)>, or that C<SvPVX(sv)> contains valid data, or
that successive calls to C<SvPV(sv)> (or another of these forms) will return
the same pointer value each time.  This is due to the way that things like
overloading and Copy-On-Write are handled.  In these cases, the return value
may point to a temporary buffer or similar.  If you absolutely need the
C<SvPVX> field to be valid (for example, if you intend to write to it), then
see C<L</SvPV_force>>.

The differences between the forms are:

The forms with neither C<byte> nor C<utf8> in their names (e.g., C<SvPV> or
C<SvPV_nolen>) can expose the SV's internal string buffer. If
that buffer consists entirely of bytes 0-255 and includes any bytes above
127, then you B<MUST> consult C<SvUTF8> to determine the actual code points
the string is meant to contain. Generally speaking, it is probably safer to
prefer C<SvPVbyte>, C<SvPVutf8>, and the like. See
L<perlguts/How do I pass a Perl string to a C library?> for more details.

The forms with C<flags> in their names allow you to use the C<flags> parameter
to specify to process 'get' magic (by setting the C<SV_GMAGIC> flag) or to skip
'get' magic (by clearing it).  The other forms process 'get' magic, except for
the ones with C<nomg> in their names, which skip 'get' magic.

The forms that take a C<len> parameter will set that variable to the byte
length of the resultant string (these are macros, so don't use C<&len>).

The forms with C<nolen> in their names indicate they don't have a C<len>
parameter.  They should be used only when it is known that the PV is a C
string, terminated by a NUL byte, and without intermediate NUL characters; or
when you don't care about its length.

The forms with C<const> in their names return S<C<const char *>> so that the
compiler will hopefully complain if you were to try to modify the contents of
the string (unless you cast away const yourself).

The other forms return a mutable pointer so that the string is modifiable by
the caller; this is emphasized for the ones with C<mutable> in their names.

As of 5.38, all forms are guaranteed to evaluate C<sv> exactly once.  For
earlier Perls, use a form whose name ends with C<x> for single evaluation.

C<SvPVutf8> is like C<SvPV>, but converts C<sv> to UTF-8 first if not already
UTF-8.  Similarly, the other forms with C<utf8> in their names correspond to
their respective forms without.

C<SvPVutf8_or_null> and C<SvPVutf8_or_null_nomg> don't have corresponding
non-C<utf8> forms.  Instead they are like C<SvPVutf8_nomg>, but when C<sv> is
undef, they return C<NULL>.

C<SvPVbyte> is like C<SvPV>, but converts C<sv> to byte representation first if
currently encoded as UTF-8.  If C<sv> cannot be downgraded from UTF-8, it
croaks.  Similarly, the other forms with C<byte> in their names correspond to
their respective forms without.

C<SvPVbyte_or_null> doesn't have a corresponding non-C<byte> form.  Instead it
is like C<SvPVbyte>, but when C<sv> is undef, it returns C<NULL>.

=for apidoc      SvTRUE
=for apidoc_item SvTRUE_NN
=for apidoc_item SvTRUE_nomg
=for apidoc_item SvTRUE_nomg_NN
=for apidoc_item SvTRUEx

These return a boolean indicating whether Perl would evaluate the SV as true or
false.  See C<L</SvOK>> for a defined/undefined test.

As of Perl 5.32, all are guaranteed to evaluate C<sv> only once.  Prior to that
release, only C<SvTRUEx> guaranteed single evaluation; now C<SvTRUEx> is
identical to C<SvTRUE>.

C<SvTRUE_nomg> and C<TRUE_nomg_NN> do not perform 'get' magic; the others do
unless the scalar is already C<SvPOK>, C<SvIOK>, or C<SvNOK> (the public, not
the private flags).

C<SvTRUE_NN> is like C<L</SvTRUE>>, but C<sv> is assumed to be
non-null (NN).  If there is a possibility that it is NULL, use plain
C<SvTRUE>.

C<SvTRUE_nomg_NN> is like C<L</SvTRUE_nomg>>, but C<sv> is assumed to be
non-null (NN).  If there is a possibility that it is NULL, use plain
C<SvTRUE_nomg>.

=for apidoc Am|U32|SvIsCOW|SV* sv
Returns a U32 value indicating whether the SV is Copy-On-Write (either shared
hash key scalars, or full Copy On Write scalars if 5.9.0 is configured for
COW).

=for apidoc Am|bool|SvIsCOW_shared_hash|SV* sv
Returns a boolean indicating whether the SV is Copy-On-Write shared hash key
scalar.

=cut
*/

/* To pass the action to the functions called by the following macros */
typedef enum {
    SvPVutf8_type_,
    SvPVbyte_type_,
    SvPVnormal_type_,
    SvPVforce_type_,
    SvPVutf8_pure_type_,
    SvPVbyte_pure_type_
} PL_SvPVtype;

START_EXTERN_C

/* When this code was written, embed.fnc could not handle function pointer
 * parameters; perhaps it still can't */
#ifndef PERL_NO_INLINE_FUNCTIONS
PERL_STATIC_INLINE char*
Perl_SvPV_helper(pTHX_ SV *const sv, STRLEN *const lp, const U32 flags, const PL_SvPVtype type, char * (*non_trivial)(pTHX_ SV *, STRLEN * const, const U32), const bool or_null, const U32 return_flags);
#endif

END_EXTERN_C

/* This test is "is there a cached PV that we can use directly?"
 * We can if
 * a) SVf_POK is true and there's definitely no get magic on the scalar
 * b) SVp_POK is true, there's no get magic, and we know that the cached PV
 *    came from an IV conversion.
 * For the latter case, we don't set SVf_POK so that we can distinguish whether
 * the value originated as a string or as an integer, before we cached the
 * second representation. */
#define SvPOK_or_cached_IV(sv) \
    (((SvFLAGS(sv) & (SVf_POK|SVs_GMG)) == SVf_POK) || ((SvFLAGS(sv) & (SVf_IOK|SVp_POK|SVs_GMG)) == (SVf_IOK|SVp_POK)))

#define SvPV_flags(sv, len, flags)                                          \
   Perl_SvPV_helper(aTHX_ sv, &len, flags, SvPVnormal_type_,                \
                    Perl_sv_2pv_flags, FALSE, 0)
#define SvPV_flags_const(sv, len, flags)                                    \
   ((const char*) Perl_SvPV_helper(aTHX_ sv, &len, flags, SvPVnormal_type_, \
                                   Perl_sv_2pv_flags, FALSE,                \
                                   SV_CONST_RETURN))
#define SvPV_flags_const_nolen(sv, flags)                                   \
   ((const char*) Perl_SvPV_helper(aTHX_ sv, NULL, flags, SvPVnormal_type_, \
                                   Perl_sv_2pv_flags, FALSE,                \
                                   SV_CONST_RETURN))
#define SvPV_flags_mutable(sv, len, flags)                                  \
    Perl_SvPV_helper(aTHX_ sv, &len, flags, SvPVnormal_type_,               \
                     Perl_sv_2pv_flags, FALSE, SV_MUTABLE_RETURN)

#define SvPV_nolen(sv)                                                      \
    Perl_SvPV_helper(aTHX_ sv, NULL, SV_GMAGIC, SvPVnormal_type_,           \
                     Perl_sv_2pv_flags, FALSE, 0)

#define SvPV_nolen_const(sv)  SvPV_flags_const_nolen(sv, SV_GMAGIC)

#define SvPV(sv, len)               SvPV_flags(sv, len, SV_GMAGIC)
#define SvPV_const(sv, len)         SvPV_flags_const(sv, len, SV_GMAGIC)
#define SvPV_mutable(sv, len)       SvPV_flags_mutable(sv, len, SV_GMAGIC)

#define SvPV_nomg_nolen(sv)                                                 \
    Perl_SvPV_helper(aTHX_ sv, NULL, 0, SvPVnormal_type_,Perl_sv_2pv_flags, \
                     FALSE, 0)
#define SvPV_nomg(sv, len)          SvPV_flags(sv, len, 0)
#define SvPV_nomg_const(sv, len)    SvPV_flags_const(sv, len, 0)
#define SvPV_nomg_const_nolen(sv)   SvPV_flags_const_nolen(sv, 0)

#define SvPV_force_flags(sv, len, flags)                                    \
    Perl_SvPV_helper(aTHX_ sv, &len, flags, SvPVforce_type_,                \
                     Perl_sv_pvn_force_flags, FALSE, 0)
#define SvPV_force_flags_nolen(sv, flags)                                   \
    Perl_SvPV_helper(aTHX_ sv, NULL, flags, SvPVforce_type_,                \
                     Perl_sv_pvn_force_flags, FALSE, 0)
#define SvPV_force_flags_mutable(sv, len, flags)                            \
    Perl_SvPV_helper(aTHX_ sv, &len, flags, SvPVforce_type_,                \
                     Perl_sv_pvn_force_flags, FALSE, SV_MUTABLE_RETURN)

#define SvPV_force(sv, len)         SvPV_force_flags(sv, len, SV_GMAGIC)
#define SvPV_force_nolen(sv)        SvPV_force_flags_nolen(sv, SV_GMAGIC)
#define SvPV_force_mutable(sv, len) SvPV_force_flags_mutable(sv, len, SV_GMAGIC)

/* "_nomg" in these defines means no mg_get() */
#define SvPV_force_nomg(sv, len)    SvPV_force_flags(sv, len, 0)
#define SvPV_force_nomg_nolen(sv)   SvPV_force_flags_nolen(sv, 0)

#define SvPVutf8(sv, len)                                                   \
    Perl_SvPV_helper(aTHX_ sv, &len, SV_GMAGIC, SvPVutf8_type_,             \
                     Perl_sv_2pvutf8_flags, FALSE, 0)
#define SvPVutf8_nomg(sv, len)                                              \
    Perl_SvPV_helper(aTHX_ sv, &len, 0, SvPVutf8_type_,                     \
                     Perl_sv_2pvutf8_flags, FALSE, 0)
#define SvPVutf8_nolen(sv)                                                  \
    Perl_SvPV_helper(aTHX_ sv, NULL, SV_GMAGIC, SvPVutf8_type_,             \
                     Perl_sv_2pvutf8_flags, FALSE, 0)
#define SvPVutf8_or_null(sv, len)                                           \
    Perl_SvPV_helper(aTHX_ sv, &len, SV_GMAGIC, SvPVutf8_type_,             \
                     Perl_sv_2pvutf8_flags, TRUE, 0)
#define SvPVutf8_or_null_nomg(sv, len)                                      \
    Perl_SvPV_helper(aTHX_ sv, &len, 0, SvPVutf8_type_,                     \
                     Perl_sv_2pvutf8_flags, TRUE, 0)

#define SvPVbyte(sv, len)                                                   \
    Perl_SvPV_helper(aTHX_ sv, &len, SV_GMAGIC, SvPVbyte_type_,             \
                     Perl_sv_2pvbyte_flags, FALSE, 0)
#define SvPVbyte_nomg(sv, len)                                              \
    Perl_SvPV_helper(aTHX_ sv, &len, 0, SvPVbyte_type_,                     \
                     Perl_sv_2pvbyte_flags, FALSE, 0)
#define SvPVbyte_nolen(sv)                                                  \
    Perl_SvPV_helper(aTHX_ sv, NULL, SV_GMAGIC, SvPVbyte_type_,             \
                     Perl_sv_2pvbyte_flags, FALSE, 0)
#define SvPVbyte_or_null(sv, len)                                           \
    Perl_SvPV_helper(aTHX_ sv, &len, SV_GMAGIC, SvPVbyte_type_,             \
                     Perl_sv_2pvbyte_flags, TRUE, 0)
#define SvPVbyte_or_null_nomg(sv, len)                                      \
    Perl_SvPV_helper(aTHX_ sv, &len, 0, SvPVbyte_type_,                     \
                     Perl_sv_2pvbyte_flags, TRUE, 0)

#define SvPVutf8_force(sv, len)                                             \
    Perl_SvPV_helper(aTHX_ sv, &len, 0, SvPVutf8_pure_type_,                \
                     Perl_sv_pvutf8n_force_wrapper, FALSE, 0)

#define SvPVbyte_force(sv, len)                                             \
    Perl_SvPV_helper(aTHX_ sv, &len, 0, SvPVbyte_pure_type_,                \
                     Perl_sv_pvbyten_force_wrapper, FALSE, 0)

/* define FOOx(): Before FOO(x) was inlined, these were idempotent versions of
 * FOO(). */

#define SvPVx_force(sv, len) sv_pvn_force(sv, &len)
#define SvPVutf8x_force(sv, len) sv_pvutf8n_force(sv, &len)
#define SvPVbytex_force(sv, len) sv_pvbyten_force(sv, &len)

/*
=for apidoc_defn Am|bool|SvTRUEx|SV *sv
=for apidoc_defn Am|bool|SvTRUE_nomg_NN|SV *sv
=cut
*/
#define SvTRUEx(sv)        SvTRUE(sv)
#define SvTRUEx_nomg(sv)   SvTRUE_nomg(sv)
#define SvTRUE_nomg_NN(sv) SvTRUE_common(sv, TRUE)

#define SvIVx(sv) SvIV(sv)
#define SvUVx(sv) SvUV(sv)
#define SvNVx(sv) SvNV(sv)

/* The following macro expansions evaluate their arguments just once. In
 * earlier perl releases, the global variable PL_Sv was used as an intermediate
 * in order to prevent multiple evaluations. The implementation changed in
 * commit 1ef9039bccbfe64f47f201b6cfb7d6d23e0b08a7 to use inline functions
 * instead. */
#define SvPVx(sv, len)          SvPV(sv, len)
#define SvPVx_const(sv, len)    SvPV_const(sv, len)
#define SvPVx_nolen(sv)         SvPV_nolen(sv)
#define SvPVx_nolen_const(sv)   SvPV_nolen_const(sv)
#define SvPVutf8x(sv, len)      SvPVutf8(sv, len)
#define SvPVbytex(sv, len)      SvPVbyte(sv, len)
#define SvPVbytex_nolen(sv)     SvPVbyte_nolen(sv)

#define SvIsCOW(sv)              (SvFLAGS(sv) & SVf_IsCOW)
#define SvIsCOW_on(sv)           (SvFLAGS(sv) |= SVf_IsCOW)
#define SvIsCOW_off(sv)          (SvFLAGS(sv) &= ~(SVf_IsCOW|SVppv_STATIC))
#define SvIsCOW_shared_hash(sv)  ((SvFLAGS(sv) & (SVf_IsCOW|SVppv_STATIC)) == (SVf_IsCOW) && SvLEN(sv) == 0)
#define SvIsCOW_static(sv)       ((SvFLAGS(sv) & (SVf_IsCOW|SVppv_STATIC)) == (SVf_IsCOW|SVppv_STATIC))

#define SvSHARED_HEK_FROM_PV(pvx) \
        ((struct hek*)(pvx - STRUCT_OFFSET(struct hek, hek_key)))
/*
=for apidoc Am|struct hek*|SvSHARED_HASH|SV * sv
Returns the hash for C<sv> created by C<L</newSVpvn_share>>.

=cut
*/
#define SvSHARED_HASH(sv) (0 + SvSHARED_HEK_FROM_PV(SvPVX_const(sv))->hek_hash)

/* flag values for sv_*_flags functions */
#define SV_UTF8_NO_ENCODING	0       /* No longer used */

/*
=for apidoc AmnhD||SV_UTF8_NO_ENCODING

=cut
*/

/* Flags used as `U32 flags` arguments to various functions */
#define SV_IMMEDIATE_UNREF      (1 <<  0) /* 0x0001 -     1 */
#define SV_GMAGIC               (1 <<  1) /* 0x0002 -     2 */
#define SV_COW_DROP_PV          (1 <<  2) /* 0x0004 -     4 */
/* SV_NOT_USED                  (1 <<  3)    0x0008 -     8 */
#define SV_NOSTEAL              (1 <<  4) /* 0x0010 -    16 */
#define SV_CONST_RETURN         (1 <<  5) /* 0x0020 -    32 */
#define SV_MUTABLE_RETURN       (1 <<  6) /* 0x0040 -    64 */
#define SV_SMAGIC               (1 <<  7) /* 0x0080 -   128 */
#define SV_HAS_TRAILING_NUL     (1 <<  8) /* 0x0100 -   256 */
#define SV_COW_SHARED_HASH_KEYS (1 <<  9) /* 0x0200 -   512 */
/* This one is only enabled for PERL_OLD_COPY_ON_WRITE */
/* XXX This flag actually enabled for any COW.  But it appears not to do
       anything.  Can we just remove it?  Or will it serve some future
       purpose.  */
#define SV_COW_OTHER_PVS        (1 << 10) /* 0x0400 -  1024 */
/* Make sv_2pv_flags return NULL if something is undefined.  */
#define SV_UNDEF_RETURNS_NULL   (1 << 11) /* 0x0800 -  2048 */
/* Tell sv_utf8_upgrade() to not check to see if an upgrade is really needed.
 * This is used when the caller has already determined it is, and avoids
 * redundant work */
#define SV_FORCE_UTF8_UPGRADE   (1 << 12) /* 0x1000 -  4096 */
/* if (after resolving magic etc), the SV is found to be overloaded,
 * don't call the overload magic, just return as-is */
#define SV_SKIP_OVERLOAD        (1 << 13) /* 0x2000 -  8192 */
#define SV_CATBYTES             (1 << 14) /* 0x4000 - 16384 */
#define SV_CATUTF8              (1 << 15) /* 0x8000 - 32768 */

/* sv_regex_global_pos_*() should count in bytes, not chars */
#define SV_POSBYTES             SV_CATBYTES

/* The core is safe for this COW optimisation. XS code on CPAN may not be.
   So only default to doing the COW setup if we're in the core.
 */
#ifdef PERL_CORE
#  ifndef SV_DO_COW_SVSETSV
#    define SV_DO_COW_SVSETSV	SV_COW_SHARED_HASH_KEYS|SV_COW_OTHER_PVS
#  endif
#endif

#ifndef SV_DO_COW_SVSETSV
#  define SV_DO_COW_SVSETSV	0
#endif


#define sv_unref(sv)    	sv_unref_flags(sv, 0)
#define sv_force_normal(sv)	sv_force_normal_flags(sv, 0)
#define sv_usepvn(sv, p, l)	sv_usepvn_flags(sv, p, l, 0)
#define sv_usepvn_mg(sv, p, l)	sv_usepvn_flags(sv, p, l, SV_SMAGIC)

/*
=for apidoc Am|void|SV_CHECK_THINKFIRST_COW_DROP|SV * sv

Call this when you are about to replace the PV value in C<sv>, which is
potentially copy-on-write.  It stops any sharing with other SVs, so that no
Copy on Write (COW) actually happens.  This COW would be useless, as it would
immediately get changed to something else.  This function also removes any
other encumbrances that would be problematic when changing C<sv>.

=cut
*/

#define SV_CHECK_THINKFIRST_COW_DROP(sv) if (SvTHINKFIRST(sv)) \
                                    sv_force_normal_flags(sv, SV_COW_DROP_PV)

#ifdef PERL_COPY_ON_WRITE
#   define SvCANCOW(sv)					    \
        (SvIsCOW(sv)					     \
         ? SvLEN(sv) ? CowREFCNT(sv) != SV_COW_REFCNT_MAX : 1 \
         : (SvFLAGS(sv) & CAN_COW_MASK) == CAN_COW_FLAGS       \
                            && SvCUR(sv)+1 < SvLEN(sv))
   /* Note: To allow 256 COW "copies", a refcnt of 0 means 1. */
#   define CowREFCNT(sv)	(*(U8 *)(SvPVX(sv)+SvLEN(sv)-1))
#   define SV_COW_REFCNT_MAX	nBIT_UMAX(sizeof(U8) * CHARBITS)
#   define CAN_COW_MASK	(SVf_POK|SVf_ROK|SVp_POK|SVf_FAKE| \
                         SVf_OOK|SVf_BREAK|SVf_READONLY|SVf_PROTECT)
#endif

#define CAN_COW_FLAGS	(SVp_POK|SVf_POK)

/*
=for apidoc Am|void|SV_CHECK_THINKFIRST|SV * sv

Remove any encumbrances from C<sv>, that need to be taken care of before it
is modifiable.  For example if it is Copy on Write (COW), now is the time to
make that copy.

If you know that you are about to change the PV value of C<sv>, instead use
L</C<SV_CHECK_THINKFIRST_COW_DROP>> to avoid the write that would be
immediately written again.

=cut
*/
#define SV_CHECK_THINKFIRST(sv) if (SvTHINKFIRST(sv)) \
                                    sv_force_normal_flags(sv, 0)


/* all these 'functions' are now just macros */

#define sv_pv(sv) SvPV_nolen(sv)
#define sv_pvutf8(sv) SvPVutf8_nolen(sv)
#define sv_pvbyte(sv) SvPVbyte_nolen(sv)

#define sv_pvn_force_nomg(sv, lp) sv_pvn_force_flags(sv, lp, 0)
#define sv_utf8_upgrade_flags(sv, flags) sv_utf8_upgrade_flags_grow(sv, flags, 0)
#define sv_utf8_upgrade_nomg(sv) sv_utf8_upgrade_flags(sv, 0)
#define sv_utf8_downgrade(sv, fail_ok) sv_utf8_downgrade_flags(sv, fail_ok, SV_GMAGIC)
#define sv_utf8_downgrade_nomg(sv, fail_ok) sv_utf8_downgrade_flags(sv, fail_ok, 0)
/*
=for apidoc_defn Am|void|sv_catpvn_nomg|NN SV * const dsv               \
                                       |NULLOK const char * sstr        \
                                       |const STRLEN len
=for apidoc_defn Am|void|sv_catpv_nomg|NN SV * const dsv                \
                                      |NULLOK const char * sstr
=cut
*/
#define sv_catpvn_nomg(dsv, sstr, slen) sv_catpvn_flags(dsv, sstr, slen, 0)
#define sv_catpv_nomg(dsv, sstr) sv_catpv_flags(dsv, sstr, 0)
#define sv_setsv(dsv, ssv) \
        sv_setsv_flags(dsv, ssv, SV_GMAGIC|SV_DO_COW_SVSETSV)
/*
=for apidoc_defn Am|void|sv_setsv_nomg|SV *dsv|SV *ssv
=for apidoc_defn Am|void|sv_catsv_nomg|SV * const dsv|SV * const sstr
=cut
*/
#define sv_setsv_nomg(dsv, ssv) sv_setsv_flags(dsv, ssv, SV_DO_COW_SVSETSV)
#define sv_catsv(dsv, ssv) sv_catsv_flags(dsv, ssv, SV_GMAGIC)
#define sv_catsv_nomg(dsv, ssv) sv_catsv_flags(dsv, ssv, 0)
#define sv_catsv_mg(dsv, ssv) sv_catsv_flags(dsv, ssv, SV_GMAGIC|SV_SMAGIC)
#define sv_catpvn(dsv, sstr, slen) sv_catpvn_flags(dsv, sstr, slen, SV_GMAGIC)
#define sv_catpvn_mg(dsv, sstr, slen) sv_catpvn_flags(dsv, sstr, slen, SV_GMAGIC|SV_SMAGIC);
#define sv_copypv(dsv, ssv) sv_copypv_flags(dsv, ssv, SV_GMAGIC)
#define sv_copypv_nomg(dsv, ssv) sv_copypv_flags(dsv, ssv, 0)
#define sv_2pv(sv, lp) sv_2pv_flags(sv, lp, SV_GMAGIC)
#define sv_2pv_nolen(sv) sv_2pv(sv, 0)
#define sv_2pvbyte(sv, lp) sv_2pvbyte_flags(sv, lp, SV_GMAGIC)
#define sv_2pvbyte_nolen(sv) sv_2pvbyte(sv, 0)
#define sv_2pvutf8(sv, lp) sv_2pvutf8_flags(sv, lp, SV_GMAGIC)
#define sv_2pvutf8_nolen(sv) sv_2pvutf8(sv, 0)
#define sv_2pv_nomg(sv, lp) sv_2pv_flags(sv, lp, 0)
#define sv_pvn_force(sv, lp) sv_pvn_force_flags(sv, lp, SV_GMAGIC)
#define sv_utf8_upgrade(sv) sv_utf8_upgrade_flags(sv, SV_GMAGIC)
#define sv_2iv(sv) sv_2iv_flags(sv, SV_GMAGIC)
#define sv_2uv(sv) sv_2uv_flags(sv, SV_GMAGIC)
#define sv_2nv(sv) sv_2nv_flags(sv, SV_GMAGIC)
#define sv_eq(sv1, sv2) sv_eq_flags(sv1, sv2, SV_GMAGIC)
#define sv_cmp(sv1, sv2) sv_cmp_flags(sv1, sv2, SV_GMAGIC)
#define sv_cmp_locale(sv1, sv2) sv_cmp_locale_flags(sv1, sv2, SV_GMAGIC)
#define sv_numeq(sv1, sv2) sv_numeq_flags(sv1, sv2, SV_GMAGIC)
#define sv_streq(sv1, sv2) sv_streq_flags(sv1, sv2, SV_GMAGIC)
#define sv_collxfrm(sv, nxp) sv_collxfrm_flags(sv, nxp, SV_GMAGIC)
#define sv_2bool(sv) sv_2bool_flags(sv, SV_GMAGIC)
#define sv_2bool_nomg(sv) sv_2bool_flags(sv, 0)
#define sv_insert(bigstr, offset, len, little, littlelen)		\
        Perl_sv_insert_flags(aTHX_ (bigstr),(offset), (len), (little),	\
                             (littlelen), SV_GMAGIC)
#define sv_mortalcopy(sv) \
        Perl_sv_mortalcopy_flags(aTHX_ sv, SV_GMAGIC|SV_DO_COW_SVSETSV)
#define sv_cathek(sv,hek)					    \
        STMT_START {						     \
            HEK * const bmxk = hek;				      \
            sv_catpvn_flags(sv, HEK_KEY(bmxk), HEK_LEN(bmxk),	       \
                            HEK_UTF8(bmxk) ? SV_CATUTF8 : SV_CATBYTES); \
        } STMT_END

/* Should be named SvCatPVN_utf8_upgrade? */
#define sv_catpvn_nomg_utf8_upgrade(dsv, sstr, slen, nsv)	\
        STMT_START {					\
            if (!(nsv))					\
                nsv = newSVpvn_flags(sstr, slen, SVs_TEMP);	\
            else					\
                sv_setpvn(nsv, sstr, slen);		\
            SvUTF8_off(nsv);				\
            sv_utf8_upgrade(nsv);			\
            sv_catsv_nomg(dsv, nsv);			\
        } STMT_END

/*
=for apidoc_defn Adm|void|sv_catpvn_nomg_maybeutf8|NN SV * const dsv    \
                                                  |NN const char *sstr  \
                                                  |const STRLEN len     \
                                                  |const I32 flags
=cut
*/
#define sv_catpvn_nomg_maybeutf8(dsv, sstr, len, is_utf8) \
        sv_catpvn_flags(dsv, sstr, len, (is_utf8)?SV_CATUTF8:SV_CATBYTES)

#if defined(PERL_CORE) || defined(PERL_EXT)
# define sv_or_pv_len_utf8(sv, pv, bytelen)	      \
    (SvGAMAGIC(sv)				       \
        ? utf8_length((U8 *)(pv), (U8 *)(pv)+(bytelen))	\
        : sv_len_utf8(sv))
#endif

/*
=for apidoc         newRV
=for apidoc_item m||newRV_inc|

These are identical.  They create an RV wrapper for an SV.  The reference count
for the original SV is incremented.

=cut
*/

#define newRV_inc(sv)	newRV(sv)

/* the following macros update any magic values this C<sv> is associated with */

/*
=for apidoc_section $SV

=for apidoc Am|void|SvSETMAGIC|SV* sv
Invokes C<L</mg_set>> on an SV if it has 'set' magic.  This is necessary
after modifying a scalar, in case it is a magical variable like C<$|>
or a tied variable (it calls C<STORE>).  This macro evaluates its
argument more than once.

=for apidoc Am|void|SvSetMagicSV|SV* dsv|SV* ssv
=for apidoc_item    SvSetMagicSV_nosteal
=for apidoc_item    SvSetSV
=for apidoc_item    SvSetSV_nosteal

if C<dsv> is the same as C<ssv>, these do nothing.  Otherwise they all call
some form of C<L</sv_setsv>>.  They may evaluate their arguments more than
once.

The only differences are:

C<SvSetMagicSV> and C<SvSetMagicSV_nosteal> perform any required 'set' magic
afterwards on the destination SV; C<SvSetSV> and C<SvSetSV_nosteal> do not.

C<SvSetSV_nosteal> C<SvSetMagicSV_nosteal> call a non-destructive version of
C<sv_setsv>.

=for apidoc Am|void|SvSHARE|SV* sv
Arranges for C<sv> to be shared between threads if a suitable module
has been loaded.

=for apidoc Am|void|SvLOCK|SV* sv
Arranges for a mutual exclusion lock to be obtained on C<sv> if a suitable module
has been loaded.

=for apidoc Am|void|SvUNLOCK|SV* sv
Releases a mutual exclusion lock on C<sv> if a suitable module
has been loaded.

=for apidoc_section $SV

=for apidoc Am|char *|SvGROW|SV* sv|STRLEN len
Expands the character buffer in the SV so that it has room for the
indicated number of bytes (remember to reserve space for an extra trailing
C<NUL> character).  Calls C<sv_grow> to perform the expansion if necessary.
Returns a pointer to the character
buffer.  SV must be of type >= C<SVt_PV>.  One
alternative is to call C<sv_grow> if you are not sure of the type of SV.

You might mistakenly think that C<len> is the number of bytes to add to the
existing size, but instead it is the total size C<sv> should be.

=for apidoc Am|char *|SvPVCLEAR|SV* sv
Ensures that sv is a SVt_PV and that its SvCUR is 0, and that it is
properly null terminated. Equivalent to sv_setpvs(""), but more efficient.

=for apidoc Am|char *|SvPVCLEAR_FRESH|SV* sv

Like SvPVCLEAR, but optimized for newly-minted SVt_PV/PVIV/PVNV/PVMG
that already have a PV buffer allocated, but no SvTHINKFIRST.

=cut
*/

#define SvPVCLEAR(sv) sv_setpv_bufsize(sv,0,0)
#define SvPVCLEAR_FRESH(sv) sv_setpv_freshbuf(sv)
#define SvSHARE(sv) PL_sharehook(aTHX_ sv)
#define SvLOCK(sv) PL_lockhook(aTHX_ sv)
#define SvUNLOCK(sv) PL_unlockhook(aTHX_ sv)
#define SvDESTROYABLE(sv) PL_destroyhook(aTHX_ sv)

#define SvSETMAGIC(x) STMT_START { if (UNLIKELY(SvSMAGICAL(x))) mg_set(x); } STMT_END

#define SvSetSV_and(dst,src,finally) \
        STMT_START {					\
            SV * src_ = src;                            \
            SV * dst_ = dst;                            \
            if (LIKELY((dst_) != (src_))) {             \
                sv_setsv(dst_, src_);                   \
                finally;				\
            }						\
        } STMT_END

#define SvSetSV_nosteal_and(dst,src,finally) \
        STMT_START {					\
            SV * src_ = src;                            \
            SV * dst_ = dst;                            \
            if (LIKELY((dst_) != (src_))) {             \
                sv_setsv_flags(dst_, src_,              \
                        SV_GMAGIC                       \
                      | SV_NOSTEAL                      \
                      | SV_DO_COW_SVSETSV);             \
                finally;				\
            }						\
        } STMT_END

#define SvSetSV(dst,src) \
                SvSetSV_and(dst,src,/*nothing*/;)
#define SvSetSV_nosteal(dst,src) \
                SvSetSV_nosteal_and(dst,src,/*nothing*/;)

#define SvSetMagicSV(dst,src) \
                SvSetSV_and(dst,src,SvSETMAGIC(dst))
#define SvSetMagicSV_nosteal(dst,src) \
                SvSetSV_nosteal_and(dst,src,SvSETMAGIC(dst))


#if !defined(SKIP_DEBUGGING)
#define SvPEEK(sv) sv_peek(sv)
#else
#define SvPEEK(sv) ""
#endif

/* Is this a per-interpreter immortal SV (rather than global)?
 * These should either occupy adjacent entries in the interpreter struct
 * (MULTIPLICITY) or adjacent elements of PL_sv_immortals[] otherwise.
 * The unsigned (Size_t) cast avoids the need for a second < 0 condition.
 */
#define SvIMMORTAL_INTERP(sv) ((Size_t)((sv) - &PL_sv_yes) < 4)

/* Does this immortal have a true value? Currently only PL_sv_yes does. */
#define SvIMMORTAL_TRUE(sv)   ((sv) == &PL_sv_yes)

/* the SvREADONLY() test is to quickly reject most SVs */
#define SvIMMORTAL(sv) \
                (  SvREADONLY(sv) \
                && (SvIMMORTAL_INTERP(sv) || (sv) == &PL_sv_placeholder))

#ifdef DEBUGGING
   /* exercise the immortal resurrection code in sv_free2() */
#  ifdef PERL_RC_STACK
     /* When the stack is ref-counted, the code tends to take a lot of
      * short cuts with immortals, such as skipping the bump of the ref
      * count of PL_sv_undef when pushing it on the stack. Exercise that
      * this doesn't cause problems, especially on code which
      * special-cases RC==1 etc.
      */
#    define SvREFCNT_IMMORTAL 10
#  else
#    define SvREFCNT_IMMORTAL 1000
#  endif
#else
#  define SvREFCNT_IMMORTAL ((~(U32)0)/2)
#endif

/*
=for apidoc Am|SV *|boolSV|bool b

Returns a true SV if C<b> is a true value, or a false SV if C<b> is 0.

See also C<L</PL_sv_yes>> and C<L</PL_sv_no>>.

=cut
*/

#define boolSV(b) ((b) ? &PL_sv_yes : &PL_sv_no)

/*
=for apidoc Am|void|sv_setbool|SV *sv|bool b
=for apidoc_item |void|sv_setbool_mg|SV *sv|bool b

These set an SV to a true or false boolean value, upgrading first if necessary.

They differ only in that C<sv_setbool_mg> handles 'set' magic; C<sv_setbool>
does not.

=cut
*/

#define sv_setbool(sv, b)     sv_setsv(sv, boolSV(b))
#define sv_setbool_mg(sv, b)  sv_setsv_mg(sv, boolSV(b))

#define isGV(sv) (SvTYPE(sv) == SVt_PVGV)
/* If I give every macro argument a different name, then there won't be bugs
   where nested macros get confused. Been there, done that.  */
/*
=for apidoc Am|bool|isGV_with_GP|SV * sv
Returns a boolean as to whether or not C<sv> is a GV with a pointer to a GP
(glob pointer).

=cut
*/
#define isGV_with_GP(pwadak) \
        (((SvFLAGS(pwadak) & (SVp_POK|SVpgv_GP)) == SVpgv_GP)	\
        && (SvTYPE(pwadak) == SVt_PVGV || SvTYPE(pwadak) == SVt_PVLV))

#define isGV_with_GP_on(sv)                                            \
    STMT_START {			                               \
        SV * sv_ = MUTABLE_SV(sv);                                     \
        assert (SvTYPE(sv_) == SVt_PVGV || SvTYPE(sv_) == SVt_PVLV);   \
        assert (!SvPOKp(sv_));					       \
        assert (!SvIOKp(sv_));					       \
        (SvFLAGS(sv_) |= SVpgv_GP);				       \
    } STMT_END

#define isGV_with_GP_off(sv)                                           \
    STMT_START {                                                       \
        SV * sv_ = MUTABLE_SV(sv);                                     \
        assert (SvTYPE(sv_) == SVt_PVGV || SvTYPE(sv_) == SVt_PVLV);   \
        assert (!SvPOKp(sv_));                                         \
        assert (!SvIOKp(sv_));					       \
        (SvFLAGS(sv_) &= ~SVpgv_GP);				       \
    } STMT_END

#ifdef PERL_CORE
# define isGV_or_RVCV(kadawp) \
    (isGV(kadawp) || (SvROK(kadawp) && SvTYPE(SvRV(kadawp)) == SVt_PVCV))
#endif
#define isREGEXP(sv) \
    (SvTYPE(sv) == SVt_REGEXP				      \
     || (SvFLAGS(sv) & (SVTYPEMASK|SVpgv_GP|SVf_FAKE))        \
         == (SVt_PVLV|SVf_FAKE))


#ifdef PERL_ANY_COW
# define SvGROW(sv,len) \
        (SvIsCOW(sv) || SvLEN(sv) < (len) ? sv_grow(sv,len) : SvPVX(sv))
#else
# define SvGROW(sv,len) (SvLEN(sv) < (len) ? sv_grow(sv,len) : SvPVX(sv))
#endif
#define SvGROW_mutable(sv,len) \
    (SvLEN(sv) < (len) ? sv_grow(sv,len) : SvPVX_mutable(sv))
#define Sv_Grow sv_grow

#define CLONEf_COPY_STACKS 1
#define CLONEf_KEEP_PTR_TABLE 2
#define CLONEf_CLONE_HOST 4
#define CLONEf_JOIN_IN 8

struct clone_params {
  AV* stashes;
  UV  flags;
  PerlInterpreter *proto_perl;
  PerlInterpreter *new_perl;
  AV *unreferenced;
};

/* SV_NOSTEAL prevents TEMP buffers being, well, stolen, and saves games
   with SvTEMP_off and SvTEMP_on round a call to sv_setsv.  */
#define newSVsv(sv) newSVsv_flags((sv), SV_GMAGIC|SV_NOSTEAL)
#define newSVsv_nomg(sv) newSVsv_flags((sv), SV_NOSTEAL)

/*
=for apidoc Am|SV*|newSVpvn_utf8|const char* s|STRLEN len|U32 utf8

Creates a new SV and copies a string (which may contain C<NUL> (C<\0>)
characters) into it.  If C<utf8> is true, calls
C<SvUTF8_on> on the new SV.  Implemented as a wrapper around C<newSVpvn_flags>.

=cut
*/

#define newSVpvn_utf8(s, len, u) newSVpvn_flags((s), (len), (u) ? SVf_UTF8 : 0)

/*
=for apidoc Amx|SV*|newSVpadname|PADNAME *pn

Creates a new SV containing the pad name.

=cut
*/

#define newSVpadname(pn) newSVpvn_utf8(PadnamePV(pn), PadnameLEN(pn), TRUE)

/*
=for apidoc Am|void|SvOOK_offset|SV*sv|STRLEN len

Reads into C<len> the offset from C<SvPVX> back to the true start of the
allocated buffer, which will be non-zero if C<sv_chop> has been used to
efficiently remove characters from start of the buffer.  Implemented as a
macro, which takes the address of C<len>, which must be of type C<STRLEN>.
Evaluates C<sv> more than once.  Sets C<len> to 0 if C<SvOOK(sv)> is false.

=cut
*/

#ifdef DEBUGGING
/* Does the bot know something I don't?
10:28 <@Nicholas> metabatman
10:28 <+meta> Nicholas: crash
*/
#  define SvOOK_offset(sv, offset) STMT_START {				\
        STATIC_ASSERT_STMT(sizeof(offset) == sizeof(STRLEN));		\
        if (SvOOK(sv)) {						\
            const U8 *_crash = (U8*)SvPVX_const(sv);			\
            (offset) = *--_crash;					\
            if (!(offset)) {						\
                _crash -= sizeof(STRLEN);				\
                Copy(_crash, (U8 *)&(offset), sizeof(STRLEN), U8);	\
            }								\
            {								\
                /* Validate the preceding buffer's sentinels to		\
                   verify that no-one is using it.  */			\
                const U8 *const _bonk = (U8*)SvPVX_const(sv) - (offset);\
                while (_crash > _bonk) {				\
                    --_crash;						\
                    assert (*_crash == (U8)PTR2UV(_crash));		\
                }							\
            }								\
        } else {							\
            (offset) = 0;						\
        }								\
    } STMT_END
#else
    /* This is the same code, but avoids using any temporary variables:  */
#  define SvOOK_offset(sv, offset) STMT_START {				\
        STATIC_ASSERT_STMT(sizeof(offset) == sizeof(STRLEN));		\
        if (SvOOK(sv)) {						\
            (offset) = ((U8*)SvPVX_const(sv))[-1];			\
            if (!(offset)) {						\
                Copy(SvPVX_const(sv) - 1 - sizeof(STRLEN),		\
                     (U8*)&(offset), sizeof(STRLEN), U8);		\
            }								\
        } else {							\
            (offset) = 0;						\
        }								\
    } STMT_END
#endif

/*
=for apidoc_section $io
=for apidoc newIO

Create a new IO, setting the reference count to 1.

=cut
*/
#define newIO()	MUTABLE_IO(newSV_type(SVt_PVIO))

#if defined(PERL_CORE) || defined(PERL_EXT)

#  define SV_CONST(name) \
        PL_sv_consts[SV_CONST_##name] \
                ? PL_sv_consts[SV_CONST_##name] \
                : (PL_sv_consts[SV_CONST_##name] = newSVpv_share(#name, 0))

#  define SV_CONST_TIESCALAR 0
#  define SV_CONST_TIEARRAY 1
#  define SV_CONST_TIEHASH 2
#  define SV_CONST_TIEHANDLE 3

#  define SV_CONST_FETCH 4
#  define SV_CONST_FETCHSIZE 5
#  define SV_CONST_STORE 6
#  define SV_CONST_STORESIZE 7
#  define SV_CONST_EXISTS 8

#  define SV_CONST_PUSH 9
#  define SV_CONST_POP 10
#  define SV_CONST_SHIFT 11
#  define SV_CONST_UNSHIFT 12
#  define SV_CONST_SPLICE 13
#  define SV_CONST_EXTEND 14

#  define SV_CONST_FIRSTKEY 15
#  define SV_CONST_NEXTKEY 16
#  define SV_CONST_SCALAR 17

#  define SV_CONST_OPEN 18
#  define SV_CONST_WRITE 19
#  define SV_CONST_PRINT 20
#  define SV_CONST_PRINTF 21
#  define SV_CONST_READ 22
#  define SV_CONST_READLINE 23
#  define SV_CONST_GETC 24
#  define SV_CONST_SEEK 25
#  define SV_CONST_TELL 26
#  define SV_CONST_EOF 27
#  define SV_CONST_BINMODE 28
#  define SV_CONST_FILENO 29
#  define SV_CONST_CLOSE 30

#  define SV_CONST_DELETE 31
#  define SV_CONST_CLEAR 32
#  define SV_CONST_UNTIE 33
#  define SV_CONST_DESTROY 34
#endif

#define SV_CONSTS_COUNT 35

/*
 * Bodyless IVs and NVs!
 *
 * Since 5.9.2, we can avoid allocating a body for SVt_IV-type SVs.
 * Since the larger IV-holding variants of SVs store their integer
 * values in their respective bodies, the family of SvIV() accessor
 * macros would  naively have to branch on the SV type to find the
 * integer value either in the HEAD or BODY. In order to avoid this
 * expensive branch, a clever soul has deployed a great hack:
 * We set up the SvANY pointer such that instead of pointing to a
 * real body, it points into the memory before the location of the
 * head. We compute this pointer such that the location of
 * the integer member of the hypothetical body struct happens to
 * be the same as the location of the integer member of the bodyless
 * SV head. This now means that the SvIV() family of accessors can
 * always read from the (hypothetical or real) body via SvANY.
 *
 * Since the 5.21 dev series, we employ the same trick for NVs
 * if the architecture can support it (NVSIZE <= IVSIZE).
 */

/* The following two macros compute the necessary offsets for the above
 * trick and store them in SvANY for SvIV() (and friends) to use. */

#  define SET_SVANY_FOR_BODYLESS_IV(sv) \
    STMT_START {                                            \
        SV * sv_ = MUTABLE_SV(sv);                          \
        SvANY(sv_) =   (XPVIV*)((char*)&(sv_->sv_u.svu_iv)  \
                    - STRUCT_OFFSET(XPVIV, xiv_iv));        \
    } STMT_END

#  define SET_SVANY_FOR_BODYLESS_NV(sv) \
    STMT_START {                                            \
        SV * sv_ = MUTABLE_SV(sv);                          \
        SvANY(sv_) =   (XPVNV*)((char*)&(sv_->sv_u.svu_nv)  \
                    - STRUCT_OFFSET(XPVNV, xnv_u.xnv_nv));  \
    } STMT_END

#if defined(PERL_CORE) && defined(USE_ITHREADS)
/* Certain cases in Perl_ss_dup have been merged, by relying on the fact
   that currently av_dup, gv_dup and hv_dup are the same as sv_dup.
   If this changes, please unmerge ss_dup.
   Likewise, sv_dup_inc_multiple() relies on this fact.  */
#  define sv_dup_inc_NN(s,t)	SvREFCNT_inc_NN(sv_dup_inc(s,t))
#  define av_dup(s,t)	MUTABLE_AV(sv_dup((const SV *)s,t))
#  define av_dup_inc(s,t)	MUTABLE_AV(sv_dup_inc((const SV *)s,t))
#  define hv_dup(s,t)	MUTABLE_HV(sv_dup((const SV *)s,t))
#  define hv_dup_inc(s,t)	MUTABLE_HV(sv_dup_inc((const SV *)s,t))
#  define cv_dup(s,t)	MUTABLE_CV(sv_dup((const SV *)s,t))
#  define cv_dup_inc(s,t)	MUTABLE_CV(sv_dup_inc((const SV *)s,t))
#  define io_dup(s,t)	MUTABLE_IO(sv_dup((const SV *)s,t))
#  define io_dup_inc(s,t)	MUTABLE_IO(sv_dup_inc((const SV *)s,t))
#  define gv_dup(s,t)	MUTABLE_GV(sv_dup((const SV *)s,t))
#  define gv_dup_inc(s,t)	MUTABLE_GV(sv_dup_inc((const SV *)s,t))
#endif

/*
=for apidoc    Am|const char *|SvVSTRING       |SV* sv|STRLEN len

If the given SV has vstring magic, stores the length of it into the variable
C<len>, and returns the string pointer.  If not, returns C<NULL>.

This is a wrapper around the C<sv_vstring_get> function that conveniently
takes the address of the C<len> variable, in a form similar to the C<SvPV>
macro family.

=cut
*/

#define SvVSTRING(sv, len)  (sv_vstring_get(sv, &(len)))

/*
 * ex: set ts=8 sts=4 sw=4 et:
 */

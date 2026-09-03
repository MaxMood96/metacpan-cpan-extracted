#ifndef CS_SLOT_H
#define CS_SLOT_H 1

/* One sealed class data attribute.
 *
 * mk_classdata installs two methods per attribute, "$name" and
 * "_${name}_accessor", sharing one closure. Both are replaced by an XSUB, and
 * both XSUBs share one cs_slot, so a write through either one unseals both.
 * Two independent slots would leave the other returning the stale constant.
 *
 * Nothing here is freed. A slot lives for the life of the interpreter and
 * their number is bounded by the application's class data, which is fixed at
 * setup: seventy-two on a bare application. */

typedef struct {
    SV *value;      /* owned: the resolved value, undef included          */
    SV *orig;       /* owned: coderef of the accessor we shadowed         */
    SV *pkg;        /* owned: the sealed class name                       */
    SV *name;       /* owned: the attribute name, for messages            */
    SV *fq;         /* owned: "Pkg::name"                                 */
    SV *fq_alias;   /* owned: "Pkg::_name_accessor"                       */
    HV *stash;      /* owned: the sealed class's stash                    */
    CV *cv;         /* owned: our XSUB, kept alive across an unseal       */
    CV *cv_alias;   /* owned: likewise                                    */
    int unsealed;   /* set once a write has put the original back         */
} cs_slot;

/* One sealed attribute reader.
 *
 * Not a constant: the value is per instance. What is fixed at setup is the
 * shape, which slot the value lives in and which class the reader belongs to,
 * and that is all this needs to skip Moose's generated reader. */

typedef struct {
    SV *key;        /* owned: the hash slot name                          */
    U32 hash;       /* precomputed hash of key                            */
    SV *orig;       /* owned: coderef of the reader we shadowed           */
    SV *fq;         /* owned: "Pkg::name"                                 */
    HV *stash;      /* owned: the sealed class's stash                    */
    CV *cv;         /* owned: our XSUB                                    */
    int lazy;       /* a miss delegates instead of returning undef        */
} cs_reader;

#endif

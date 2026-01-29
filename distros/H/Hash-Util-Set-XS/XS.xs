#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef G_LIST
# define G_LIST G_ARRAY
#endif

#ifdef av_push_simple
# define my_av_push_simple av_push_simple
#else
# define my_av_push_simple av_push
#endif

static bool
THX_keys_disjoint(pTHX_ HV *x, HV *y) {
  HE *he;

  if (HvTOTALKEYS(x) > HvTOTALKEYS(y)) {
    HV *tmp = x;
    x = y;
    y = tmp;
  }

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    if (hv_exists_ent(y, hv_iterkeysv(he), HeHASH(he)))
      return FALSE;
  }
  return TRUE;
}

static bool
THX_keys_equal(pTHX_ HV *x, HV *y) {
  HE *he;

  if (HvTOTALKEYS(x) != HvTOTALKEYS(y))
    return FALSE;

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    if (!hv_exists_ent(y, hv_iterkeysv(he), HeHASH(he)))
      return FALSE;
  }
  return TRUE;
}

static bool
THX_keys_subset(pTHX_ HV *x, HV *y) {
  HE *he;

  if (HvTOTALKEYS(x) > HvTOTALKEYS(y))
    return FALSE;

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    if (!hv_exists_ent(y, hv_iterkeysv(he), HeHASH(he)))
      return FALSE;
  }
  return TRUE;
}

static bool
THX_keys_proper_subset(pTHX_ HV *x, HV *y) {
  HE *he;

  if (HvTOTALKEYS(x) >= HvTOTALKEYS(y))
    return FALSE;

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    if (!hv_exists_ent(y, hv_iterkeysv(he), HeHASH(he)))
      return FALSE;
  }
  return TRUE;
}

static IV
THX_keys_union_count(pTHX_ HV *x, HV *y) {
  HV *seen;
  HE *he;
  SV *key;

  sv_2mortal((SV *)(seen = newHV()));

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (hv_exists_ent(seen, key, HeHASH(he)))
      continue;
    (void)hv_store_ent(seen, key, &PL_sv_yes, HeHASH(he));
  }

  hv_iterinit(y);
  while ((he = hv_iternext(y))) {
    key = hv_iterkeysv(he);
    if (hv_exists_ent(seen, key, HeHASH(he)))
      continue;
    (void)hv_store_ent(seen, key, &PL_sv_yes, HeHASH(he));
  }

  return HvTOTALKEYS(seen);
}

static IV
THX_keys_intersection_count(pTHX_ HV *x, HV *y) {
  HE *he;
  SV *key;
  IV count = 0;

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (hv_exists_ent(y, key, HeHASH(he)))
      count++;
  }
  return count;
}

static IV
THX_keys_difference_count(pTHX_ HV *x, HV *y) {
  HE *he;
  SV *key;
  IV count = 0;

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(y, key, HeHASH(he)))
      count++;
  }
  return count;
}

static IV
THX_keys_symmetric_difference_count(pTHX_ HV *x, HV *y) {
  HE *he;
  SV *key;
  IV count = 0;

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(y, key, HeHASH(he)))
      count++;
  }

  hv_iterinit(y);
  while ((he = hv_iternext(y))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(x, key, HeHASH(he)))
      count++;
  }
  return count;
}

MODULE = Hash::Util::Set::XS   PACKAGE = Hash::Util::Set::XS

PROTOTYPES: ENABLE

void
keys_union(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
PREINIT:
  HV *seen;
  HE *he;
  SV *key;
PPCODE:
  if(GIMME_V != G_LIST)
    XSRETURN_IV(THX_keys_union_count(aTHX_ x, y));

  EXTEND(SP, (SSize_t)HvTOTALKEYS(x) + (SSize_t)HvTOTALKEYS(y));

  sv_2mortal((SV *)(seen = newHV()));

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
#ifdef HV_FETCH_EMPTY_HE
    he = (HE *)hv_common(seen, key, NULL, 0, 0, HV_FETCH_LVALUE|HV_FETCH_EMPTY_HE, NULL, HeHASH(he));
    if (HeVAL(he))
      continue;
    HeVAL(he) = &PL_sv_undef;
#else
    if (hv_exists_ent(seen, key, HeHASH(he)))
      continue;
    (void)hv_store_ent(seen, key, &PL_sv_yes, HeHASH(he));
#endif
    PUSHs(key);
  }

  hv_iterinit(y);
  while ((he = hv_iternext(y))) {
    key = hv_iterkeysv(he);
#ifdef HV_FETCH_EMPTY_HE
    he = (HE *)hv_common(seen, key, NULL, 0, 0, HV_FETCH_LVALUE|HV_FETCH_EMPTY_HE, NULL, HeHASH(he));
    if (HeVAL(he))
      continue;
    HeVAL(he) = &PL_sv_undef;
#else
    if (hv_exists_ent(seen, key, HeHASH(he)))
      continue;
    (void)hv_store_ent(seen, key, &PL_sv_yes, HeHASH(he));
#endif
    PUSHs(key);
  }

void
keys_intersection(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
PREINIT:
  HE *he;
  SV *key;
PPCODE:
  if(GIMME_V != G_LIST)
    XSRETURN_IV(THX_keys_intersection_count(aTHX_ x, y));

  if (HvTOTALKEYS(x) > HvTOTALKEYS(y)) {
    HV *tmp = x;
    x = y;
    y = tmp;
  }

  EXTEND(SP, (SSize_t)HvTOTALKEYS(x));

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (hv_exists_ent(y, key, HeHASH(he)))
      PUSHs(key);
  }

void
keys_difference(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
PREINIT:
  HE *he;
  SV *key;
PPCODE:
  if(GIMME_V != G_LIST)
    XSRETURN_IV(THX_keys_difference_count(aTHX_ x, y));

  EXTEND(SP, (SSize_t)HvTOTALKEYS(x));

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(y, key, HeHASH(he)))
      PUSHs(key);
  }

void
keys_symmetric_difference(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
PREINIT:
  HE *he;
  SV *key;
PPCODE:
  if(GIMME_V != G_LIST)
    XSRETURN_IV(THX_keys_symmetric_difference_count(aTHX_ x, y));

  EXTEND(SP, (SSize_t)HvTOTALKEYS(x) + (SSize_t)HvTOTALKEYS(y));

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(y, key, HeHASH(he)))
      PUSHs(key);
  }

  hv_iterinit(y);
  while ((he = hv_iternext(y))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(x, key, HeHASH(he)))
      PUSHs(key);
  }

bool
keys_disjoint(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
CODE:
  RETVAL = THX_keys_disjoint(aTHX_ x, y);
OUTPUT:
  RETVAL

bool
keys_equal(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
CODE:
  RETVAL = THX_keys_equal(aTHX_ x, y);
OUTPUT:
  RETVAL

bool
keys_subset(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
CODE:
  RETVAL = THX_keys_subset(aTHX_ x, y);
OUTPUT:
  RETVAL

bool
keys_proper_subset(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
CODE:
  RETVAL = THX_keys_proper_subset(aTHX_ x, y);
OUTPUT:
  RETVAL

bool
keys_superset(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
CODE:
  RETVAL = THX_keys_subset(aTHX_ y, x);
OUTPUT:
  RETVAL

bool
keys_proper_superset(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
CODE:
  RETVAL = THX_keys_proper_subset(aTHX_ y, x);
OUTPUT:
  RETVAL

void
keys_any(x, ...)
  HV *x
PROTOTYPE: \%@
PREINIT:
  I32 i;
PPCODE:
  for (i = 1; i < items; i++) {
    if (hv_exists_ent(x, ST(i), 0))
      XSRETURN_YES;
  }
  XSRETURN_NO;

void
keys_all(x, ...)
  HV *x
PROTOTYPE: \%@
PREINIT:
  I32 i;
PPCODE:
  for (i = 1; i < items; i++) {
    if (!hv_exists_ent(x, ST(i), 0))
      XSRETURN_NO;
  }
  XSRETURN_YES;

void
keys_none(x, ...)
  HV *x
PROTOTYPE: \%@
PREINIT:
  I32 i;
PPCODE:
  for (i = 1; i < items; i++) {
    if (hv_exists_ent(x, ST(i), 0))
      XSRETURN_NO;
  }
  XSRETURN_YES;

void
keys_partition(x, y)
  HV *x
  HV *y
PROTOTYPE: \%\%
PREINIT:
  AV *only_x, *both, *only_y;
  HE *he;
  SV *key;
PPCODE:

  sv_2mortal((SV *)(only_x = newAV()));
  sv_2mortal((SV *)(both = newAV()));
  sv_2mortal((SV *)(only_y = newAV()));

  hv_iterinit(x);
  while ((he = hv_iternext(x))) {
    key = hv_iterkeysv(he);
    if (hv_exists_ent(y, key, HeHASH(he)))
      my_av_push_simple(both, SvREFCNT_inc(key));
    else
      my_av_push_simple(only_x, SvREFCNT_inc(key));
  }

  hv_iterinit(y);
  while ((he = hv_iternext(y))) {
    key = hv_iterkeysv(he);
    if (!hv_exists_ent(x, key, HeHASH(he)))
      my_av_push_simple(only_y, SvREFCNT_inc(key));
  }
  
  EXTEND(SP, 3);
  PUSHs(sv_2mortal(newRV_inc((SV *)only_x)));
  PUSHs(sv_2mortal(newRV_inc((SV *)both)));
  PUSHs(sv_2mortal(newRV_inc((SV *)only_y)));


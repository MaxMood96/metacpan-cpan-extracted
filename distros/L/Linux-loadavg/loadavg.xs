#ifndef __linux
#error "No linux. Compile aborted."
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "stdlib.h"

/* VERSION: 0.15 */

MODULE = Linux::loadavg		PACKAGE = Linux::loadavg		

void
loadavg(...)
PROTOTYPE: ;$
PREINIT:
   double loadavg[3];
   int     rc, i;
   int     nelem;
PPCODE:
   if (items == 0) {
     nelem = 3;
   } else {
     nelem = atoi(SvPV_nolen(ST(0)));
   }
   if (nelem > 3 || nelem < 1)
      croak("invalid nelem (%d)", nelem);
   if ((rc = getloadavg(loadavg, nelem)) != nelem)
      croak("getloadavg failed (%d)", rc);
   EXTEND(SP,nelem);
   for(i=0; i<nelem; i++) {
     PUSHs(sv_2mortal(newSVnv(loadavg[i])));
   }

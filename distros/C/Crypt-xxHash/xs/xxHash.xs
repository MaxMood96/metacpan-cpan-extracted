// PERL_NO_GET_CONTEXT is not used here, so it's OK to define it after inculding these files
#include "EXTERN.h"
#include "perl.h"

// There are a lot of macro about threads: USE_ITHREADS, USE_5005THREADS, I_PTHREAD, I_MACH_CTHREADS, OLD_PTHREADS_API
// This symbol, if defined, indicates that Perl should be built to use the interpreter-based threading implementation.
#ifndef USE_ITHREADS
#   define PERL_NO_GET_CONTEXT
#endif

#include "XSUB.h"
#include "ppport.h"

#ifdef I_PTHREAD
#   include "pthread.h"
#endif

#ifdef I_MACH_CTHREADS
#   include "mach/cthreads.h"
#endif


/* define int64_t and uint64_t when using MinGW compiler */
#ifdef __MINGW32__
#include <stdint.h>
#endif

/* define int64_t and uint64_t when using MS compiler */
#ifdef _MSC_VER
#include <stdlib.h>
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
#endif

#include "xxhash.h"
#include <inttypes.h>
#include <stdio.h>

#ifdef HAS_INT64_T
#endif

#ifdef CPP
using namespace std;
#endif

static int
canceller_free (pTHX_ SV *cv, MAGIC *mg)
{
    XXH64_freeState((XXH64_state_t*)mg->mg_ptr);
    return 0;
}
static MGVTBL canceller_vtbl = {
    0, 0, 0, 0,
    canceller_free
};

MODULE = Crypt::xxHash  PACKAGE = Crypt::xxHash 

PROTOTYPES: DISABLE

U32
xxhash32( const char *input, int length(input), UV seed )
    CODE:
#ifdef CPP
        RETVAL = XXH32(input, STRLEN_length_of_input, move(seed));
#else
        RETVAL = XXH32(input, STRLEN_length_of_input, seed);
#endif
    OUTPUT:
        RETVAL

UV
xxhash64( const char *input, int length(input), UV seed )
    CODE:
#ifdef CPP
        RETVAL = (UV) XXH64(input, STRLEN_length_of_input, move(seed));
#else
        RETVAL = (UV) XXH64(input, STRLEN_length_of_input, seed);
#endif
    OUTPUT:
        RETVAL

UV
xxhash3_64bits( const char *input, int length(input), UV seed )
    CODE:
#ifdef CPP
        RETVAL = (UV) XXH3_64bits_withSeed(input, STRLEN_length_of_input, move(seed));
#else
        RETVAL = (UV) XXH3_64bits_withSeed(input, STRLEN_length_of_input, seed);
#endif
    OUTPUT:
        RETVAL

char*
xxhash32_hex ( const char *input, int length(input), UV seed )
    CODE:
        static char value32[9];
        static const char *format = "%08x";
#ifdef CPP
        sprintf(value32, format, (uint32_t) XXH32(input, STRLEN_length_of_input, move(seed)) );
#else
        sprintf(value32, format, (uint32_t) XXH32(input, STRLEN_length_of_input, seed) );
#endif
        RETVAL = value32;
    OUTPUT:
        RETVAL

char*
xxhash64_hex( const char *input, int length(input), UV seed )
    CODE:
        static char value64[17];
        static const char *format = "%016" PRIx64;
#ifdef CPP
        sprintf(value64, format, (uint64_t) XXH64(input, STRLEN_length_of_input, move(seed)) );
#else
        sprintf(value64, format, (uint64_t) XXH64(input, STRLEN_length_of_input, seed) );
#endif
        RETVAL = value64;
    OUTPUT:
        RETVAL

char*
xxhash3_64bits_hex( const char *input, int length(input), UV seed )
    CODE:
        static char value64[17];
        static const char *format = "%016" PRIx64;
#ifdef CPP
        sprintf(value64, format, (uint64_t) XXH3_64bits_withSeed(input, STRLEN_length_of_input, move(seed)) );
#else
        sprintf(value64, format, (uint64_t) XXH3_64bits_withSeed(input, STRLEN_length_of_input, seed) );
#endif
        RETVAL = value64;
    OUTPUT:
        RETVAL

char*
xxhash3_128bits_hex( const char *input, int length(input), UV seed )
    CODE:
        static char value64[33];
        static const char *format = "%016" PRIx64 "%016" PRIx64;
#ifdef CPP
        XXH128_hash_t hash = XXH3_128bits_withSeed(input, STRLEN_length_of_input, move(seed));
#else
        XXH128_hash_t hash = XXH3_128bits_withSeed(input, STRLEN_length_of_input, seed);
#endif
        sprintf(value64, format, (uint64_t) hash.high64, (uint64_t) hash.low64 );
        RETVAL = value64;
    OUTPUT:
        RETVAL

void
xxhash3_64bits_stream( UV seed )
    PPCODE:
        XXH64_state_t * state = XXH64_createState();
        if( !state )
            croak("Allocate 64bits xxHash state failed.");
        if( XXH64_reset(state, seed) == XXH_ERROR )
            croak("Initialize 64bits xxHash state failed.");
        SV *canceller = NEWSV(0, 0);
        SvUPGRADE(canceller, SVt_PVMG);
        sv_magicext(canceller, NULL, PERL_MAGIC_ext, &canceller_vtbl, (const char*)state, 0);
        mPUSHs(newRV_noinc(canceller));

void
xxhash3_64bits_stream_update(SV * state_RV, SV * data_SV)
    PPCODE:
        if( !SvROK(state_RV) )
            croak("This is not a 64bits xxHash state variable.");
        MAGIC * mg = mg_findext(SvRV(state_RV), PERL_MAGIC_ext, &canceller_vtbl);
        if( !mg )
            croak("This is not a 64bits xxHash state variable.");
        STRLEN len;
        char * buf = SvPV(data_SV, len);
        if( XXH64_update((XXH64_state_t*)mg->mg_ptr, buf, len) == XXH_ERROR )
            croak("Update 64bits xxHash state failed.");

void
xxhash3_64bits_stream_digest(SV * state_RV)
    PPCODE:
        dXSTARG;
        if( !SvROK(state_RV) )
            croak("This is not a 64bits xxHash state variable.");
        MAGIC * mg = mg_findext(SvRV(state_RV), PERL_MAGIC_ext, &canceller_vtbl);
        if( !mg )
            croak("This is not a 64bits xxHash state variable.");

        PUSHu((UV) XXH64_digest((XXH64_state_t*)mg->mg_ptr));

void
xxhash3_64bits_stream_digest_hex(SV * state_RV)
    PPCODE:
        if( !SvROK(state_RV) )
            croak("This is not a 64bits xxHash state variable.");
        MAGIC * mg = mg_findext(SvRV(state_RV), PERL_MAGIC_ext, &canceller_vtbl);
        if( !mg )
            croak("This is not a 64bits xxHash state variable.");

        mPUSHs(newSVpvf("%016" PRIx64, (uint64_t)XXH64_digest((XXH64_state_t*)mg->mg_ptr)));

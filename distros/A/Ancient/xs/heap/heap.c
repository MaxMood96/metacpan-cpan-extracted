/*
 * heap.c - Ultra-fast binary heap (priority queue)
 *
 * Three API levels for different speed/convenience tradeoffs:
 *
 * 1. RAW ARRAY API (fastest - matches Array::Heap speed)
 *    push_heap_min(\@array, $val)
 *    pop_heap_min(\@array)
 *    make_heap_min(\@array)  # O(n) Floyd's heapify
 *
 * 2. NUMERIC HEAP (very fast - stores NV directly, no SV overhead)
 *    my $h = heap::new_nv('min');
 *    $h->push(3.14);  # No SV allocation
 *    $h->pop;         # Returns NV directly
 *
 * 3. OO HEAP (convenient - stores any Perl values)
 *    my $h = heap::new('min');
 *    $h->push($anything);
 *
 * Optimizations:
 * - Custom ops bypass method dispatch
 * - Inlined comparison for min/max heaps
 * - Floyd's O(n) heapify for bulk operations
 * - Zero-copy returns where possible
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "heap_compat.h"

/* ============================================
   Heap type enum
   ============================================ */
typedef enum {
    HEAP_MIN = 0,
    HEAP_MAX = 1
} HeapType;

/* ============================================
   Standard Heap structure (stores SV*)
   ============================================ */
typedef struct {
    SV **data;
    IV size;
    IV capacity;
    HeapType type;
    SV *comparator;
} Heap;

/* ============================================
   Numeric Heap structure (stores NV directly)
   ============================================ */
typedef struct {
    NV *data;
    IV size;
    IV capacity;
    HeapType type;
} NumericHeap;

/* ============================================
   Custom op declarations
   ============================================ */
static XOP heap_push_xop;
static XOP heap_pop_xop;
static XOP heap_peek_xop;
static XOP heap_size_xop;

static XOP heap_func_push_xop;
static XOP heap_func_pop_xop;
static XOP heap_func_peek_xop;
static XOP heap_func_size_xop;

/* Raw array ops */
static XOP push_heap_min_xop;
static XOP pop_heap_min_xop;
static XOP push_heap_max_xop;
static XOP pop_heap_max_xop;

/* Numeric heap ops */
static XOP nv_push_xop;
static XOP nv_pop_xop;
static XOP nv_peek_xop;

/* Method-to-op optimization */
static Perl_check_t orig_entersub_check;

/* ============================================
   Magic vtables
   ============================================ */
static int heap_free(pTHX_ SV *sv, MAGIC *mg);
static int numeric_heap_free(pTHX_ SV *sv, MAGIC *mg);

static MGVTBL heap_vtbl = {
    NULL, NULL, NULL, NULL,
    heap_free,
    NULL, NULL, NULL
};

static MGVTBL numeric_heap_vtbl = {
    NULL, NULL, NULL, NULL,
    numeric_heap_free,
    NULL, NULL, NULL
};

/* ============================================
   Get structures from blessed SV
   ============================================ */
#define GET_HEAP_MAGIC(obj) mg_find(SvRV(obj), PERL_MAGIC_ext)

static Heap* get_heap(pTHX_ SV *obj) {
    MAGIC *mg;
    if (!SvROK(obj)) croak("Not a reference");
    mg = mg_find(SvRV(obj), PERL_MAGIC_ext);
    while (mg) {
        if (mg->mg_virtual == &heap_vtbl) {
            return (Heap*)mg->mg_ptr;
        }
        mg = mg->mg_moremagic;
    }
    croak("Not a heap object");
    return NULL;
}

static NumericHeap* get_numeric_heap(pTHX_ SV *obj) {
    MAGIC *mg;
    if (!SvROK(obj)) croak("Not a reference");
    mg = mg_find(SvRV(obj), PERL_MAGIC_ext);
    while (mg) {
        if (mg->mg_virtual == &numeric_heap_vtbl) {
            return (NumericHeap*)mg->mg_ptr;
        }
        mg = mg->mg_moremagic;
    }
    croak("Not a numeric heap object");
    return NULL;
}

/* Try to get numeric heap, return NULL if not a numeric heap */
static NumericHeap* try_get_numeric_heap(pTHX_ SV *obj) {
    MAGIC *mg;
    if (!SvROK(obj)) return NULL;
    mg = mg_find(SvRV(obj), PERL_MAGIC_ext);
    while (mg) {
        if (mg->mg_virtual == &numeric_heap_vtbl) {
            return (NumericHeap*)mg->mg_ptr;
        }
        mg = mg->mg_moremagic;
    }
    return NULL;
}

/* ============================================
   PART 1: RAW ARRAY API (fastest)
   Operates directly on Perl arrays
   ============================================ */

/* Sift up for raw array - min heap */
static void raw_sift_up_min(pTHX_ AV *av, IV idx) {
    SV **arr = AvARRAY(av);
    SV *val = arr[idx];
    NV val_nv = SvNV(val);

    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        NV parent_nv = SvNV(arr[parent]);
        if (val_nv < parent_nv) {
            arr[idx] = arr[parent];
            idx = parent;
        } else {
            break;
        }
    }
    arr[idx] = val;
}

/* Sift up for raw array - max heap */
static void raw_sift_up_max(pTHX_ AV *av, IV idx) {
    SV **arr = AvARRAY(av);
    SV *val = arr[idx];
    NV val_nv = SvNV(val);

    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        NV parent_nv = SvNV(arr[parent]);
        if (val_nv > parent_nv) {
            arr[idx] = arr[parent];
            idx = parent;
        } else {
            break;
        }
    }
    arr[idx] = val;
}

/* Sift down for raw array - min heap */
static void raw_sift_down_min(pTHX_ AV *av, IV idx, IV size) {
    SV **arr = AvARRAY(av);
    SV *val = arr[idx];
    NV val_nv = SvNV(val);
    IV half = size >> 1;

    while (idx < half) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = left;
        NV best_nv = SvNV(arr[left]);

        if (right < size) {
            NV right_nv = SvNV(arr[right]);
            if (right_nv < best_nv) {
                best = right;
                best_nv = right_nv;
            }
        }

        if (best_nv < val_nv) {
            arr[idx] = arr[best];
            idx = best;
        } else {
            break;
        }
    }
    arr[idx] = val;
}

/* Sift down for raw array - max heap */
static void raw_sift_down_max(pTHX_ AV *av, IV idx, IV size) {
    SV **arr = AvARRAY(av);
    SV *val = arr[idx];
    NV val_nv = SvNV(val);
    IV half = size >> 1;

    while (idx < half) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = left;
        NV best_nv = SvNV(arr[left]);

        if (right < size) {
            NV right_nv = SvNV(arr[right]);
            if (right_nv > best_nv) {
                best = right;
                best_nv = right_nv;
            }
        }

        if (best_nv > val_nv) {
            arr[idx] = arr[best];
            idx = best;
        } else {
            break;
        }
    }
    arr[idx] = val;
}

/* push_heap_min(\@array, $value) */
XS_EXTERNAL(XS_push_heap_min) {
    dXSARGS;
    AV *av;
    SV *val;
    IV size;

    if (items != 2) croak("Usage: push_heap_min(\\@array, $value)");
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("First argument must be an array reference");
    }

    av = (AV*)SvRV(ST(0));
    val = newSVsv(ST(1));

    av_push(av, val);
    size = av_len(av) + 1;
    raw_sift_up_min(aTHX_ av, size - 1);

    XSRETURN_EMPTY;
}

/* push_heap_max(\@array, $value) */
XS_EXTERNAL(XS_push_heap_max) {
    dXSARGS;
    AV *av;
    SV *val;
    IV size;

    if (items != 2) croak("Usage: push_heap_max(\\@array, $value)");
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("First argument must be an array reference");
    }

    av = (AV*)SvRV(ST(0));
    val = newSVsv(ST(1));

    av_push(av, val);
    size = av_len(av) + 1;
    raw_sift_up_max(aTHX_ av, size - 1);

    XSRETURN_EMPTY;
}

/* pop_heap_min(\@array) */
XS_EXTERNAL(XS_pop_heap_min) {
    dXSARGS;
    AV *av;
    IV size;
    SV *result;
    SV **arr;

    if (items != 1) croak("Usage: pop_heap_min(\\@array)");
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("First argument must be an array reference");
    }

    av = (AV*)SvRV(ST(0));
    size = av_len(av) + 1;

    if (size == 0) XSRETURN_UNDEF;

    arr = AvARRAY(av);
    result = arr[0];

    if (size > 1) {
        arr[0] = arr[size - 1];
        AvFILLp(av) = size - 2;
        raw_sift_down_min(aTHX_ av, 0, size - 1);
    } else {
        AvFILLp(av) = -1;
    }

    ST(0) = sv_2mortal(result);
    XSRETURN(1);
}

/* pop_heap_max(\@array) */
XS_EXTERNAL(XS_pop_heap_max) {
    dXSARGS;
    AV *av;
    IV size;
    SV *result;
    SV **arr;

    if (items != 1) croak("Usage: pop_heap_max(\\@array)");
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("First argument must be an array reference");
    }

    av = (AV*)SvRV(ST(0));
    size = av_len(av) + 1;

    if (size == 0) XSRETURN_UNDEF;

    arr = AvARRAY(av);
    result = arr[0];

    if (size > 1) {
        arr[0] = arr[size - 1];
        AvFILLp(av) = size - 2;
        raw_sift_down_max(aTHX_ av, 0, size - 1);
    } else {
        AvFILLp(av) = -1;
    }

    ST(0) = sv_2mortal(result);
    XSRETURN(1);
}

/* make_heap_min(\@array) - Floyd's O(n) heapify */
XS_EXTERNAL(XS_make_heap_min) {
    dXSARGS;
    AV *av;
    IV size, i;

    if (items != 1) croak("Usage: make_heap_min(\\@array)");
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("First argument must be an array reference");
    }

    av = (AV*)SvRV(ST(0));
    size = av_len(av) + 1;

    /* Floyd's algorithm: sift down from middle to root */
    for (i = (size >> 1) - 1; i >= 0; i--) {
        raw_sift_down_min(aTHX_ av, i, size);
    }

    XSRETURN_EMPTY;
}

/* make_heap_max(\@array) - Floyd's O(n) heapify */
XS_EXTERNAL(XS_make_heap_max) {
    dXSARGS;
    AV *av;
    IV size, i;

    if (items != 1) croak("Usage: make_heap_max(\\@array)");
    if (!SvROK(ST(0)) || SvTYPE(SvRV(ST(0))) != SVt_PVAV) {
        croak("First argument must be an array reference");
    }

    av = (AV*)SvRV(ST(0));
    size = av_len(av) + 1;

    for (i = (size >> 1) - 1; i >= 0; i--) {
        raw_sift_down_max(aTHX_ av, i, size);
    }

    XSRETURN_EMPTY;
}

/* ============================================
   PART 2: NUMERIC HEAP (stores NV directly)
   ============================================ */

static void nv_ensure_capacity(NumericHeap *h, IV needed) {
    if (needed > h->capacity) {
        IV new_cap = h->capacity ? h->capacity * 2 : 16;
        while (new_cap < needed) new_cap *= 2;
        Renew(h->data, new_cap, NV);
        h->capacity = new_cap;
    }
}

/* Sift up for NV min-heap */
static void nv_sift_up_min(NumericHeap *h, IV idx) {
    NV *data = h->data;
    NV val = data[idx];

    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        if (val < data[parent]) {
            data[idx] = data[parent];
            idx = parent;
        } else {
            break;
        }
    }
    data[idx] = val;
}

/* Sift up for NV max-heap */
static void nv_sift_up_max(NumericHeap *h, IV idx) {
    NV *data = h->data;
    NV val = data[idx];

    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        if (val > data[parent]) {
            data[idx] = data[parent];
            idx = parent;
        } else {
            break;
        }
    }
    data[idx] = val;
}

/* Sift down for NV min-heap */
static void nv_sift_down_min(NumericHeap *h, IV idx) {
    NV *data = h->data;
    IV size = h->size;
    NV val = data[idx];
    IV half = size >> 1;

    while (idx < half) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = left;
        NV best_nv = data[left];

        if (right < size && data[right] < best_nv) {
            best = right;
            best_nv = data[right];
        }

        if (best_nv < val) {
            data[idx] = data[best];
            idx = best;
        } else {
            break;
        }
    }
    data[idx] = val;
}

/* Sift down for NV max-heap */
static void nv_sift_down_max(NumericHeap *h, IV idx) {
    NV *data = h->data;
    IV size = h->size;
    NV val = data[idx];
    IV half = size >> 1;

    while (idx < half) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = left;
        NV best_nv = data[left];

        if (right < size && data[right] > best_nv) {
            best = right;
            best_nv = data[right];
        }

        if (best_nv > val) {
            data[idx] = data[best];
            idx = best;
        } else {
            break;
        }
    }
    data[idx] = val;
}

static int numeric_heap_free(pTHX_ SV *sv, MAGIC *mg) {
    NumericHeap *h = (NumericHeap*)mg->mg_ptr;
    PERL_UNUSED_ARG(sv);
    if (h->data) Safefree(h->data);
    Safefree(h);
    return 0;
}

/* heap::new_nv($type) - create numeric heap */
XS_EXTERNAL(XS_heap_new_nv) {
    dXSARGS;
    NumericHeap *h;
    SV *obj_sv, *rv;
    HV *stash;
    HeapType type = HEAP_MIN;
    int arg_offset = 0;

    if (items >= 1 && SvPOK(ST(0))) {
        STRLEN len;
        const char *str = SvPV(ST(0), len);
        if (len == 4 && strEQ(str, "heap")) {
            arg_offset = 1;
        } else if (len == 3 && (strEQ(str, "min") || strEQ(str, "max"))) {
            arg_offset = 0;
        } else {
            arg_offset = 1;
        }
    }

    if (items > arg_offset) {
        STRLEN len;
        const char *type_str = SvPV(ST(arg_offset), len);
        if (len == 3 && strEQ(type_str, "max")) {
            type = HEAP_MAX;
        }
    }

    Newxz(h, 1, NumericHeap);
    h->type = type;
    h->size = 0;
    h->capacity = 16;
    Newx(h->data, 16, NV);

    obj_sv = newSV(0);
    sv_magicext(obj_sv, NULL, PERL_MAGIC_ext, &numeric_heap_vtbl, (char*)h, 0);

    rv = newRV_noinc(obj_sv);
    stash = gv_stashpvn("heap::nv", 8, GV_ADD);
    sv_bless(rv, stash);

    ST(0) = sv_2mortal(rv);
    XSRETURN(1);
}

/* $nv_heap->push($value) */
XS_EXTERNAL(XS_nv_push) {
    dXSARGS;
    NumericHeap *h;
    NV val;

    if (items != 2) croak("Usage: $heap->push($value)");

    h = get_numeric_heap(aTHX_ ST(0));
    val = SvNV(ST(1));

    nv_ensure_capacity(h, h->size + 1);
    h->data[h->size] = val;
    h->size++;

    if (h->type == HEAP_MIN) {
        nv_sift_up_min(h, h->size - 1);
    } else {
        nv_sift_up_max(h, h->size - 1);
    }

    ST(0) = ST(0);
    XSRETURN(1);
}

/* $nv_heap->push_all(@values) - with Floyd's heapify */
XS_EXTERNAL(XS_nv_push_all) {
    dXSARGS;
    NumericHeap *h;
    int i;
    IV start_size;

    if (items < 1) croak("Usage: $heap->push_all(@values)");

    h = get_numeric_heap(aTHX_ ST(0));
    start_size = h->size;

    nv_ensure_capacity(h, h->size + items - 1);

    /* Add all values first */
    for (i = 1; i < items; i++) {
        h->data[h->size++] = SvNV(ST(i));
    }

    /* Floyd's heapify on the new portion if significant */
    if (items - 1 > 10) {
        /* Full Floyd's heapify */
        IV j;
        for (j = (h->size >> 1) - 1; j >= 0; j--) {
            if (h->type == HEAP_MIN) {
                nv_sift_down_min(h, j);
            } else {
                nv_sift_down_max(h, j);
            }
        }
    } else {
        /* Just sift up each new element */
        for (i = start_size; i < h->size; i++) {
            if (h->type == HEAP_MIN) {
                nv_sift_up_min(h, i);
            } else {
                nv_sift_up_max(h, i);
            }
        }
    }

    ST(0) = ST(0);
    XSRETURN(1);
}

/* $nv_heap->pop() */
XS_EXTERNAL(XS_nv_pop) {
    dXSARGS;
    NumericHeap *h;
    NV result;

    if (items != 1) croak("Usage: $heap->pop()");

    h = get_numeric_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_UNDEF;

    result = h->data[0];
    h->size--;

    if (h->size > 0) {
        h->data[0] = h->data[h->size];
        if (h->type == HEAP_MIN) {
            nv_sift_down_min(h, 0);
        } else {
            nv_sift_down_max(h, 0);
        }
    }

    ST(0) = sv_2mortal(newSVnv(result));
    XSRETURN(1);
}

/* $nv_heap->peek() */
XS_EXTERNAL(XS_nv_peek) {
    dXSARGS;
    NumericHeap *h;

    if (items != 1) croak("Usage: $heap->peek()");

    h = get_numeric_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_UNDEF;

    ST(0) = sv_2mortal(newSVnv(h->data[0]));
    XSRETURN(1);
}

/* $nv_heap->size() */
XS_EXTERNAL(XS_nv_size) {
    dXSARGS;
    NumericHeap *h;

    if (items != 1) croak("Usage: $heap->size()");

    h = get_numeric_heap(aTHX_ ST(0));
    XSRETURN_IV(h->size);
}

/* $nv_heap->is_empty() */
XS_EXTERNAL(XS_nv_is_empty) {
    dXSARGS;
    NumericHeap *h;

    if (items != 1) croak("Usage: $heap->is_empty()");

    h = get_numeric_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_YES;
    XSRETURN_NO;
}

/* $nv_heap->clear() */
XS_EXTERNAL(XS_nv_clear) {
    dXSARGS;
    NumericHeap *h;

    if (items != 1) croak("Usage: $heap->clear()");

    h = get_numeric_heap(aTHX_ ST(0));
    h->size = 0;

    XSRETURN_EMPTY;
}

/* ============================================
   PART 3: STANDARD HEAP (original OO API)
   ============================================ */

static void heap_ensure_capacity(Heap *h, IV needed) {
    if (needed > h->capacity) {
        IV new_cap = h->capacity ? h->capacity * 2 : 16;
        while (new_cap < needed) new_cap *= 2;
        Renew(h->data, new_cap, SV*);
        h->capacity = new_cap;
    }
}

/* Sift functions for standard heap */
static void heap_sift_up_min(Heap *h, IV idx) {
    SV **data = h->data;
    SV *val = data[idx];
    NV val_nv = SvNV(val);

    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        if (val_nv < SvNV(data[parent])) {
            data[idx] = data[parent];
            idx = parent;
        } else {
            break;
        }
    }
    data[idx] = val;
}

static void heap_sift_up_max(Heap *h, IV idx) {
    SV **data = h->data;
    SV *val = data[idx];
    NV val_nv = SvNV(val);

    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        if (val_nv > SvNV(data[parent])) {
            data[idx] = data[parent];
            idx = parent;
        } else {
            break;
        }
    }
    data[idx] = val;
}

static void heap_sift_down_min(Heap *h, IV idx) {
    SV **data = h->data;
    IV size = h->size;
    SV *val = data[idx];
    NV val_nv = SvNV(val);
    IV half = size >> 1;

    while (idx < half) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = left;
        NV best_nv = SvNV(data[left]);

        if (right < size) {
            NV right_nv = SvNV(data[right]);
            if (right_nv < best_nv) {
                best = right;
                best_nv = right_nv;
            }
        }

        if (best_nv < val_nv) {
            data[idx] = data[best];
            idx = best;
        } else {
            break;
        }
    }
    data[idx] = val;
}

static void heap_sift_down_max(Heap *h, IV idx) {
    SV **data = h->data;
    IV size = h->size;
    SV *val = data[idx];
    NV val_nv = SvNV(val);
    IV half = size >> 1;

    while (idx < half) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = left;
        NV best_nv = SvNV(data[left]);

        if (right < size) {
            NV right_nv = SvNV(data[right]);
            if (right_nv > best_nv) {
                best = right;
                best_nv = right_nv;
            }
        }

        if (best_nv > val_nv) {
            data[idx] = data[best];
            idx = best;
        } else {
            break;
        }
    }
    data[idx] = val;
}

/* Custom comparator sift operations */
static bool heap_compare_custom(pTHX_ Heap *h, SV *a, SV *b) {
    dSP;
    IV result;
    int count;

    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(a);
    XPUSHs(b);
    PUTBACK;

    count = call_sv(h->comparator, G_SCALAR);

    SPAGAIN;
    if (count != 1) croak("Comparator must return exactly one value");
    result = POPi;
    PUTBACK;
    FREETMPS; LEAVE;

    return h->type == HEAP_MIN ? result < 0 : result > 0;
}

static void heap_sift_up_custom(pTHX_ Heap *h, IV idx) {
    while (idx > 0) {
        IV parent = (idx - 1) >> 1;
        if (heap_compare_custom(aTHX_ h, h->data[idx], h->data[parent])) {
            SV *tmp = h->data[idx];
            h->data[idx] = h->data[parent];
            h->data[parent] = tmp;
            idx = parent;
        } else {
            break;
        }
    }
}

static void heap_sift_down_custom(pTHX_ Heap *h, IV idx) {
    while (1) {
        IV left = (idx << 1) + 1;
        IV right = left + 1;
        IV best = idx;

        if (left < h->size && heap_compare_custom(aTHX_ h, h->data[left], h->data[best])) {
            best = left;
        }
        if (right < h->size && heap_compare_custom(aTHX_ h, h->data[right], h->data[best])) {
            best = right;
        }

        if (best != idx) {
            SV *tmp = h->data[idx];
            h->data[idx] = h->data[best];
            h->data[best] = tmp;
            idx = best;
        } else {
            break;
        }
    }
}

static void heap_sift_up(pTHX_ Heap *h, IV idx) {
    if (h->comparator) {
        heap_sift_up_custom(aTHX_ h, idx);
    } else if (h->type == HEAP_MIN) {
        heap_sift_up_min(h, idx);
    } else {
        heap_sift_up_max(h, idx);
    }
}

static void heap_sift_down(pTHX_ Heap *h, IV idx) {
    if (h->comparator) {
        heap_sift_down_custom(aTHX_ h, idx);
    } else if (h->type == HEAP_MIN) {
        heap_sift_down_min(h, idx);
    } else {
        heap_sift_down_max(h, idx);
    }
}

static int heap_free(pTHX_ SV *sv, MAGIC *mg) {
    Heap *h = (Heap*)mg->mg_ptr;
    IV i;
    PERL_UNUSED_ARG(sv);

    for (i = 0; i < h->size; i++) {
        if (h->data[i]) SvREFCNT_dec(h->data[i]);
    }
    if (h->comparator) SvREFCNT_dec(h->comparator);
    if (h->data) Safefree(h->data);
    Safefree(h);
    return 0;
}

/* Custom OP implementations - handle both regular and numeric heaps */
static OP* pp_heap_push(pTHX) {
    dSP;
    SV *val_sv = POPs;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        NV val = SvNV(val_sv);
        nv_ensure_capacity(nh, nh->size + 1);
        nh->data[nh->size] = val;
        nh->size++;
        if (nh->type == HEAP_MIN) {
            nv_sift_up_min(nh, nh->size - 1);
        } else {
            nv_sift_up_max(nh, nh->size - 1);
        }
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);
    SV *value = newSVsv(val_sv);

    heap_ensure_capacity(h, h->size + 1);
    h->data[h->size] = value;
    h->size++;
    heap_sift_up(aTHX_ h, h->size - 1);

    RETURN;
}

static OP* pp_heap_pop(pTHX) {
    dSP;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        if (nh->size == 0) {
            SETs(&PL_sv_undef);
            RETURN;
        }
        NV result = nh->data[0];
        nh->size--;
        if (nh->size > 0) {
            nh->data[0] = nh->data[nh->size];
            if (nh->type == HEAP_MIN) {
                nv_sift_down_min(nh, 0);
            } else {
                nv_sift_down_max(nh, 0);
            }
        }
        SETs(sv_2mortal(newSVnv(result)));
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);

    if (h->size == 0) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    SV *result = sv_mortalcopy(h->data[0]);
    SvREFCNT_dec(h->data[0]);

    h->size--;
    if (h->size > 0) {
        h->data[0] = h->data[h->size];
        heap_sift_down(aTHX_ h, 0);
    }

    SETs(result);
    RETURN;
}

static OP* pp_heap_peek(pTHX) {
    dSP;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        if (nh->size == 0) {
            SETs(&PL_sv_undef);
        } else {
            SETs(sv_2mortal(newSVnv(nh->data[0])));
        }
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);

    if (h->size == 0) {
        SETs(&PL_sv_undef);
    } else {
        SETs(h->data[0]);
    }
    RETURN;
}

static OP* pp_heap_size(pTHX) {
    dSP;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        SETs(sv_2mortal(newSViv(nh->size)));
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);

    SETs(sv_2mortal(newSViv(h->size)));
    RETURN;
}

/* Function-style custom ops */
static OP* pp_heap_func_push(pTHX) {
    dSP;
    SV *val_sv = TOPs;
    SV *heap_sv = TOPm1s;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        NV val = SvNV(val_sv);
        nv_ensure_capacity(nh, nh->size + 1);
        nh->data[nh->size] = val;
        nh->size++;
        if (nh->type == HEAP_MIN) {
            nv_sift_up_min(nh, nh->size - 1);
        } else {
            nv_sift_up_max(nh, nh->size - 1);
        }
        SP--;
        SETs(heap_sv);
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);
    SV *value = newSVsv(val_sv);

    heap_ensure_capacity(h, h->size + 1);
    h->data[h->size] = value;
    h->size++;
    heap_sift_up(aTHX_ h, h->size - 1);

    SP--;
    SETs(heap_sv);
    RETURN;
}

static OP* pp_heap_func_pop(pTHX) {
    dSP;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        if (nh->size == 0) {
            SETs(&PL_sv_undef);
            RETURN;
        }
        NV result = nh->data[0];
        nh->size--;
        if (nh->size > 0) {
            nh->data[0] = nh->data[nh->size];
            if (nh->type == HEAP_MIN) {
                nv_sift_down_min(nh, 0);
            } else {
                nv_sift_down_max(nh, 0);
            }
        }
        SETs(sv_2mortal(newSVnv(result)));
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);

    if (h->size == 0) {
        SETs(&PL_sv_undef);
        RETURN;
    }

    SV *result = sv_mortalcopy(h->data[0]);
    SvREFCNT_dec(h->data[0]);

    h->size--;
    if (h->size > 0) {
        h->data[0] = h->data[h->size];
        heap_sift_down(aTHX_ h, 0);
    }

    SETs(result);
    RETURN;
}

static OP* pp_heap_func_peek(pTHX) {
    dSP;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        SETs(nh->size > 0 ? sv_2mortal(newSVnv(nh->data[0])) : &PL_sv_undef);
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);
    SETs(h->size > 0 ? h->data[0] : &PL_sv_undef);
    RETURN;
}

static OP* pp_heap_func_size(pTHX) {
    dSP;
    SV *heap_sv = TOPs;

    /* Check for numeric heap first */
    NumericHeap *nh = try_get_numeric_heap(aTHX_ heap_sv);
    if (nh) {
        SETs(sv_2mortal(newSViv(nh->size)));
        RETURN;
    }

    /* Regular heap */
    Heap *h = get_heap(aTHX_ heap_sv);
    SETs(sv_2mortal(newSViv(h->size)));
    RETURN;
}

/* ============================================
   Method-to-op optimization via PL_check hook
   ============================================ */

/* Forward declarations */
static OP* pp_heap_push(pTHX);
static OP* pp_heap_pop(pTHX);
static OP* pp_heap_peek(pTHX);
static OP* pp_heap_size(pTHX);

/*
 * Intercept OP_ENTERSUB at compile time.
 * If it's a method_named call for push/pop/peek/size on a heap,
 * replace with custom op.
 *
 * Tree structure for $h->push(5):
 *   entersub-+-pushmark
 *            |-padsv[$h]        <- heap
 *            |-const[IV 5]      <- value (for 2-arg methods)
 *            `-method_named[PV "push"]
 */
static OP* heap_entersub_check(pTHX_ OP *entersubop) {
    OP *pushop, *firstarg, *methop, *prevop;
    const char *meth_name;
    STRLEN meth_len;
    OP *heapop, *valop = NULL;
    OP *newop;
    OP *(*ppfunc)(pTHX) = NULL;
    bool is_2arg = FALSE;
    int nargs = 0;

    /* Only for ENTERSUB ops */
    if (entersubop->op_type != OP_ENTERSUB)
        return orig_entersub_check(aTHX_ entersubop);

    /* Navigate to first child - might be wrapped in ex-list */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop))
        pushop = cUNOPx(pushop)->op_first;

    /* pushop should be pushmark, first sibling is first argument */
    if (pushop->op_type != OP_PUSHMARK)
        return orig_entersub_check(aTHX_ entersubop);

    firstarg = OpSIBLING(pushop);
    if (!firstarg)
        return orig_entersub_check(aTHX_ entersubop);

    /* Walk to find method_named - it's the last sibling */
    prevop = pushop;
    methop = firstarg;
    while (OpHAS_SIBLING(methop)) {
        prevop = methop;
        methop = OpSIBLING(methop);
        nargs++;
    }

    /* Must end with method_named */
    if (methop->op_type != OP_METHOD_NAMED)
        return orig_entersub_check(aTHX_ entersubop);

    /* Get method name */
#if PERL_VERSION_GE(5,22,0)
    meth_name = SvPV_const(cMETHOPx_meth(methop), meth_len);
#else
    meth_name = SvPV_const(cSVOPx(methop)->op_sv, meth_len);
#endif

    /* Check if it's one of our methods */
    if (meth_len == 4 && strEQ(meth_name, "push")) {
        ppfunc = pp_heap_push;
        is_2arg = TRUE;
    } else if (meth_len == 3 && strEQ(meth_name, "pop")) {
        ppfunc = pp_heap_pop;
        is_2arg = FALSE;
    } else if (meth_len == 4 && strEQ(meth_name, "peek")) {
        ppfunc = pp_heap_peek;
        is_2arg = FALSE;
    } else if (meth_len == 4 && strEQ(meth_name, "size")) {
        ppfunc = pp_heap_size;
        is_2arg = FALSE;
    } else {
        return orig_entersub_check(aTHX_ entersubop);
    }

    /* Verify argument count: 1 arg for 1-arg methods, 2 for 2-arg */
    if (is_2arg && nargs != 2)
        return orig_entersub_check(aTHX_ entersubop);
    if (!is_2arg && nargs != 1)
        return orig_entersub_check(aTHX_ entersubop);

    /* Extract ops:
     * For 1-arg: firstarg is heap
     * For 2-arg: firstarg is heap, OpSIBLING(firstarg) is value
     */
    heapop = firstarg;

    if (is_2arg) {
        valop = OpSIBLING(heapop);

        /* Unlink heap and val from chain */
        OpMORESIB_set(pushop, methop);
        OpLASTSIB_set(heapop, NULL);
        OpLASTSIB_set(valop, NULL);

        newop = newBINOP(OP_CUSTOM, 0, heapop, valop);
        newop->op_ppaddr = ppfunc;
    } else {
        /* Unlink heap from chain */
        OpMORESIB_set(pushop, methop);
        OpLASTSIB_set(heapop, NULL);

        newop = newUNOP(OP_CUSTOM, 0, heapop);
        newop->op_ppaddr = ppfunc;
    }

    op_free(entersubop);
    return newop;
}

/* Call checkers */
typedef OP* (*heap_ppfunc)(pTHX);

static OP* heap_call_checker_1arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    heap_ppfunc ppfunc = (heap_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *heapop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) pushop = cUNOPx(pushop)->op_first;

    heapop = OpSIBLING(pushop);
    if (!heapop) return entersubop;

    cvop = OpSIBLING(heapop);
    if (!cvop) return entersubop;
    if (OpSIBLING(heapop) != cvop) return entersubop;

    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(heapop, NULL);

    newop = newUNOP(OP_CUSTOM, 0, heapop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

static OP* heap_call_checker_2arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    heap_ppfunc ppfunc = (heap_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *heapop, *valop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) pushop = cUNOPx(pushop)->op_first;

    heapop = OpSIBLING(pushop);
    if (!heapop) return entersubop;

    valop = OpSIBLING(heapop);
    if (!valop) return entersubop;

    cvop = OpSIBLING(valop);
    if (!cvop) return entersubop;
    if (OpSIBLING(valop) != cvop) return entersubop;

    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(valop, NULL);
    OpLASTSIB_set(heapop, NULL);

    newop = newBINOP(OP_CUSTOM, 0, heapop, valop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

static OP* heap_func_call_checker_1arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    return heap_call_checker_1arg(aTHX_ entersubop, namegv, ckobj);
}

static OP* heap_func_call_checker_2arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    return heap_call_checker_2arg(aTHX_ entersubop, namegv, ckobj);
}

/* XS Functions */
XS_EXTERNAL(XS_heap_new) {
    dXSARGS;
    Heap *h;
    SV *obj_sv, *rv;
    HV *stash;
    HeapType type = HEAP_MIN;
    SV *comparator = NULL;
    int arg_offset = 0;

    if (items >= 1 && SvPOK(ST(0))) {
        STRLEN len;
        const char *str = SvPV(ST(0), len);
        if (len == 4 && strEQ(str, "heap")) {
            arg_offset = 1;
        } else if (len == 3 && (strEQ(str, "min") || strEQ(str, "max"))) {
            arg_offset = 0;
        } else {
            arg_offset = 1;
        }
    }

    if (items > arg_offset) {
        STRLEN len;
        const char *type_str = SvPV(ST(arg_offset), len);
        if (len == 3 && strEQ(type_str, "max")) {
            type = HEAP_MAX;
        } else if (len == 3 && strEQ(type_str, "min")) {
            type = HEAP_MIN;
        } else {
            croak("heap type must be 'min' or 'max'");
        }
    }

    if (items > arg_offset + 1) {
        SV *cmp_arg = ST(arg_offset + 1);
        if (SvROK(cmp_arg) && SvTYPE(SvRV(cmp_arg)) == SVt_PVCV) {
            comparator = newSVsv(cmp_arg);
        } else if (SvOK(cmp_arg)) {
            croak("Comparator must be a code reference");
        }
    }

    Newxz(h, 1, Heap);
    h->type = type;
    h->size = 0;
    h->capacity = 0;
    h->data = NULL;
    h->comparator = comparator;

    obj_sv = newSV(0);
    sv_magicext(obj_sv, NULL, PERL_MAGIC_ext, &heap_vtbl, (char*)h, 0);

    rv = newRV_noinc(obj_sv);
    stash = gv_stashpvn("heap", 4, GV_ADD);
    sv_bless(rv, stash);

    ST(0) = sv_2mortal(rv);
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_push) {
    dXSARGS;
    Heap *h;
    SV *value;

    if (items != 2) croak("Usage: $heap->push($value)");

    h = get_heap(aTHX_ ST(0));
    value = newSVsv(ST(1));

    heap_ensure_capacity(h, h->size + 1);
    h->data[h->size] = value;
    h->size++;
    heap_sift_up(aTHX_ h, h->size - 1);

    ST(0) = ST(0);
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_push_all) {
    dXSARGS;
    Heap *h;
    int i;
    IV start_size;

    if (items < 1) croak("Usage: $heap->push_all(@values)");

    h = get_heap(aTHX_ ST(0));
    start_size = h->size;

    heap_ensure_capacity(h, h->size + items - 1);

    /* Add all values first */
    for (i = 1; i < items; i++) {
        h->data[h->size++] = newSVsv(ST(i));
    }

    /* Floyd's heapify if adding many elements */
    if (items - 1 > 10) {
        IV j;
        for (j = (h->size >> 1) - 1; j >= 0; j--) {
            heap_sift_down(aTHX_ h, j);
        }
    } else {
        for (i = start_size; i < h->size; i++) {
            heap_sift_up(aTHX_ h, i);
        }
    }

    ST(0) = ST(0);
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_pop) {
    dXSARGS;
    Heap *h;
    SV *result;

    if (items != 1) croak("Usage: $heap->pop()");

    h = get_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_UNDEF;

    result = sv_mortalcopy(h->data[0]);
    SvREFCNT_dec(h->data[0]);

    h->size--;
    if (h->size > 0) {
        h->data[0] = h->data[h->size];
        heap_sift_down(aTHX_ h, 0);
    }

    ST(0) = result;
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_peek) {
    dXSARGS;
    Heap *h;

    if (items != 1) croak("Usage: $heap->peek()");

    h = get_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_UNDEF;

    ST(0) = h->data[0];
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_size) {
    dXSARGS;
    Heap *h;

    if (items != 1) croak("Usage: $heap->size()");

    h = get_heap(aTHX_ ST(0));
    XSRETURN_IV(h->size);
}

XS_EXTERNAL(XS_heap_is_empty) {
    dXSARGS;
    Heap *h;

    if (items != 1) croak("Usage: $heap->is_empty()");

    h = get_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_YES;
    XSRETURN_NO;
}

XS_EXTERNAL(XS_heap_clear) {
    dXSARGS;
    Heap *h;
    IV i;

    if (items != 1) croak("Usage: $heap->clear()");

    h = get_heap(aTHX_ ST(0));

    for (i = 0; i < h->size; i++) {
        if (h->data[i]) SvREFCNT_dec(h->data[i]);
    }
    h->size = 0;

    XSRETURN_EMPTY;
}

XS_EXTERNAL(XS_heap_type) {
    dXSARGS;
    Heap *h;

    if (items != 1) croak("Usage: $heap->type()");

    h = get_heap(aTHX_ ST(0));

    if (h->type == HEAP_MIN) {
        ST(0) = sv_2mortal(newSVpvn("min", 3));
    } else {
        ST(0) = sv_2mortal(newSVpvn("max", 3));
    }
    XSRETURN(1);
}

/* Function-style XS fallbacks */
XS_EXTERNAL(XS_heap_func_push) {
    dXSARGS;
    if (items != 2) croak("Usage: heap_push($heap, $value)");
    Heap *h = get_heap(aTHX_ ST(0));
    SV *value = newSVsv(ST(1));

    heap_ensure_capacity(h, h->size + 1);
    h->data[h->size] = value;
    h->size++;
    heap_sift_up(aTHX_ h, h->size - 1);

    ST(0) = ST(0);
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_func_pop) {
    dXSARGS;
    if (items != 1) croak("Usage: heap_pop($heap)");
    Heap *h = get_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_UNDEF;

    SV *result = sv_mortalcopy(h->data[0]);
    SvREFCNT_dec(h->data[0]);

    h->size--;
    if (h->size > 0) {
        h->data[0] = h->data[h->size];
        heap_sift_down(aTHX_ h, 0);
    }

    ST(0) = result;
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_func_peek) {
    dXSARGS;
    if (items != 1) croak("Usage: heap_peek($heap)");
    Heap *h = get_heap(aTHX_ ST(0));

    if (h->size == 0) XSRETURN_UNDEF;
    ST(0) = h->data[0];
    XSRETURN(1);
}

XS_EXTERNAL(XS_heap_func_size) {
    dXSARGS;
    if (items != 1) croak("Usage: heap_size($heap)");
    Heap *h = get_heap(aTHX_ ST(0));
    XSRETURN_IV(h->size);
}

/* Import functions */
static void install_heap_func_1arg(pTHX_ const char *pkg, const char *name,
                                    XSUBADDR_t xsub, heap_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);
    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, heap_func_call_checker_1arg, ckobj);
}

static void install_heap_func_2arg(pTHX_ const char *pkg, const char *name,
                                    XSUBADDR_t xsub, heap_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);
    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, heap_func_call_checker_2arg, ckobj);
}

XS_EXTERNAL(XS_heap_import) {
    dXSARGS;
    const char *pkg;
    int i;
    bool want_import = FALSE;
    bool want_raw = FALSE;

    pkg = CopSTASHPV(PL_curcop);

    for (i = 1; i < items; i++) {
        STRLEN len;
        const char *arg = SvPV(ST(i), len);
        if (len == 6 && strEQ(arg, "import")) {
            want_import = TRUE;
        } else if (len == 3 && strEQ(arg, "raw")) {
            want_raw = TRUE;
        }
    }

    if (want_import) {
        install_heap_func_2arg(aTHX_ pkg, "heap_push", XS_heap_func_push, pp_heap_func_push);
        install_heap_func_1arg(aTHX_ pkg, "heap_pop", XS_heap_func_pop, pp_heap_func_pop);
        install_heap_func_1arg(aTHX_ pkg, "heap_peek", XS_heap_func_peek, pp_heap_func_peek);
        install_heap_func_1arg(aTHX_ pkg, "heap_size", XS_heap_func_size, pp_heap_func_size);
    }

    if (want_raw) {
        /* Install raw array functions */
        char full_name[256];
        snprintf(full_name, sizeof(full_name), "%s::push_heap_min", pkg);
        newXS(full_name, XS_push_heap_min, __FILE__);
        snprintf(full_name, sizeof(full_name), "%s::pop_heap_min", pkg);
        newXS(full_name, XS_pop_heap_min, __FILE__);
        snprintf(full_name, sizeof(full_name), "%s::push_heap_max", pkg);
        newXS(full_name, XS_push_heap_max, __FILE__);
        snprintf(full_name, sizeof(full_name), "%s::pop_heap_max", pkg);
        newXS(full_name, XS_pop_heap_max, __FILE__);
        snprintf(full_name, sizeof(full_name), "%s::make_heap_min", pkg);
        newXS(full_name, XS_make_heap_min, __FILE__);
        snprintf(full_name, sizeof(full_name), "%s::make_heap_max", pkg);
        newXS(full_name, XS_make_heap_max, __FILE__);
    }

    XSRETURN_EMPTY;
}

/* ============================================
   Boot function
   ============================================ */

XS_EXTERNAL(boot_heap) {
    dXSBOOTARGSXSAPIVERCHK;
    PERL_UNUSED_VAR(items);

    /* Register custom ops */
    XopENTRY_set(&heap_push_xop, xop_name, "heap_push");
    XopENTRY_set(&heap_push_xop, xop_desc, "heap push");
    Perl_custom_op_register(aTHX_ pp_heap_push, &heap_push_xop);

    XopENTRY_set(&heap_pop_xop, xop_name, "heap_pop");
    XopENTRY_set(&heap_pop_xop, xop_desc, "heap pop");
    Perl_custom_op_register(aTHX_ pp_heap_pop, &heap_pop_xop);

    XopENTRY_set(&heap_peek_xop, xop_name, "heap_peek");
    XopENTRY_set(&heap_peek_xop, xop_desc, "heap peek");
    Perl_custom_op_register(aTHX_ pp_heap_peek, &heap_peek_xop);

    XopENTRY_set(&heap_size_xop, xop_name, "heap_size");
    XopENTRY_set(&heap_size_xop, xop_desc, "heap size");
    Perl_custom_op_register(aTHX_ pp_heap_size, &heap_size_xop);

    XopENTRY_set(&heap_func_push_xop, xop_name, "heap_func_push");
    XopENTRY_set(&heap_func_push_xop, xop_desc, "heap function push");
    Perl_custom_op_register(aTHX_ pp_heap_func_push, &heap_func_push_xop);

    XopENTRY_set(&heap_func_pop_xop, xop_name, "heap_func_pop");
    XopENTRY_set(&heap_func_pop_xop, xop_desc, "heap function pop");
    Perl_custom_op_register(aTHX_ pp_heap_func_pop, &heap_func_pop_xop);

    XopENTRY_set(&heap_func_peek_xop, xop_name, "heap_func_peek");
    XopENTRY_set(&heap_func_peek_xop, xop_desc, "heap function peek");
    Perl_custom_op_register(aTHX_ pp_heap_func_peek, &heap_func_peek_xop);

    XopENTRY_set(&heap_func_size_xop, xop_name, "heap_func_size");
    XopENTRY_set(&heap_func_size_xop, xop_desc, "heap function size");
    Perl_custom_op_register(aTHX_ pp_heap_func_size, &heap_func_size_xop);

    /* Register XS subs with call checkers */
    {
        CV *cv;
        SV *ckobj;

        /* Standard heap */
        newXS("heap::new", XS_heap_new, __FILE__);

        cv = newXS("heap::push", XS_heap_push, __FILE__);
        ckobj = newSViv(PTR2IV(pp_heap_push));
        cv_set_call_checker(cv, heap_call_checker_2arg, ckobj);

        newXS("heap::push_all", XS_heap_push_all, __FILE__);

        cv = newXS("heap::pop", XS_heap_pop, __FILE__);
        ckobj = newSViv(PTR2IV(pp_heap_pop));
        cv_set_call_checker(cv, heap_call_checker_1arg, ckobj);

        cv = newXS("heap::peek", XS_heap_peek, __FILE__);
        ckobj = newSViv(PTR2IV(pp_heap_peek));
        cv_set_call_checker(cv, heap_call_checker_1arg, ckobj);

        cv = newXS("heap::size", XS_heap_size, __FILE__);
        ckobj = newSViv(PTR2IV(pp_heap_size));
        cv_set_call_checker(cv, heap_call_checker_1arg, ckobj);

        newXS("heap::is_empty", XS_heap_is_empty, __FILE__);
        newXS("heap::clear", XS_heap_clear, __FILE__);
        newXS("heap::type", XS_heap_type, __FILE__);
        newXS("heap::import", XS_heap_import, __FILE__);

        /* Numeric heap */
        newXS("heap::new_nv", XS_heap_new_nv, __FILE__);
        newXS("heap::nv::push", XS_nv_push, __FILE__);
        newXS("heap::nv::push_all", XS_nv_push_all, __FILE__);
        newXS("heap::nv::pop", XS_nv_pop, __FILE__);
        newXS("heap::nv::peek", XS_nv_peek, __FILE__);
        newXS("heap::nv::size", XS_nv_size, __FILE__);
        newXS("heap::nv::is_empty", XS_nv_is_empty, __FILE__);
        newXS("heap::nv::clear", XS_nv_clear, __FILE__);

        /* Raw array functions */
        newXS("heap::push_heap_min", XS_push_heap_min, __FILE__);
        newXS("heap::pop_heap_min", XS_pop_heap_min, __FILE__);
        newXS("heap::push_heap_max", XS_push_heap_max, __FILE__);
        newXS("heap::pop_heap_max", XS_pop_heap_max, __FILE__);
        newXS("heap::make_heap_min", XS_make_heap_min, __FILE__);
        newXS("heap::make_heap_max", XS_make_heap_max, __FILE__);
    }

    /* Install PL_check hook for method-to-op optimization */
    orig_entersub_check = PL_check[OP_ENTERSUB];
    PL_check[OP_ENTERSUB] = heap_entersub_check;

#if PERL_VERSION_GE(5,22,0)
    Perl_xs_boot_epilog(aTHX_ ax);
#else
    XSRETURN_YES;
#endif
}

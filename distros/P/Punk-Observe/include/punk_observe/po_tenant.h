/* po_tenant.h - the tenant seam, kept honest.
 *
 * Phase 0 rooted every path at the store root and put the tenant id in every
 * segment header, so this engine is single-tenant in POLICY and never in
 * PATH. This file does not resolve tenants - that is the hosted product's
 * job. It keeps the seam from rotting in the meantime.
 *
 * THE DEFAULT IS A CONSTANT, WHICH IS THE POINT.
 *
 * The self-hosted shape is the whole shape: one tenant, named by
 * configuration, resolved by returning it. The hosted shape is the same code
 * with a callback. If the constant case went through a different path than
 * the callback case, the hosted deployment would be a rewrite rather than a
 * configuration, and everything the seam was built for would be spent.
 *
 * A TENANT ID IS NEVER TAKEN FROM ANYTHING A CLIENT CAN INFLUENCE.
 *
 * Not a header, not a query parameter, not a path segment. That is not a
 * check performed here; it is the absence of a function that would do it. A
 * code path that reads a tenant from a request cannot be added later by
 * accident if it was never written, and this file is where somebody would go
 * looking for one.
 *
 * So the only two sources are a configured constant and a host callback, and
 * whatever either produces is validated against the same fixed character
 * class before a single byte of it reaches a path.
 */
#ifndef PO_TENANT_H
#define PO_TENANT_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_store.h"
#include "punk_observe/po_hash.h"

#define PO_TN_OK        0
#define PO_TN_EMPTY     1
#define PO_TN_TOO_LONG  2
#define PO_TN_BAD_CHAR  3
#define PO_TN_TRAVERSAL 4

static const char *po_tn_reason(int rc) {
    switch (rc) {
        case PO_TN_OK:        return "ok";
        case PO_TN_EMPTY:     return "a tenant id cannot be empty";
        case PO_TN_TOO_LONG:  return "a tenant id is at most 64 characters";
        case PO_TN_BAD_CHAR:  return "a tenant id is [A-Za-z0-9_-] only";
        case PO_TN_TRAVERSAL: return "a tenant id cannot be . or ..";
        default:              return "refused";
    }
}

/* The boundary check, with a REASON.
 *
 * `po_tenant_ok` in po_store.h answers yes or no, which is all a path
 * builder needs. A resolver that returned something unusable deserves to be
 * told which rule it broke: the person debugging it wrote the resolver, and
 * "invalid tenant" is not a bug report.
 *
 * `.` and `..` are called out separately even though the character class
 * already excludes the dot. The class is the check; naming traversal is what
 * makes the intent survive somebody widening the class later. */
static int po_tenant_check(const char *id, size_t len) {
    size_t i;
    if (!id || !len) return PO_TN_EMPTY;
    if (len > PO_TENANT_MAX) return PO_TN_TOO_LONG;
    if ((len == 1 && id[0] == '.')
        || (len == 2 && id[0] == '.' && id[1] == '.')) return PO_TN_TRAVERSAL;
    for (i = 0; i < len; i++) {
        char c = id[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
              || (c >= '0' && c <= '9') || c == '_' || c == '-'))
            return PO_TN_BAD_CHAR;
    }
    return PO_TN_OK;
}

/* ---- the resolver ---------------------------------------------------------
 *
 * A callback, or NULL for the constant. Both go through po_tenant_resolve,
 * so the validation is on one path rather than on two that can drift. */
typedef int (*po_tenant_fn)(void *ud, const char **out, size_t *len);

typedef struct {
    char         fixed[PO_TENANT_MAX + 1];
    size_t       fixed_len;
    po_tenant_fn fn;
    void        *ud;
    int          last_rc;
} po_tenant_cfg;

/* Configure the constant. Refused here rather than at first use, so a typo in
 * a config file is a boot failure and not a runtime one. */
static int po_tenant_set_fixed(po_tenant_cfg *c, const char *id, size_t len) {
    int rc;
    memset(c, 0, sizeof(*c));
    if (!id || !len) { id = PO_TENANT_DEFAULT; len = strlen(PO_TENANT_DEFAULT); }
    rc = po_tenant_check(id, len);
    if (rc != PO_TN_OK) { c->last_rc = rc; return rc; }
    memcpy(c->fixed, id, len);
    c->fixed[len] = '\0';
    c->fixed_len  = len;
    return PO_TN_OK;
}

static void po_tenant_set_fn(po_tenant_cfg *c, po_tenant_fn fn, void *ud) {
    c->fn = fn;
    c->ud = ud;
}

/* Resolve, then validate. In that order and never the reverse: a resolver is
 * host code, and host code that returns `../other` is a bug this must catch
 * rather than trust. */
static int po_tenant_resolve(po_tenant_cfg *c, char *out, size_t cap,
                             size_t *out_len) {
    const char *id = NULL;
    size_t len = 0;
    int rc;

    if (c->fn) {
        if (!c->fn(c->ud, &id, &len) || !id) {
            c->last_rc = PO_TN_EMPTY;
            return PO_TN_EMPTY;
        }
    }
    else { id = c->fixed; len = c->fixed_len; }

    rc = po_tenant_check(id, len);
    c->last_rc = rc;
    if (rc != PO_TN_OK) return rc;
    if (len + 1 > cap) { c->last_rc = PO_TN_TOO_LONG; return PO_TN_TOO_LONG; }

    memcpy(out, id, len);
    out[len] = '\0';
    if (out_len) *out_len = len;
    return PO_TN_OK;
}

/* ---- the segment header check ---------------------------------------------
 *
 * A segment carries a hash of the tenant it belongs to. Checked when the file
 * is OPENED, not when its contents are served: a mis-filed segment found at
 * open is an error, and one found after it has been read is a disclosure that
 * already happened. */
static uint32_t po_tenant_hash(const char *id, size_t len) {
    return po_hash32(id, len);
}

static int po_tenant_owns(uint32_t header_hash, const char *id, size_t len) {
    return header_hash == po_tenant_hash(id, len);
}

#endif /* PO_TENANT_H */

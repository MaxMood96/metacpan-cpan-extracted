/* po_store.h - the root, and the tenant boundary.
 *
 * The engine is single-tenant. The hosted site is multi-tenant. The whole
 * difference has to be ONE argument resolved at the top, or the site is a
 * rewrite rather than a deployment.
 *
 * So every path the store constructs is rooted at po_store->root, and a
 * multi-tenant deployment sets root = $data/<tenant_id>. There is no tenant
 * column in a segment, no tenant field in po_rec, and no tenant predicate in
 * a query.
 *
 * THIS IS A SECURITY DECISION, NOT A LAYOUT PREFERENCE. A tenant column means
 * every query in the executor must remember to filter on it, and the one that
 * forgets serves another customer's telemetry. A directory means a query for
 * tenant A physically has no file handle that reaches tenant B's data. The
 * failure mode of the column design is silent cross-tenant disclosure; the
 * failure mode of this one is a missing directory.
 */
#ifndef PO_STORE_H
#define PO_STORE_H

#include "punk_observe/po_compat.h"

#define PO_TENANT_MAX 64
#define PO_PATH_MAX  4096

/* The default tenant, used when no resolver is configured. A self-hosted
 * install on a private network should not need an ingest key, and this is
 * what makes "no key" a supported configuration rather than a hole. */
#define PO_TENANT_DEFAULT "default"

typedef struct {
    char root[PO_PATH_MAX];     /* $data, or $data/<tenant_id> */
    char tenant[PO_TENANT_MAX + 1];
} po_store;

/* A tenant id is an opaque token and nothing else: [A-Za-z0-9_-]{1,64}.
 *
 * The allowlist is deliberate. A denylist here would have to know about "..",
 * "/", "\", NUL, percent-encoding, overlong UTF-8 and whatever the next
 * traversal trick is; an allowlist knows about none of them and refuses them
 * all. Note especially that a backslash is refused even though it is not a
 * separator on POSIX, because browsers fold it to one and the reflected-bytes
 * class of bug has already cost this ecosystem a CVE.
 *
 * Returns 1 if the id is acceptable. It is checked BEFORE any path is
 * constructed - a validated id is the only thing that reaches a buffer. */
static int po_tenant_ok(const char *id, size_t len) {
    size_t i;
    if (!id || len == 0 || len > PO_TENANT_MAX) return 0;
    for (i = 0; i < len; i++) {
        char c = id[i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '_' || c == '-') continue;
        return 0;
    }
    /* "." and ".." are refused by the character class already, but a leading
     * dot would still make a hidden directory, which is a surprise nobody
     * needs. The class excludes '.' entirely, so this is belt and braces for
     * a future edit that widens it. */
    if (id[0] == '.') return 0;
    return 1;
}

/* Resolve a store root. `data` is the configured directory; `tenant` is NULL
 * or empty for single-tenant, in which case the root IS `data` and no
 * per-tenant directory is created.
 *
 * Returns 1 on success, 0 if the tenant id is refused or the path would not
 * fit. A refusal never leaves a partially built root behind. */
static int po_store_init(po_store *s, const char *data,
                         const char *tenant, size_t tlen) {
    size_t dlen;
    if (!s || !data) return 0;
    dlen = strlen(data);
    if (dlen == 0 || dlen >= PO_PATH_MAX) return 0;

    memset(s, 0, sizeof(*s));

    if (!tenant || tlen == 0) {
        memcpy(s->tenant, PO_TENANT_DEFAULT, sizeof(PO_TENANT_DEFAULT));
        memcpy(s->root, data, dlen);
        s->root[dlen] = '\0';
        return 1;
    }

    if (!po_tenant_ok(tenant, tlen)) { memset(s, 0, sizeof(*s)); return 0; }
    if (dlen + 1 + tlen >= PO_PATH_MAX) { memset(s, 0, sizeof(*s)); return 0; }

    memcpy(s->tenant, tenant, tlen);
    s->tenant[tlen] = '\0';

    memcpy(s->root, data, dlen);
    s->root[dlen] = '/';
    memcpy(s->root + dlen + 1, tenant, tlen);
    s->root[dlen + 1 + tlen] = '\0';
    return 1;
}

/* Build a path under the store root. `rel` is written by this distribution
 * and is never user input; the tenant component was validated in
 * po_store_init and is the only thing here that ever came from outside.
 *
 * Returns the length written, or 0 if it would not fit. */
static size_t po_store_path(const po_store *s, const char *rel,
                            char *out, size_t outlen) {
    size_t rlen, len;
    if (!s || !rel || !out) return 0;
    rlen = strlen(s->root);
    len  = strlen(rel);
    if (rlen + 1 + len >= outlen) return 0;
    memcpy(out, s->root, rlen);
    out[rlen] = '/';
    memcpy(out + rlen + 1, rel, len);
    out[rlen + 1 + len] = '\0';
    return rlen + 1 + len;
}

#endif /* PO_STORE_H */

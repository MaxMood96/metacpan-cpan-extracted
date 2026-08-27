/* po_target.h - where a webhook is allowed to point.
 *
 * A WEBHOOK URL IS ATTACKER-INFLUENCED INPUT, AND FETCHING IT IS AN SSRF.
 *
 * The server makes a request to a URL a user typed into a form. On a cloud
 * instance that is a request from inside the perimeter, and the classic
 * target is the metadata service on 169.254.169.254, which hands out
 * credentials to anything that asks from the right place. Loopback reaches
 * whatever else is bound on the box - an admin port, a database, this
 * process.
 *
 * So the destination is validated BEFORE the request, and the default is
 * refusal: loopback, link-local, the private ranges, and anything that is not
 * plain http or https. An operator who genuinely needs an internal target
 * adds it to an allowlist, which is a decision somebody made rather than a
 * default nobody noticed.
 *
 * THIS IS NOT A COMPLETE SSRF DEFENCE AND DOES NOT PRETEND TO BE. A hostname
 * that resolves to a private address defeats any check made on the string,
 * which is why the policy is also applied to the ADDRESS at connect time by
 * the caller. What this file does is refuse the literal cases, which is the
 * majority of them, and refuse them where an operator can see the reason.
 */
#ifndef PO_TARGET_H
#define PO_TARGET_H

#include "punk_observe/po_compat.h"

#define PO_TGT_OK          0
#define PO_TGT_BAD_SCHEME  1
#define PO_TGT_LOOPBACK    2
#define PO_TGT_LINK_LOCAL  3
#define PO_TGT_PRIVATE     4
#define PO_TGT_MALFORMED   5
#define PO_TGT_NOT_ALLOWED 6

#define PO_TGT_HOST_MAX 256

/* Own case fold, not strncasecmp: that one lives in strings.h on POSIX and
 * nowhere on MSVC, and it is locale-sensitive besides. A scheme comparison
 * must not depend on a locale. */
static int po_ascii_ncase(const char *a, const char *b, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) {
        unsigned char x = (unsigned char)a[i], y = (unsigned char)b[i];
        if (x >= 'A' && x <= 'Z') x = (unsigned char)(x - 'A' + 'a');
        if (y >= 'A' && y <= 'Z') y = (unsigned char)(y - 'A' + 'a');
        if (x != y) return x < y ? -1 : 1;
        if (!x) return 0;
    }
    return 0;
}

static const char *po_tgt_reason(int rc) {
    switch (rc) {
        case PO_TGT_OK:          return "ok";
        case PO_TGT_BAD_SCHEME:  return "only http and https are allowed";
        case PO_TGT_LOOPBACK:    return "loopback addresses are refused";
        case PO_TGT_LINK_LOCAL:  return "link-local addresses are refused";
        case PO_TGT_PRIVATE:     return "private addresses are refused";
        case PO_TGT_MALFORMED:   return "that is not a URL";
        case PO_TGT_NOT_ALLOWED: return "not on the allowlist";
        default:                 return "refused";
    }
}

/* Pull the host out of a URL, lowercased, without the port or the brackets
 * around a literal IPv6 address. */
static int po_tgt_host(const char *url, size_t len, char *out, size_t cap,
                       int *is_v6) {
    size_t i = 0, n = 0;
    int v6 = 0;

    *is_v6 = 0;
    if (len > 7 && po_ascii_ncase(url, "http://", 7) == 0) i = 7;
    else if (len > 8 && po_ascii_ncase(url, "https://", 8) == 0) i = 8;
    else return PO_TGT_BAD_SCHEME;

    /* Userinfo. `http://metadata@127.0.0.1/` puts a decoy before the @, and a
     * parser that stops at the first delimiter reads the decoy as the host. */
    {
        size_t j, at = 0;
        for (j = i; j < len; j++) {
            if (url[j] == '@') at = j + 1;
            if (url[j] == '/' || url[j] == '?' || url[j] == '#') break;
        }
        if (at > i) i = at;
    }

    if (i < len && url[i] == '[') { v6 = 1; i++; }

    for (; i < len; i++) {
        char c = url[i];
        if (v6 && c == ']') break;
        if (!v6 && (c == ':' || c == '/' || c == '?' || c == '#')) break;
        if (c == '/' || c == '?' || c == '#') break;
        if (n + 1 >= cap) return PO_TGT_MALFORMED;
        out[n++] = (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
    }
    out[n] = '\0';
    if (!n) return PO_TGT_MALFORMED;
    *is_v6 = v6;
    return PO_TGT_OK;
}

/* Parse a dotted quad. Returns 0 when the host is not one, which is the
 * common case (a name), not an error. */
static int po_tgt_v4(const char *h, uint32_t *out) {
    uint32_t o[4];
    int part = 0;
    size_t i = 0;
    for (part = 0; part < 4; part++) {
        uint32_t v = 0;
        int digits = 0;
        while (h[i] >= '0' && h[i] <= '9') {
            v = v * 10 + (uint32_t)(h[i] - '0');
            if (v > 255) return 0;
            i++; digits++;
            if (digits > 3) return 0;
        }
        if (!digits) return 0;
        o[part] = v;
        if (part < 3) { if (h[i] != '.') return 0; i++; }
    }
    if (h[i] != '\0') return 0;
    *out = (o[0] << 24) | (o[1] << 16) | (o[2] << 8) | o[3];
    return 1;
}

static int po_tgt_v4_policy(uint32_t a) {
    if ((a >> 24) == 127) return PO_TGT_LOOPBACK;          /* 127.0.0.0/8   */
    if (a == 0) return PO_TGT_LOOPBACK;                    /* 0.0.0.0       */
    if ((a >> 16) == 0xA9FE) return PO_TGT_LINK_LOCAL;     /* 169.254.0.0/16 */
    if ((a >> 24) == 10) return PO_TGT_PRIVATE;            /* 10.0.0.0/8    */
    if ((a >> 20) == 0xAC1) return PO_TGT_PRIVATE;         /* 172.16.0.0/12 */
    if ((a >> 16) == 0xC0A8) return PO_TGT_PRIVATE;        /* 192.168.0.0/16 */
    if ((a >> 8)  == 0xC00002) return PO_TGT_PRIVATE;      /* 192.0.2.0/24  */
    if ((a >> 22) == 0x191) return PO_TGT_PRIVATE;        /* 100.64.0.0/10 */
    return PO_TGT_OK;
}

/* IPv6, on the text. ::1 is loopback, fe80::/10 link-local, fc00::/7 unique
 * local, and ::ffff:127.0.0.1 is loopback wearing a hat. */
static int po_tgt_v6_policy(const char *h) {
    size_t n = strlen(h);
    if (n == 0) return PO_TGT_MALFORMED;
    if (strcmp(h, "::1") == 0 || strcmp(h, "::") == 0) return PO_TGT_LOOPBACK;
    if (n >= 4 && h[0] == 'f' && h[1] == 'e'
        && (h[2] == '8' || h[2] == '9' || h[2] == 'a' || h[2] == 'b'))
        return PO_TGT_LINK_LOCAL;
    if (n >= 2 && h[0] == 'f' && (h[1] == 'c' || h[1] == 'd'))
        return PO_TGT_PRIVATE;
    /* An IPv4-mapped address carries the v4 policy, not a v6 pass. */
    if (n > 7 && po_ascii_ncase(h, "::ffff:", 7) == 0) {
        uint32_t a;
        if (po_tgt_v4(h + 7, &a)) return po_tgt_v4_policy(a);
    }
    return PO_TGT_OK;
}

/* Names that resolve to loopback by convention. Refused by name as well as by
 * address, because `http://localhost:5432/` never reaches a resolver check
 * that is only applied to literals. */
static int po_tgt_name_policy(const char *h) {
    size_t n = strlen(h);
    if (strcmp(h, "localhost") == 0) return PO_TGT_LOOPBACK;
    if (n > 10 && strcmp(h + n - 10, ".localhost") == 0) return PO_TGT_LOOPBACK;
    if (n > 6 && strcmp(h + n - 6, ".local") == 0) return PO_TGT_LINK_LOCAL;
    if (strcmp(h, "metadata.google.internal") == 0) return PO_TGT_LINK_LOCAL;
    if (n > 9 && strcmp(h + n - 9, ".internal") == 0) return PO_TGT_PRIVATE;
    return PO_TGT_OK;
}

/* An allowlist entry matches a whole host or a dot-anchored suffix. The
 * anchor matters: an entry of `example.com` must not admit
 * `example.com.attacker.net`, and a plain suffix compare does exactly that. */
static int po_tgt_allowed(const char *h, const char *const *allow, int nallow) {
    int i;
    size_t hn = strlen(h);
    for (i = 0; i < nallow; i++) {
        size_t an = strlen(allow[i]);
        if (an == hn && memcmp(h, allow[i], an) == 0) return 1;
        if (hn > an + 1 && h[hn - an - 1] == '.'
            && memcmp(h + hn - an, allow[i], an) == 0) return 1;
    }
    return 0;
}

/* The whole policy.
 *
 * `allow` overrides the range refusals - an operator who has decided that an
 * internal host is a legitimate webhook target says so explicitly - but
 * never overrides the scheme, because `file://` and `gopher://` are not
 * webhook destinations under any policy. */
static int po_target_ok(const char *url, size_t len,
                        const char *const *allow, int nallow) {
    char host[PO_TGT_HOST_MAX];
    int v6 = 0, rc;

    if (!url || !len) return PO_TGT_MALFORMED;
    rc = po_tgt_host(url, len, host, sizeof(host), &v6);
    if (rc != PO_TGT_OK) return rc;

    if (allow && nallow) {
        if (po_tgt_allowed(host, allow, nallow)) return PO_TGT_OK;
        /* An allowlist that exists is exhaustive. Falling through to the
         * default ranges would make it a suggestion. */
        return PO_TGT_NOT_ALLOWED;
    }

    if (v6) return po_tgt_v6_policy(host);
    {
        uint32_t a;
        if (po_tgt_v4(host, &a)) return po_tgt_v4_policy(a);
    }
    return po_tgt_name_policy(host);
}

#endif /* PO_TARGET_H */

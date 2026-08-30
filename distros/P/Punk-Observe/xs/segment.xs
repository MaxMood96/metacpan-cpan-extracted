MODULE = Punk::Observe   PACKAGE = Punk::Observe::Segment   PREFIX = pos_

# --- the hash, against published vectors -----------------------------------

void
pos_murmur128(SV *buf, SV *seed)
    PPCODE:
        {
            STRLEN len; const char *p;
            po_h128 h;
            p = SvPV(buf, len);
            h = po_murmur3_128(p, (size_t)len, (uint32_t)SvUV(seed));
            mXPUSHs(po_u64_to_sv(h.hi));
            mXPUSHs(po_u64_to_sv(h.lo));
        }

# --- series ids -------------------------------------------------------------

# Intern a list of canonical blocks, returning the slot each got. Two calls
# with the same blocks in different ORDERS must give each block the same id,
# which is the property per-worker writing rests on.
void
pos_intern_series(SV *blocks)
    PPCODE:
        {
            po_arena ar;
            po_series_tab t;
            AV *av;
            SSize_t i, n;
            AV *slots = newAV();
            AV *ids   = newAV();

            if (!SvROK(blocks) || SvTYPE(SvRV(blocks)) != SVt_PVAV)
                croak("blocks must be an arrayref");
            av = (AV *)SvRV(blocks);
            n = av_len(av) + 1;

            if (!po_arena_init(&ar, 256)) croak("arena");
            if (!po_series_tab_init(&t, &ar, 16)) { po_arena_free(&ar); croak("tab"); }

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                STRLEN l; const char *p;
                po_h128 id;
                int created = 0;
                uint32_t slot;
                if (!e) continue;
                p = SvPV(*e, l);
                slot = po_series_intern(&t, p, (uint32_t)l, &id, &created);
                if (slot == PO_SERIES_ERR) { po_series_tab_free(&t);
                                             po_arena_free(&ar); croak("intern"); }
                av_push(slots, newSVuv((UV)slot));
                {
                    char hex[33];
                    static const char H[] = "0123456789abcdef";
                    int k;
                    for (k = 0; k < 8; k++) {
                        unsigned b = (unsigned)((id.hi >> (56 - k * 8)) & 0xFF);
                        hex[k * 2] = H[b >> 4]; hex[k * 2 + 1] = H[b & 15];
                    }
                    for (k = 0; k < 8; k++) {
                        unsigned b = (unsigned)((id.lo >> (56 - k * 8)) & 0xFF);
                        hex[16 + k * 2] = H[b >> 4]; hex[16 + k * 2 + 1] = H[b & 15];
                    }
                    av_push(ids, newSVpvn(hex, 32));
                }
            }
            {
                HV *res = newHV();
                hv_stores(res, "slots", newRV_noinc((SV *)slots));
                hv_stores(res, "ids",   newRV_noinc((SV *)ids));
                hv_stores(res, "count", newSVuv((UV)t.n));
                hv_stores(res, "collisions", newSVuv((UV)t.collisions));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_series_tab_free(&t);
            po_arena_free(&ar);
        }

# --- the symbol table -------------------------------------------------------

void
pos_intern_strings(SV *strings)
    PPCODE:
        {
            po_intern t;
            AV *av;
            SSize_t i, n;
            AV *ids = newAV();
            char *img;
            size_t imglen;

            if (!SvROK(strings) || SvTYPE(SvRV(strings)) != SVt_PVAV)
                croak("strings must be an arrayref");
            av = (AV *)SvRV(strings);
            n = av_len(av) + 1;
            if (!po_intern_init(&t, 16)) croak("intern");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                STRLEN l; const char *p;
                uint32_t id;
                if (!e) continue;
                p = SvPV(*e, l);
                id = po_intern_put(&t, p, (size_t)l);
                if (id == PO_SYM_NONE) { po_intern_free(&t); croak("intern full"); }
                av_push(ids, newSVuv((UV)id));
            }

            /* Round-trip through the serialised form, which is what a reader
             * actually sees out of an mmap. */
            imglen = po_intern_size(&t);
            img = (char *)malloc(imglen);
            if (!img) { po_intern_free(&t); croak("oom"); }
            po_intern_write(&t, img);

            {
                po_intern_view v;
                AV *back = newAV();
                HV *res = newHV();
                if (po_intern_open(&v, img, imglen)) {
                    uint32_t k;
                    for (k = 0; k < v.n; k++) {
                        uint32_t l; const char *p = po_intern_view_get(&v, k, &l);
                        av_push(back, p ? newSVpvn(p, l) : newSVpvs(""));
                    }
                }
                hv_stores(res, "ids",    newRV_noinc((SV *)ids));
                hv_stores(res, "count",  newSVuv((UV)t.n));
                hv_stores(res, "decoded", newRV_noinc((SV *)back));
                hv_stores(res, "bytes",  newSVuv((UV)imglen));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            free(img);
            po_intern_free(&t);
        }

# --- segments ---------------------------------------------------------------

# Build a segment from record specs and write it. Returns the path written.
SV *
pos_write(SV *path, SV *specs, SV *tenant, SV *slot)
    CODE:
        {
            po_seg_w w;
            AV *av;
            SSize_t i, n;
            STRLEN plen, tlen;
            const char *p, *tn;
            uint8_t ulid[16];
            int ok = 1;

            p  = SvPV(path, plen);
            tn = SvPV(tenant, tlen);
            if (!SvROK(specs) || SvTYPE(SvRV(specs)) != SVt_PVAV)
                croak("specs must be an arrayref");
            av = (AV *)SvRV(specs);
            n = av_len(av) + 1;

            if (!po_seg_w_init(&w, PO_SIG_TRACE, (uint32_t)SvUV(slot), tn, (size_t)tlen))
                croak("seg init");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **f;
                po_rec r;
                const char *body = NULL, *labels = NULL;
                STRLEN bl = 0, ll = 0;
                po_u64 t = 0;
                int created = 0;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                po_rec_zero(&r);
                r.kind = PO_SPAN;
                if ((f = hv_fetchs(h, "t", 0)) && po_sv_to_u64(aTHX_ *f, &t))
                    r.t_unix_nano = t;
                if ((f = hv_fetchs(h, "body", 0)))   body   = SvPV(*f, bl);
                if ((f = hv_fetchs(h, "labels", 0))) labels = SvPV(*f, ll);
                if (!po_seg_w_add(&w, &r, body, (uint32_t)bl,
                                  labels, (uint32_t)ll, &created)) { ok = 0; break; }
            }

            for (i = 0; i < 16; i++) ulid[i] = (uint8_t)(i * 7 + 3);
            if (ok) ok = po_seg_write(&w, p, ulid);
            po_seg_w_free(&w);
            RETVAL = ok ? newSVpv(p, 0) : &PL_sv_undef;
        }
    OUTPUT:
        RETVAL

# Parse an in-memory image. Separated from mmap so a test can hand it a
# deliberately damaged buffer with no filesystem in the way.
SV *
pos_parse(SV *buf)
    CODE:
        {
            po_seg_r s;
            STRLEN len;
            const char *p;
            p = SvPV(buf, len);
            memset(&s, 0, sizeof(s));
            s.fd = -1;
            if (!po_seg_parse(&s, p, (size_t)len)) RETVAL = &PL_sv_undef;
            else {
                HV *res = newHV();
                hv_stores(res, "records",  po_u64_to_sv((po_u64)s.n));
                hv_stores(res, "t_min",    po_u64_to_sv(s.hdr.t_min));
                hv_stores(res, "t_max",    po_u64_to_sv(s.hdr.t_max));
                hv_stores(res, "signal",   newSVuv((UV)s.hdr.signal));
                hv_stores(res, "slot",     newSVuv((UV)s.hdr.worker_slot));
                hv_stores(res, "symbols",  newSVuv((UV)s.sym.n));
                RETVAL = newRV_noinc((SV *)res);
            }
        }
    OUTPUT:
        RETVAL

# mmap a segment and read its bodies back through the symbol table.
void
pos_read(SV *path)
    PPCODE:
        {
            po_seg_r s;
            STRLEN plen;
            const char *p = SvPV(path, plen);
            AV *out = newAV();
            if (!po_seg_open(&s, p)) { mXPUSHs(&PL_sv_undef); XSRETURN(1); }
            {
                size_t i;
                for (i = 0; i < s.n; i++) {
                    HV *h = newHV();
                    uint32_t l = 0;
                    const char *b = po_intern_view_get(&s.sym, s.rec[i].body_off, &l);
                    hv_stores(h, "t", po_u64_to_sv(s.rec[i].t_unix_nano));
                    hv_stores(h, "series", po_u64_to_sv(s.rec[i].series));
                    hv_stores(h, "body", b ? newSVpvn(b, l) : newSVpvs(""));
                    av_push(out, newRV_noinc((SV *)h));
                }
            }
            {
                HV *res = newHV();
                hv_stores(res, "records", newRV_noinc((SV *)out));
                hv_stores(res, "t_min", po_u64_to_sv(s.hdr.t_min));
                hv_stores(res, "t_max", po_u64_to_sv(s.hdr.t_max));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_seg_close(&s);
        }

# Does a segment's span overlap a range? The pruning that makes a query over
# an hour not open a week.
int
pos_overlaps(SV *path, SV *from, SV *to)
    CODE:
        {
            po_seg_r s;
            STRLEN plen;
            const char *p = SvPV(path, plen);
            po_u64 a = 0, b = 0;
            (void)po_sv_to_u64(aTHX_ from, &a);
            (void)po_sv_to_u64(aTHX_ to, &b);
            if (!po_seg_open(&s, p)) XSRETURN_UNDEF;
            RETVAL = po_seg_overlaps(&s, a, b);
            po_seg_close(&s);
        }
    OUTPUT:
        RETVAL

# --- the shared arena -------------------------------------------------------

SV *
pos_shm_new(SV *cap)
    CODE:
        {
            po_shared *s;
            po_u64 c = 0;
            (void)po_sv_to_u64(aTHX_ cap, &c);
            Newxz(s, 1, po_shared);
            if (!po_shared_init(s, c)) { Safefree(s); XSRETURN_UNDEF; }
            RETVAL = newSViv(PTR2IV(s));
        }
    OUTPUT:
        RETVAL

void
pos_shm_rotate(SV *h)
    CODE:
        {
            po_shared *s = INT2PTR(po_shared *, SvIV(h));
#if defined(PO_HAVE_ATOMICS) && !defined(_WIN32)
            if (s->ok && s->m) {
                __atomic_store_n(&s->m->epoch_start, po_now_ns(),
                                 __ATOMIC_SEQ_CST);
                po_shm_rotate(s->m);
            }
#endif
        }

void
pos_shm_window(SV *h, SV *ns)
    CODE:
        {
            po_shared *s = INT2PTR(po_shared *, SvIV(h));
            po_u64 w = 0;
            (void)po_sv_to_u64(aTHX_ ns, &w);
            if (s->ok && s->m) s->m->window_ns = w;
        }

int
pos_shm_admit(SV *h)
    CODE:
        RETVAL = po_shared_admit_series(INT2PTR(po_shared *, SvIV(h)));
    OUTPUT:
        RETVAL

void
pos_shm_stats(SV *h)
    PPCODE:
        {
            po_shared *s = INT2PTR(po_shared *, SvIV(h));
            HV *res = newHV();
            hv_stores(res, "series",     po_u64_to_sv(s->m->series));
            hv_stores(res, "series_cap", po_u64_to_sv(s->m->series_cap));
            hv_stores(res, "rejected",   po_u64_to_sv(s->m->rejected));
            hv_stores(res, "overflow",   po_u64_to_sv(s->m->overflow));
            /* ACCEPTED, which is not what the store holds: the store's own
             * count is what survived retention, and this is what arrived. A
             * receiver that is refusing everything and a receiver that is
             * being sent nothing look identical in the store and different
             * here. */
            hv_stores(res, "records",    po_u64_to_sv(s->m->records));
            hv_stores(res, "bytes",      po_u64_to_sv(s->m->bytes));
            hv_stores(res, "rate_window_start",
                                         po_u64_to_sv(s->m->rate_window_start));
            hv_stores(res, "rate_records",  po_u64_to_sv(s->m->rate_records));
            hv_stores(res, "rate_bytes",    po_u64_to_sv(s->m->rate_bytes));
            hv_stores(res, "rate_rejected", po_u64_to_sv(s->m->rate_rejected));
            hv_stores(res, "series_window", po_u64_to_sv(s->m->window_ns));
            hv_stores(res, "live_gaps",  po_u64_to_sv(s->m->live_gaps));
            hv_stores(res, "shared",     newSViv(po_shared_is_shared(s)));
            mXPUSHs(newRV_noinc((SV *)res));
        }

void
pos_shm_free(SV *h)
    CODE:
        {
            po_shared *s = INT2PTR(po_shared *, SvIV(h));
            po_shared_free(s);
            Safefree(s);
        }

# --- the manifest -----------------------------------------------------------

int
pos_manifest_append(SV *path, SV *gen, SV *names)
    CODE:
        {
            STRLEN plen;
            const char *p = SvPV(path, plen);
            AV *av;
            SSize_t i, n;
            const char **list;
            po_u64 g = 0;
            (void)po_sv_to_u64(aTHX_ gen, &g);
            if (!SvROK(names) || SvTYPE(SvRV(names)) != SVt_PVAV)
                croak("names must be an arrayref");
            av = (AV *)SvRV(names);
            n = av_len(av) + 1;
            Newx(list, n ? n : 1, const char *);
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                list[i] = e ? SvPV_nolen(*e) : "";
            }
            RETVAL = po_manifest_append(p, g, list, (size_t)n);
            Safefree(list);
        }
    OUTPUT:
        RETVAL

void
pos_manifest_latest(SV *buf)
    PPCODE:
        {
            STRLEN len;
            const char *p = SvPV(buf, len);
            size_t off = 0, nlen = 0, count = 0;
            po_u64 g = po_manifest_latest(p, (size_t)len, &off, &nlen, &count);
            HV *res = newHV();
            AV *names = newAV();
            if (g) {
                size_t i = off, end = off + nlen;
                while (i < end) {
                    size_t e = i;
                    while (e < end && p[e] != '\n') e++;
                    av_push(names, newSVpvn(p + i, e - i));
                    i = e + 1;
                }
            }
            hv_stores(res, "generation", po_u64_to_sv(g));
            hv_stores(res, "names", newRV_noinc((SV *)names));
            hv_stores(res, "count", newSVuv((UV)count));
            mXPUSHs(newRV_noinc((SV *)res));
        }

/* punk_stream.h - a streamed response for an ordinary route, in C.
 *
 * $c->stream($content_type, $cb) hands $cb a writer and emits the body as it
 * is produced: a CSV export walking a large query, an NDJSON dump - a response
 * of unknown length that should not cost its size in memory. This is the SSE
 * transport machinery (punk_sse.h) with the event framing removed: the same
 * three transports in the same order - Hyperman detach (stream on the loop),
 * psgi.streaming (the portable delayed-response writer), and blocking
 * psgix.io - and the same pw_append / io_watch WRITE flush discipline.
 *
 * What is new here is the ending. An SSE stream lives until someone closes
 * it; a streamed response ENDS, and how it ends must be visible to the
 * client. On the raw-socket transports the body is chunk-framed (HTTP/1.1),
 * so a clean close sends the terminal chunk and a handler that dies closes
 * the socket without one - the client sees truncation, never a valid-looking
 * short body. The contract is: the callback returning closes the stream
 * cleanly; a die closes it hard.
 *
 * Backpressure is $w->drain: a Punk::Future settled with 1 when everything
 * written so far has reached the kernel, or 0 when the stream closed first.
 * On the detach transport a pending drain settles from the writable watcher;
 * the blocking transports flush synchronously, so it settles immediately.
 * Awaiting it after each write bounds the buffer to one chunk.
 *
 * Must be included after punk_wsconn.h (punk_hm, pw_append), punk_wshandshake.h
 * (pw_err / pw_empty), punk_context.h (pcx_*), punk_static.h (punk_closure)
 * and punk_future.h (pf_new / pf_settle).
 */

#ifndef PUNK_STREAM_H
#define PUNK_STREAM_H

#include <fcntl.h>

enum { PST_MODE_DETACH = 0, PST_MODE_STREAM = 1, PST_MODE_BLOCK = 2 };
enum { PST_OPEN = 0, PST_CLOSING = 1, PST_CLOSED = 2 };

typedef struct punk_stream {
    int    fd;                    /* detach / block; -1 for a psgi writer */
    int    mode;
    int    state;
    unsigned char reading, writing, in_teardown, chunked;
    char  *wbuf; size_t wlen, woff, wcap;
    size_t write_buffer_limit;    /* 0 = unbounded; over it, teardown */
    SV    *writer;                /* the psgi.streaming $writer (STREAM mode) */
    SV    *self_rv;               /* strong self while live */
    SV    *drain_f;               /* the pending drain future, or NULL */
    SV    *reqid;                 /* psgix.request_id for the death report */
    SV    *defer_c, *defer_code, *defer_head;   /* the deferred detach start */
    hm_abi_timer *defer_tw;
    void  *loop;
    const hm_abi *abi;
} punk_stream;

static punk_stream *pst_of(pTHX_ SV *self) {
    if (!SvROK(self) || !SvIOK(SvRV(self)))
        croak("Punk::Stream: not a stream");
    return (punk_stream *)INT2PTR(void *, SvIV(SvRV(self)));
}

static void pst_teardown(pTHX_ punk_stream *st);
static void pst_on_writable(pTHX_ int fd, int mask, void *ud);

/* settle the pending drain future, if any. ok is 1 (drained) or 0 (closed
 * first). The local copy matters: settling fires reactions that can call back
 * into this stream and ask for another drain. */
static void pst_settle_drain(pTHX_ punk_stream *st, int ok) {
    SV *f = st->drain_f;
    AV *vals;
    if (!f) return;
    st->drain_f = NULL;
    vals = newAV();
    av_push(vals, newSViv(ok));
    pf_settle(aTHX_ pf_of(aTHX_ f), f, PF_DONE, vals);
    SvREFCNT_dec(f);
}

/* ---- writing (DETACH / BLOCK): the punk_sse.h flush, plus two endings ------ */

static void pst_flush(pTHX_ punk_stream *st) {
    while (st->woff < st->wlen) {
        ssize_t n = write(st->fd, st->wbuf + st->woff, st->wlen - st->woff);
        if (n > 0) { st->woff += (size_t)n; continue; }
        if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            if (st->mode == PST_MODE_DETACH) {
                if (!st->writing && st->abi && st->loop) {
                    st->abi->io_watch(aTHX_ st->loop, st->fd, HM_ABI_WRITE,
                                      pst_on_writable, st);
                    st->writing = 1;
                }
                return;
            }
            {   /* blocking transport over a socket the server left
                 * non-blocking: wait for writability rather than spinning.
                 * SSE's writes were small enough never to meet this; an
                 * export is not. */
                fd_set wf;
                FD_ZERO(&wf);
                FD_SET(st->fd, &wf);
                (void)select(st->fd + 1, NULL, &wf, NULL, NULL);
                continue;
            }
        }
        if (n < 0 && errno == EINTR) continue;
        pst_teardown(aTHX_ st);                  /* write error: client gone */
        return;
    }
    st->wlen = st->woff = 0;
    if (st->writing && st->abi && st->loop) {
        st->abi->io_unwatch(aTHX_ st->loop, st->fd, HM_ABI_WRITE);
        st->writing = 0;
    }
    pst_settle_drain(aTHX_ st, 1);
    if (st->state == PST_CLOSING) pst_teardown(aTHX_ st);   /* fully sent */
}

static void pst_on_writable(pTHX_ int fd, int mask, void *ud) {
    PERL_UNUSED_ARG(fd); PERL_UNUSED_ARG(mask);
    pst_flush(aTHX_ (punk_stream *)ud);
}

/* the client closing early is the only thing we read for */
static void pst_on_readable(pTHX_ int fd, int mask, void *ud) {
    punk_stream *st = (punk_stream *)ud;
    char scratch[512];
    ssize_t n;
    PERL_UNUSED_ARG(fd); PERL_UNUSED_ARG(mask);
    n = read(st->fd, scratch, sizeof scratch);
    if (n == 0) { pst_teardown(aTHX_ st); return; }
    if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
        return;
    if (n < 0) pst_teardown(aTHX_ st);
    /* n > 0: bytes on a response stream are the client's mistake; ignored */
}

/* queue raw bytes (already framed) to the socket transports */
static void pst_write_raw(pTHX_ punk_stream *st, const char *bytes, size_t len) {
    if (st->write_buffer_limit
        && st->wlen - st->woff + len > st->write_buffer_limit) {
        pst_teardown(aTHX_ st);                  /* a client that will not read */
        return;
    }
    pw_append(&st->wbuf, &st->wlen, &st->wcap, bytes, len);
    pst_flush(aTHX_ st);
}

/* one body chunk, framed for the transport */
static void pst_write_body(pTHX_ punk_stream *st, const char *bytes, size_t len) {
    if (st->state != PST_OPEN || len == 0) return;
    if (st->mode == PST_MODE_STREAM) {
        dSP;
        ENTER; SAVETMPS;
        PUSHMARK(SP); EXTEND(SP, 2);
        PUSHs(st->writer ? st->writer : &PL_sv_undef);
        PUSHs(sv_2mortal(newSVpvn(bytes, len)));
        PUTBACK;
        call_method("write", G_DISCARD | G_EVAL);
        SPAGAIN;
        if (SvTRUE(ERRSV)) { FREETMPS; LEAVE; pst_teardown(aTHX_ st); return; }
        PUTBACK; FREETMPS; LEAVE;
        return;
    }
    if (st->chunked) {
        char pre[24];
        /* the size goes through its own variable: where perl expands
         * my_snprintf to a gcc statement expression, that expression declares
         * its own `len' from the snprintf return, and a `len' written in the
         * argument list resolves to that one - still uninitialised inside its
         * own initialiser. Every chunk header then reads the stack. */
        UV chunk_len = (UV)len;
        int n = my_snprintf(pre, sizeof pre, "%" UVxf "\r\n", chunk_len);
        if (st->write_buffer_limit
            && st->wlen - st->woff + len + (size_t)n + 2 > st->write_buffer_limit) {
            pst_teardown(aTHX_ st);
            return;
        }
        pw_append(&st->wbuf, &st->wlen, &st->wcap, pre, (size_t)n);
        pw_append(&st->wbuf, &st->wlen, &st->wcap, bytes, len);
        pw_append(&st->wbuf, &st->wlen, &st->wcap, "\r\n", 2);
        pst_flush(aTHX_ st);
        return;
    }
    pst_write_raw(aTHX_ st, bytes, len);
}

/* ---- teardown and the two closes ------------------------------------------- */

/* the hard stop: nothing more is sent, so on a chunked transport the client
 * sees a missing terminal chunk - truncation, not a short success */
static void pst_teardown(pTHX_ punk_stream *st) {
    if (st->in_teardown || st->state == PST_CLOSED) return;
    st->in_teardown = 1;
    if (st->mode == PST_MODE_DETACH && st->abi && st->loop) {
        if (st->reading) st->abi->io_unwatch(aTHX_ st->loop, st->fd, HM_ABI_READ);
        if (st->writing) st->abi->io_unwatch(aTHX_ st->loop, st->fd, HM_ABI_WRITE);
    }
    st->reading = st->writing = 0;
    if (st->mode == PST_MODE_STREAM && st->writer) {
        dSP;
        ENTER; SAVETMPS;
        PUSHMARK(SP); EXTEND(SP, 1); PUSHs(st->writer); PUTBACK;
        call_method("close", G_DISCARD | G_EVAL);
        SPAGAIN; PUTBACK; FREETMPS; LEAVE;
    }
    if (st->fd >= 0) { close(st->fd); st->fd = -1; }
    st->state = PST_CLOSED;
    pst_settle_drain(aTHX_ st, 0);
    st->in_teardown = 0;
    if (st->self_rv) { SV *s = st->self_rv; st->self_rv = NULL; SvREFCNT_dec(s); }
}

/* the clean end: terminal chunk, then teardown once every byte is out. On the
 * detach transport a still-loaded buffer keeps draining on the loop (the
 * stream holds itself alive until it has); the blocking transports flush here. */
static void pst_close(pTHX_ punk_stream *st) {
    if (st->state != PST_OPEN) return;
    if (st->mode == PST_MODE_STREAM) { pst_teardown(aTHX_ st); return; }
    st->state = PST_CLOSING;
    if (st->chunked)
        pw_append(&st->wbuf, &st->wlen, &st->wcap, "0\r\n\r\n", 5);
    pst_flush(aTHX_ st);        /* teardown fires from here once drained */
}

static void pst_free(pTHX_ punk_stream *st) {
    if (!st) return;
    if (st->mode == PST_MODE_DETACH && st->abi && st->loop) {
        /* watchers name this struct, so they go before it - and before the
         * fd, or the loop watches a number the next connection gets */
        if (st->reading) st->abi->io_unwatch(aTHX_ st->loop, st->fd, HM_ABI_READ);
        if (st->writing) st->abi->io_unwatch(aTHX_ st->loop, st->fd, HM_ABI_WRITE);
    }
    if (st->defer_tw && st->abi && st->loop)
        st->abi->timer_cancel(aTHX_ st->loop, st->defer_tw);
    if (st->fd >= 0)  close(st->fd);
    if (st->wbuf)     free(st->wbuf);
    if (st->writer)   SvREFCNT_dec(st->writer);
    if (st->drain_f)  SvREFCNT_dec(st->drain_f);
    if (st->reqid)    SvREFCNT_dec(st->reqid);
    if (st->defer_c)    SvREFCNT_dec(st->defer_c);
    if (st->defer_code) SvREFCNT_dec(st->defer_code);
    if (st->defer_head) SvREFCNT_dec(st->defer_head);
    if (st->self_rv)  SvREFCNT_dec(st->self_rv);
    Safefree(st);
}

/* ---- construction, the head, the handler ---------------------------------- */

static punk_stream *pst_new(pTHX_ int mode, HV *opts) {
    punk_stream *st;
    Newxz(st, 1, punk_stream);
    st->fd = -1;
    st->mode = mode;
    st->state = PST_OPEN;
    if (opts) {
        SV **w = hv_fetchs(opts, "write_buffer_limit", 0);
        if (w && *w && SvOK(*w)) st->write_buffer_limit = (size_t)SvUV(*w);
    }
    return st;
}

static IV pst_opt_status(pTHX_ HV *opts) {
    SV **s = opts ? hv_fetchs(opts, "status", 0) : NULL;
    return (s && *s && SvOK(*s)) ? SvIV(*s) : 200;
}
static AV *pst_opt_headers(pTHX_ HV *opts) {
    SV **h = opts ? hv_fetchs(opts, "headers", 0) : NULL;
    return (h && *h && SvROK(*h) && SvTYPE(SvRV(*h)) == SVt_PVAV)
        ? (AV *)SvRV(*h) : NULL;
}

/* an empty reason-phrase is valid HTTP; 200 keeps its customary one */
static const char *pst_phrase(IV status) {
    return status == 200 ? "OK" : "";
}

/* the raw response head for the socket transports */
static SV *pst_head(pTHX_ punk_stream *st, SV *ct, HV *opts) {
    IV status = pst_opt_status(aTHX_ opts);
    AV *extra = pst_opt_headers(aTHX_ opts);
    SV *head = sv_2mortal(newSVpvf("HTTP/1.1 %" IVdf " %s\r\nContent-Type: ",
                                   status, pst_phrase(status)));
    sv_catsv(head, ct);
    sv_catpvs(head, "\r\n");
    if (extra) {
        SSize_t i, n = av_len(extra) + 1;
        for (i = 0; i + 1 < n; i += 2) {
            SV **k = av_fetch(extra, i, 0);
            SV **v = av_fetch(extra, i + 1, 0);
            if (!(k && *k && v && *v)) continue;
            sv_catsv(head, *k);
            sv_catpvs(head, ": ");
            sv_catsv(head, *v);
            sv_catpvs(head, "\r\n");
        }
    }
    if (st->chunked) sv_catpvs(head, "Transfer-Encoding: chunked\r\n");
    sv_catpvs(head, "Connection: close\r\nX-Accel-Buffering: no\r\n\r\n");
    return head;
}

/* Run $code->($c, $w). The callback returning is the clean end; a die is the
 * hard one - the head is already on the wire, so there is no error response
 * to send, and on a chunked transport the missing terminal chunk is the
 * client's evidence. The report carries the request id when one exists. */
static void pst_run_handler(pTHX_ SV *code, SV *c, SV *self) {
    dSP; int died;
    punk_stream *st;
    ENTER; SAVETMPS;
    PUSHMARK(SP); EXTEND(SP, 2); PUSHs(c); PUSHs(self); PUTBACK;
    call_sv(code, G_DISCARD | G_EVAL);
    SPAGAIN;
    died = SvTRUE(ERRSV) ? 1 : 0;
    PUTBACK; FREETMPS; LEAVE;
    st = pst_of(aTHX_ self);
    if (died) {
        if (st->reqid)
            warn("Punk::Stream: handler died (request %" SVf "): %" SVf,
                 SVfARG(st->reqid), SVfARG(ERRSV));
        else
            warn("Punk::Stream: handler died: %" SVf, SVfARG(ERRSV));
        pst_teardown(aTHX_ st);
        return;
    }
    pst_close(aTHX_ st);
}

/* The deferred half of the detach transport. Hyperman's detach is two-phase:
 * hm_detach disarms the server's watchers at once, but the connection slot is
 * only released after the app frame returns its sentinel - and the event
 * dispatch routes an fd to the application's watchers only once that slot is
 * empty. A handler that produced the whole body synchronously would arm its
 * write watcher against a slot still naming the server's connection, and the
 * first EAGAIN would stall the stream forever. So the detach transport starts
 * on the next loop tick, after the sentinel has made it home.
 *
 * The self-reference is held across the run: the handler can tear the stream
 * down (client gone), and teardown drops the stream's own reference - the
 * last one, here. The SSE heartbeat learned this the hard way. */
static void pst_start_cb(pTHX_ void *ud) {
    punk_stream *st = (punk_stream *)ud;
    SV *keep = st->self_rv ? SvREFCNT_inc(st->self_rv) : NULL;
    SV *c = st->defer_c, *code = st->defer_code, *head = st->defer_head;
    st->defer_tw = NULL;                    /* it fired; nothing to cancel */
    st->defer_c = st->defer_code = st->defer_head = NULL;
    if (st->state == PST_OPEN) {
        pst_write_raw(aTHX_ st, SvPVX(head), SvCUR(head));
        if (st->state == PST_OPEN) {
            st->abi->io_watch(aTHX_ st->loop, st->fd, HM_ABI_READ,
                              pst_on_readable, st);
            st->reading = 1;
            pst_run_handler(aTHX_ code, c, st->self_rv ? st->self_rv : keep);
        }
    }
    SvREFCNT_dec(c);
    SvREFCNT_dec(code);
    SvREFCNT_dec(head);
    if (keep) SvREFCNT_dec(keep);           /* st may be gone after this */
}

/* the psgi.streaming responder: capture [ $c, $code, $ct, $opts, $reqid ] */
XS_INTERNAL(pst_stream_cb);
XS_INTERNAL(pst_stream_cb) {
    dXSARGS;
    AV *cap = punk_clos_cap(aTHX_ cv);
    SV *c    = *av_fetch(cap, 0, 0);
    SV *code = *av_fetch(cap, 1, 0);
    SV *ct   = *av_fetch(cap, 2, 0);
    SV *osv  = *av_fetch(cap, 3, 0);
    SV *rid  = *av_fetch(cap, 4, 0);
    HV *opts = (SvROK(osv) && SvTYPE(SvRV(osv)) == SVt_PVHV) ? (HV *)SvRV(osv) : NULL;
    SV *responder = items > 0 ? ST(0) : &PL_sv_undef;
    AV *hdrs = newAV(), *sh = newAV(), *extra = pst_opt_headers(aTHX_ opts);
    SV *writer, *self;
    punk_stream *st;
    av_push(hdrs, newSVpvs("Content-Type"));      av_push(hdrs, newSVsv(ct));
    if (extra) {
        SSize_t i, n = av_len(extra) + 1;
        for (i = 0; i + 1 < n; i += 2) {
            SV **k = av_fetch(extra, i, 0);
            SV **v = av_fetch(extra, i + 1, 0);
            if (!(k && *k && v && *v)) continue;
            av_push(hdrs, newSVsv(*k));
            av_push(hdrs, newSVsv(*v));
        }
    }
    av_push(hdrs, newSVpvs("X-Accel-Buffering")); av_push(hdrs, newSVpvs("no"));
    av_push(sh, newSViv(pst_opt_status(aTHX_ opts)));
    av_push(sh, newRV_noinc((SV *)hdrs));
    {
        dSP; int n;
        ENTER; SAVETMPS;
        PUSHMARK(SP); EXTEND(SP, 1);
        PUSHs(sv_2mortal(newRV_noinc((SV *)sh)));
        PUTBACK;
        n = call_sv(responder, G_SCALAR);
        SPAGAIN;
        writer = n > 0 ? SvREFCNT_inc(POPs) : &PL_sv_undef;
        PUTBACK; FREETMPS; LEAVE;
    }
    st = pst_new(aTHX_ PST_MODE_STREAM, opts);
    st->writer = writer;                           /* +1 owned */
    if (SvOK(rid)) st->reqid = newSVsv(rid);
    self = sv_2mortal(sv_setref_iv(newSV(0), "Punk::Stream", PTR2IV(st)));
    st->self_rv = newSVsv(self);
    pst_run_handler(aTHX_ code, c, self);
    XSRETURN_EMPTY;
}

/* ---- $c->stream ------------------------------------------------------------ */

static SV *punk_stream_start(pTHX_ SV *c, SV *ct, HV *opts, SV *code) {
    AV *cav = pcx_av(aTHX_ c);
    SV *envsv = pcx_get(aTHX_ cav, PCX_ENV);
    HV *envh = (envsv && SvROK(envsv) && SvTYPE(SvRV(envsv)) == SVt_PVHV)
               ? (HV *)SvRV(envsv) : NULL;
    SV **x, *rid;
    int chunked = 1;
    if (!envh) return pw_err(aTHX_ 500, "bad stream dispatch\n", NULL, NULL);

    x = hv_fetchs(envh, "SERVER_PROTOCOL", 0);
    if (x && *x && SvOK(*x)) {
        STRLEN pl;
        const char *p = SvPV_const(*x, pl);
        if (pl == 8 && memEQ(p, "HTTP/1.0", 8)) chunked = 0;
    }
    x = hv_fetchs(envh, "psgix.request_id", 0);
    rid = (x && *x && SvOK(*x)) ? *x : NULL;

    /* 1. Hyperman detach: stream on the worker loop */
    x = hv_fetchs(envh, "psgix.hyperman.conn", 0);
    if (x && *x && SvROK(*x) && SvTYPE(SvRV(*x)) == SVt_PVAV) {
        const hm_abi *A = punk_hm(aTHX);
        if (A) {
            AV *cid = (AV *)SvRV(*x);
            SV **fsv = av_fetch(cid, 0, 0), **isv = av_fetch(cid, 1, 0);
            void *loop = A->cur_loop(aTHX);
            int fd; int fl;
            punk_stream *st; SV *self;
            if (!(fsv && *fsv && isv && *isv && loop))
                return pw_err(aTHX_ 500, "cannot stream this connection\n", NULL, NULL);
            fd = (int)SvIV(*fsv);
            if (A->conn_detach(aTHX_ loop, fd, SvUV(*isv)) != 0)
                return pw_err(aTHX_ 503, "cannot stream this connection\n", NULL, NULL);
            fl = fcntl(fd, F_GETFL, 0);
            if (fl >= 0) (void)fcntl(fd, F_SETFL, fl | O_NONBLOCK);
            st = pst_new(aTHX_ PST_MODE_DETACH, opts);
            st->fd = fd; st->abi = A; st->loop = loop; st->chunked = (unsigned char)chunked;
            if (rid) st->reqid = newSVsv(rid);
            self = sv_2mortal(sv_setref_iv(newSV(0), "Punk::Stream", PTR2IV(st)));
            st->self_rv = newSVsv(self);
            st->defer_c    = newSVsv(c);
            st->defer_code = newSVsv(code);
            st->defer_head = newSVsv(pst_head(aTHX_ st, ct, opts));
            st->defer_tw   = A->timer(aTHX_ loop, 0.0, pst_start_cb, st);
            return pw_empty(aTHX_ 200);          /* the socket is ours now */
        }
    }

    /* 2. psgi.streaming: the portable delayed-response writer */
    x = hv_fetchs(envh, "psgi.streaming", 0);
    if (x && *x && SvTRUE(*x)) {
        AV *cap = newAV();
        av_push(cap, newSVsv(c));
        av_push(cap, newSVsv(code));
        av_push(cap, newSVsv(ct));
        av_push(cap, opts ? newRV_inc((SV *)opts) : newSV(0));
        av_push(cap, rid ? newSVsv(rid) : newSV(0));
        return punk_closure(aTHX_ pst_stream_cb, cap);   /* the responder */
    }

    /* 3. blocking psgix.io: stream inside the handler (pins a worker) */
    x = opts ? hv_fetchs(opts, "blocking", 0) : NULL;
    if (x && *x && SvTRUE(*x)) {
        SV **iop = hv_fetchs(envh, "psgix.io", 0);
        if (iop && *iop && SvOK(*iop)) {
            IO *io = sv_2io(*iop);
            int fd = (io && IoIFP(io)) ? PerlIO_fileno(IoIFP(io)) : -1;
            if (fd >= 0) {
                punk_stream *st = pst_new(aTHX_ PST_MODE_BLOCK, opts);
                SV *self, *head;
                st->fd = fd; st->chunked = (unsigned char)chunked;
                if (rid) st->reqid = newSVsv(rid);
                self = sv_2mortal(sv_setref_iv(newSV(0), "Punk::Stream", PTR2IV(st)));
                st->self_rv = newSVsv(self);
                head = pst_head(aTHX_ st, ct, opts);
                pst_write_raw(aTHX_ st, SvPVX(head), SvCUR(head));
                pst_run_handler(aTHX_ code, c, self);
                return pw_empty(aTHX_ 200);
            }
        }
    }

    return pw_err(aTHX_ 501,
        "this server cannot stream a response (needs Hyperman 0.11+, a "
        "psgi.streaming server, or blocking => 1 with psgix.io)\n",
        NULL, NULL);
}

#endif /* PUNK_STREAM_H */

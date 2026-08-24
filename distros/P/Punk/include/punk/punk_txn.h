/* punk_txn.h - $c->txn: a transaction on a configured database, on either
 * model backend, with the models that take part bound to it.
 *
 *   my $order = $c->txn(sub {
 *       my ($tx) = @_;
 *       my $o = $tx->model('Order')->create(\%data);
 *       $tx->model('Stock')->update({ id => $sku, held => $held + 1 });
 *       return $o;
 *   });
 *   $c->txn(analytics => sub { ... });
 *
 * The block gets a Punk::Txn. $tx->model($name) is the model bound to the
 * transaction; what that binding means differs by backend, and the
 * difference is the whole design:
 *
 *   - Punk::Model::DBI holds one connection per database per worker, so a
 *     transaction on it is begin_work / commit / rollback on that handle and
 *     every model on the database is inside it whether it came through
 *     $tx->model or $c->model. The binding is a courtesy and a check.
 *
 *   - Punk::Model::DBIx::Loop runs statements on a pool, and DBIx::Loop pins
 *     a transaction to ONE slot: its own rule is that plain statements during
 *     a transaction run on other slots and never join. So a model reached
 *     through $c->model inside the block is OUTSIDE the transaction, and
 *     $tx->model is the only way in - it hands back a copy of the model whose
 *     backend carries the pinned handle, and every statement that copy runs
 *     goes through it. A worker-wide "current transaction" would be wrong
 *     here: under the event loop the requests served between two of this
 *     block's queries belong to somebody else.
 *
 * Both return what the block returns - the value itself on DBI, a
 * Punk::Future of it on DBIx::Loop, resolved after COMMIT - which is the
 * rule Punk::Model already states for the contract: shapes, not timing.
 *
 * Nested: croaks on DBI (one connection, one transaction, and a silent join
 * is how a rollback stops covering what the caller thought it covered);
 * DBIx::Loop's own txn inside a block is an independent transaction on
 * another slot, and the POD says so rather than hiding it.
 *
 * Include after punk_dbil.h (both backends, pdl_start, the bridge) and
 * punk_future.h, and punk_static.h for punk_closure. */

#ifndef PUNK_TXN_H
#define PUNK_TXN_H

#define PTX_CLS "Punk::Txn"

static HV *ptx_hv(pTHX_ SV *tx) {
    if (!(tx && SvROK(tx) && SvTYPE(SvRV(tx)) == SVt_PVHV
          && sv_derived_from(tx, PTX_CLS)))
        croak(PTX_CLS ": not a transaction object");
    return (HV *)SvRV(tx);
}

/* ---- the database behind a name -------------------------------------------- */

/* The `database` keyword's options for a name (K_DATABASES), and the backend
 * class they select. `name` NULL or undef is the default database. Returns
 * the options as an RV (mortal); *class_out is a mortal class-name SV. */
static SV *ptx_db_opts(pTHX_ SV *app, SV *name, SV **class_out) {
    HV *h   = app_hv(aTHX_ app);
    HV *dbs = app_hash(aTHX_ h, K_DATABASES);
    const char *nm = K_DEFAULT; STRLEN nl = 7;
    SV **opts, *ret, *b = NULL;
    if (name && SvOK(name) && SvCUR(name)) nm = SvPV_const(name, nl);
    opts = hv_fetch(dbs, nm, (I32)nl, 0);
    if (opts && *opts && SvROK(*opts) && SvTYPE(SvRV(*opts)) == SVt_PVHV) {
        ret = sv_2mortal(newSVsv(*opts));
        b = pdbi_get(aTHX_ (HV *)SvRV(*opts), "backend");
    }
    else if (nl == 7 && memEQ(nm, K_DEFAULT, 7))
        croak(PTX_CLS ": no database configured - add a database keyword");
    else
        croak(PTX_CLS ": no database '%s' configured (the database keyword "
              "names one as `database %s => { dsn => ... }`)", nm, nm);
    *class_out = (b && SvOK(b)) ? sv_2mortal(newSVsv(b))
                                : sv_2mortal(newSVpvs("Punk::Model::DBI"));
    return ret;
}

/* ---- Punk::Txn ------------------------------------------------------------ */

static SV *ptx_new(pTHX_ SV *c, SV *app, SV *name, SV *class, SV *opts) {
    HV *h = newHV();
    (void)hv_stores(h, "c",      newSVsv(c));
    (void)hv_stores(h, "app",    newSVsv(app));
    (void)hv_stores(h, "name",   (name && SvOK(name) && SvCUR(name))
                                     ? newSVsv(name) : newSVpvs(K_DEFAULT));
    (void)hv_stores(h, "class",  newSVsv(class));
    (void)hv_stores(h, "opts",   newSVsv(opts));
    (void)hv_stores(h, "handle", newSV(0));
    (void)hv_stores(h, "active", newSViv(0));
    return sv_bless(newRV_noinc((SV *)h), gv_stashpvs(PTX_CLS, GV_ADD));
}

/* $tx->model($name): the registered model, bound to this transaction.
 *
 * A shallow copy of the per-worker instance with a copy of its backend
 * carrying the transaction handle under `_tx`. The shared instance is never
 * touched, so nothing leaks out of the block. A model on another database
 * croaks: it cannot be in this transaction, and pretending would be the
 * worst of the available bugs. */
static SV *ptx_model(pTHX_ SV *tx, SV *name) {
    HV *th    = ptx_hv(aTHX_ tx);
    SV *app   = pdbi_get(aTHX_ th, "app");
    SV *txnm  = pdbi_get(aTHX_ th, "name");
    SV *hdl   = pdbi_get(aTHX_ th, "handle");
    SV *act   = pdbi_get(aTHX_ th, "active");
    SV *argv[1], *inst, *meta, *backend, *copy_rv, *bcopy_rv;
    HV *ih, *bh, *copy, *bcopy;
    const char *mdb = K_DEFAULT; STRLEN ml = 7;

    if (!(act && SvTRUE(act)))
        croak(PTX_CLS ": the transaction is over - $tx->model is for inside "
              "the block");
    argv[0] = name;
    inst = pcx_call_meth(aTHX_ app, "model_instance", argv, 1, 1);
    if (!(inst && SvROK(inst) && SvTYPE(SvRV(inst)) == SVt_PVHV)) {
        if (inst) SvREFCNT_dec(inst);
        croak(PTX_CLS ": no model '%s'", SvPV_nolen(name));
    }
    sv_2mortal(inst);
    ih = (HV *)SvRV(inst);

    /* the model's database, from its metadata */
    meta = pdbi_get(aTHX_ ih, "meta");
    if (meta && SvROK(meta) && SvTYPE(SvRV(meta)) == SVt_PVHV) {
        SV *d = pdbi_get(aTHX_ (HV *)SvRV(meta), "database");
        if (d && SvOK(d) && SvCUR(d)) mdb = SvPV_const(d, ml);
    }
    if (!(SvCUR(txnm) == ml && memEQ(SvPVX(txnm), mdb, ml)))
        croak(PTX_CLS ": model '%s' lives on database '%.*s', and this "
              "transaction is on '%s'", SvPV_nolen(name), (int)ml, mdb,
              SvPV_nolen(txnm));

    backend = pdbi_get(aTHX_ ih, "backend");
    if (!(backend && SvROK(backend) && SvTYPE(SvRV(backend)) == SVt_PVHV))
        croak(PTX_CLS ": model '%s' has no backend", SvPV_nolen(name));
    bh = (HV *)SvRV(backend);

    bcopy = newHVhv(bh);
    (void)hv_stores(bcopy, "_tx", newSVsv(hdl ? hdl : &PL_sv_undef));
    bcopy_rv = sv_bless(newRV_noinc((SV *)bcopy), SvSTASH(SvRV(backend)));

    copy = newHVhv(ih);
    (void)hv_stores(copy, "backend", bcopy_rv);
    copy_rv = sv_bless(newRV_noinc((SV *)copy), SvSTASH(SvRV(inst)));
    return copy_rv;
}

/* ---- the DBI backend: one handle, begin_work / commit / rollback ---------- */

static SV *ptx_dbi_call0(pTHX_ SV *dbh, const char *meth, SV **err) {
    dSP;
    int count;
    SV *r = NULL;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(dbh);
    PUTBACK;
    count = call_method(meth, G_SCALAR | G_EVAL);
    SPAGAIN;
    if (count > 0) r = SvREFCNT_inc(POPs);
    PUTBACK;
    if (SvTRUE(ERRSV)) { *err = newSVsv(ERRSV); if (r) SvREFCNT_dec(r); r = NULL; }
    FREETMPS; LEAVE;
    return r;
}

/* Punk::Model::DBI->_txn(\%opts, $code, $tx) -> the block's value */
static SV *ptx_dbi_run(pTHX_ SV *opts, SV *code, SV *tx) {
    HV *o    = (opts && SvROK(opts) && SvTYPE(SvRV(opts)) == SVt_PVHV)
               ? (HV *)SvRV(opts) : NULL;
    HV *slot = pdbi_slot_for_opts(aTHX_ o);
    SV *dbh  = pdbi_get(aTHX_ slot, "dbh");
    SV *open = pdbi_get(aTHX_ slot, "txn");
    HV *th   = ptx_hv(aTHX_ tx);
    SV *err  = NULL, *res = NULL, *r;

    if (!(dbh && SvROK(dbh)))
        croak("Punk::Model::DBI: no connection for the transaction");
    if (open && SvTRUE(open))
        croak("Punk::Model::DBI: a transaction is already open on this "
              "connection - nested transactions are not supported, and a "
              "silent join would stop a rollback covering what the outer "
              "block thinks it covers");

    r = ptx_dbi_call0(aTHX_ dbh, "begin_work", &err);
    if (r) SvREFCNT_dec(r);
    if (err) { sv_2mortal(err); croak_sv(err); }

    (void)hv_stores(slot, "txn", newSViv(1));
    (void)hv_stores(th, "handle", newSVsv(dbh));
    (void)hv_stores(th, "active", newSViv(1));

    {   /* the block, trapped: a die is a rollback and a rethrow */
        dSP;
        int count;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(tx);
        PUTBACK;
        count = call_sv(code, G_SCALAR | G_EVAL);
        SPAGAIN;
        if (count > 0) res = SvREFCNT_inc(POPs);
        PUTBACK;
        if (SvTRUE(ERRSV)) { err = newSVsv(ERRSV); if (res) SvREFCNT_dec(res); res = NULL; }
        FREETMPS; LEAVE;
    }

    if (!err) {
        r = ptx_dbi_call0(aTHX_ dbh, "commit", &err);
        if (r) SvREFCNT_dec(r);
    }
    if (err) {
        SV *rerr = NULL;
        r = ptx_dbi_call0(aTHX_ dbh, "rollback", &rerr);
        if (r) SvREFCNT_dec(r);
        if (rerr) SvREFCNT_dec(rerr);   /* the block's error is the one to report */
        (void)hv_stores(slot, "txn", newSViv(0));
        (void)hv_stores(th, "active", newSViv(0));
        sv_2mortal(err);
        croak_sv(err);
    }
    (void)hv_stores(slot, "txn", newSViv(0));
    (void)hv_stores(th, "active", newSViv(0));
    return res ? res : newSV(0);
}

/* ---- the DBIx::Loop backend: $db->txn, with the bridge ---------------------- */

/* capture layout for the two closures */
enum { PTX_CAP_CODE = 0, PTX_CAP_TX, PTX_CAP_DLF };

/* A Punk::Future settled -> the DBIx::Loop::Future the txn is waiting on.
 * Registered as an on_ready reaction, called with the Punk::Future. */
XS_INTERNAL(ptx_pf_ready_cb);
XS_INTERNAL(ptx_pf_ready_cb) {
    dXSARGS;
    AV *cap = punk_clos_cap(aTHX_ cv);
    const dbil_abi *A = punk_dbil(aTHX);
    SV **dlfp = cap ? av_fetch(cap, PTX_CAP_DLF, 0) : NULL;
    SV **txp  = cap ? av_fetch(cap, PTX_CAP_TX, 0)  : NULL;
    punk_future *pf;
    if (!(dlfp && *dlfp) || items < 1 || !pf_is_future(aTHX_ ST(0)))
        XSRETURN_EMPTY;
    /* the block is over once its future settles, whichever way */
    if (txp && *txp && SvROK(*txp))
        (void)hv_stores(ptx_hv(aTHX_ *txp), "active", newSViv(0));
    pf = pf_of(aTHX_ ST(0));
    if (pf->state == PF_DONE) {
        SV **v = (pf->vals && av_len(pf->vals) >= 0) ? av_fetch(pf->vals, 0, 0) : NULL;
        A->future_done1(aTHX_ *dlfp, (v && *v) ? *v : &PL_sv_undef);
    }
    else {
        SV **e = (pf->vals && av_len(pf->vals) >= 0) ? av_fetch(pf->vals, 0, 0) : NULL;
        A->future_fail(aTHX_ *dlfp, (e && *e) ? *e
                       : sv_2mortal(newSVpvs("transaction block failed")));
    }
    XSRETURN_EMPTY;
}

/* The block DBIx::Loop's txn calls with the pinned DBIx::Loop::Txn handle.
 * Records the handle on the Punk::Txn, runs the application's block, and
 * hands back its result - a Punk::Future bridged into a DBIx::Loop::Future,
 * because txn commits as soon as the block returns anything that is not one
 * of its own futures, and a commit before the model's writes have landed is
 * exactly the bug a transaction exists to prevent. */
XS_INTERNAL(ptx_loop_block_cb);
XS_INTERNAL(ptx_loop_block_cb) {
    dXSARGS;
    AV *cap = punk_clos_cap(aTHX_ cv);
    const dbil_abi *A = punk_dbil(aTHX);
    SV *code, *tx, *txh, *res = NULL, *err = NULL;
    HV *th;
    if (!cap || items < 1) croak(PTX_CLS ": the transaction block lost its capture");
    code = *av_fetch(cap, PTX_CAP_CODE, 0);
    tx   = *av_fetch(cap, PTX_CAP_TX, 0);
    txh  = ST(0);
    th   = ptx_hv(aTHX_ tx);
    (void)hv_stores(th, "handle", newSVsv(txh));
    (void)hv_stores(th, "active", newSViv(1));
    {
        dSP;
        int count;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(tx);
        PUTBACK;
        count = call_sv(code, G_SCALAR | G_EVAL);
        SPAGAIN;
        if (count > 0) res = SvREFCNT_inc(POPs);
        PUTBACK;
        if (SvTRUE(ERRSV)) { err = newSVsv(ERRSV); if (res) SvREFCNT_dec(res); res = NULL; }
        FREETMPS; LEAVE;
    }
    if (err) {
        /* DBIx::Loop called this under its own eval: the die is the ROLLBACK */
        (void)hv_stores(th, "active", newSViv(0));
        sv_2mortal(err);
        croak_sv(err);
    }
    if (res && pf_is_future(aTHX_ res)) {
        SV *dlf = A->future_new(aTHX);
        AV *bcap = newAV();
        SV *cb;
        av_store(bcap, PTX_CAP_DLF, SvREFCNT_inc(dlf));
        av_store(bcap, PTX_CAP_TX,  newSVsv(tx));
        cb = punk_closure(aTHX_ ptx_pf_ready_cb, bcap);
        pf_react(aTHX_ pf_of(aTHX_ res), res, PFR_ON_READY, cb);
        SvREFCNT_dec(cb);        /* pf_react keeps its own copy */
        SvREFCNT_dec(res);
        /* `active` stays up until the future settles: ptx_pf_ready_cb */
        ST(0) = sv_2mortal(dlf);
        XSRETURN(1);
    }
    (void)hv_stores(th, "active", newSViv(0));
    ST(0) = res ? sv_2mortal(res) : &PL_sv_undef;
    XSRETURN(1);
}

/* Punk::Model::DBIx::Loop->_txn(\%opts, $code, $tx) -> Punk::Future */
static SV *ptx_loop_run(pTHX_ SV *opts, SV *code, SV *tx) {
    HV *o    = (opts && SvROK(opts) && SvTYPE(SvRV(opts)) == SVt_PVHV)
               ? (HV *)SvRV(opts) : NULL;
    HV *slot = pdl_handle_opts(aTHX_ o);
    SV *db   = pdbi_get(aTHX_ slot, "db");
    const dbil_abi *A = punk_dbil(aTHX);
    AV *cap  = newAV();
    SV *block, *f, *out, *argv[1];
    pdl_pend *p;

    if (!(db && SvROK(db)))
        croak(PDL_CLS ": no connection for the transaction");
    av_store(cap, PTX_CAP_CODE, newSVsv(code));
    av_store(cap, PTX_CAP_TX,   newSVsv(tx));
    block = punk_closure(aTHX_ ptx_loop_block_cb, cap);   /* owns cap */
    argv[0] = block;
    f = pcx_call_meth(aTHX_ db, "txn", argv, 1, 1);
    SvREFCNT_dec(block);                 /* txn holds its own reference */
    if (!f) croak(PDL_CLS ": txn returned no future");

    p = pdl_start(aTHX_ A, slot, &out);
    p->op = PDL_OP_PASS;
    pdl_attach(aTHX_ f, p);
    return out;
}

/* ---- $c->txn --------------------------------------------------------------- */

/* $c->txn($code) / $c->txn($name => $code) */
static SV *ptx_context_txn(pTHX_ SV *c, SV *name, SV *code) {
    AV *av  = pcx_av(aTHX_ c);
    SV *app = pcx_get(aTHX_ av, PCX_APP);
    SV *class, *opts, *tx, *argv[3], *r;
    if (!(code && SvROK(code) && SvTYPE(SvRV(code)) == SVt_PVCV))
        croak(PTX_CLS ": txn takes a coderef - $c->txn(sub { my ($tx) = @_; "
              "... }) or $c->txn(name => sub { ... })");
    if (!(app && SvOK(app)))
        croak(PTX_CLS ": this context has no application");
    opts = ptx_db_opts(aTHX_ app, name, &class);
    {   /* the backend class, loaded if a model has not loaded it yet */
        HV *stash = gv_stashsv(class, 0);
        if (!(stash && gv_fetchmethod_autoload(stash, "_txn", 0))) {
            if (!pk_require_once(aTHX_ SvPV_nolen(class), FALSE))
                croak(PTX_CLS ": backend '%s' failed to load: %s",
                      SvPV_nolen(class), SvPV_nolen(ERRSV));
            stash = gv_stashsv(class, 0);
            if (!(stash && gv_fetchmethod_autoload(stash, "_txn", 0)))
                croak(PTX_CLS ": backend '%s' does not implement _txn - it "
                      "has no transactions", SvPV_nolen(class));
        }
    }
    tx = sv_2mortal(ptx_new(aTHX_ c, app, name, class, opts));
    argv[0] = opts; argv[1] = code; argv[2] = tx;
    r = pcx_call_meth(aTHX_ class, "_txn", argv, 3, 1);
    return r ? r : newSV(0);
}

#endif /* PUNK_TXN_H */

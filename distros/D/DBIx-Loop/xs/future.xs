MODULE = DBIx::Loop        PACKAGE = DBIx::Loop::Future

# The AWAIT_* methods are the Future::AsyncAwait::Awaitable API, which is how
# `await $f` reaches one of these inside an async sub. Most are aliases of the
# method they correspond to, so the protocol costs nothing beyond the XSUB it
# already resolves to.
#
# This future has no cancelled state - see AWAIT_IS_CANCELLED - so the three
# cancellation methods take the constant-false/no-op form the specification
# provides for implementations without it.

PROTOTYPES: DISABLE

SV *
new(class)
        SV *class
    CODE:
        RETVAL = dbil_future_new(aTHX_
            SvROK(class) ? sv_reftype(SvRV(class), 1) : SvPV_nolen(class));
    OUTPUT:
        RETVAL

# An already-settled future. Nothing can have registered on one this new, so
# neither settles through fire(): the callback queue is empty by construction.
SV *
AWAIT_NEW_DONE(class, ...)
        SV *class
    CODE:
    {
        dbil_future *f;
        AV *res = newAV();
        int i;
        RETVAL = dbil_future_new(aTHX_
            SvROK(class) ? sv_reftype(SvRV(class), 1) : SvPV_nolen(class));
        f = dbil_future_of(aTHX_ RETVAL);
        for (i = 1; i < items; i++) av_push(res, newSVsv(ST(i)));
        f->result = newRV_noinc((SV *)res);
        f->state  = 1;
    }
    OUTPUT:
        RETVAL

SV *
AWAIT_NEW_FAIL(class, ...)
        SV *class
    CODE:
    {
        dbil_future *f;
        RETVAL = dbil_future_new(aTHX_
            SvROK(class) ? sv_reftype(SvRV(class), 1) : SvPV_nolen(class));
        f = dbil_future_of(aTHX_ RETVAL);
        f->error = newSVsv(items > 1 ? ST(1)
                                     : sv_2mortal(newSVpvs("Failed\n")));
        f->state = 2;
    }
    OUTPUT:
        RETVAL

# A new pending future of the same class. The instance is not modified and no
# per-instance state is copied; this future carries no loop of its own, so
# there is nothing else to hand on.
SV *
AWAIT_CLONE(self)
        SV *self
    CODE:
        (void)dbil_future_of(aTHX_ self);   /* croak early if not one */
        RETVAL = dbil_future_new(aTHX_ sv_reftype(SvRV(self), 1));
    OUTPUT:
        RETVAL

SV *
done(self, ...)
        SV *self
    ALIAS:
        AWAIT_DONE = 1
    CODE:
    {
        dbil_future *f = dbil_future_of(aTHX_ self);
        AV *res = newAV();
        int i;
        PERL_UNUSED_VAR(ix);
        if (f->state)
            croak("DBIx::Loop::Future: already settled");
        for (i = 1; i < items; i++) av_push(res, newSVsv(ST(i)));
        f->result = newRV_noinc((SV *)res);
        f->state  = 1;
        dbil_future_fire(aTHX_ self, f);
        RETVAL = SvREFCNT_inc(self);
    }
    OUTPUT:
        RETVAL

# Declared with a slurpy tail only so AWAIT_FAIL can share the body: the
# protocol may hand a failure more than one value, where fail() documents
# exactly one. The arity check below is the one xsubpp generated before.
SV *
fail(self, ...)
        SV *self
    ALIAS:
        AWAIT_FAIL = 1
    CODE:
    {
        dbil_future *f;
        PERL_UNUSED_VAR(ix);
        if (items < 2)
            croak("Usage: DBIx::Loop::Future::fail(self, error)");
        f = dbil_future_of(aTHX_ self);
        if (f->state)
            croak("DBIx::Loop::Future: already settled");
        f->error = newSVsv(ST(1));
        f->state = 2;
        dbil_future_fire(aTHX_ self, f);
        RETVAL = SvREFCNT_inc(self);
    }
    OUTPUT:
        RETVAL

SV *
on_ready(self, cb)
        SV *self
        SV *cb
    ALIAS:
        AWAIT_ON_READY = 1
    CODE:
    {
        dbil_future *f = dbil_future_of(aTHX_ self);
        PERL_UNUSED_VAR(ix);
        if (!SvROK(cb) || SvTYPE(SvRV(cb)) != SVt_PVCV)
            croak("DBIx::Loop::Future->on_ready: need a coderef");
        if (f->state) {
            dSP;
            ENTER; SAVETMPS; PUSHMARK(SP);
            EXTEND(SP, 1); PUSHs(self); PUTBACK;
            call_sv(cb, G_DISCARD | G_EVAL);
            if (SvTRUE(ERRSV))
                warn("DBIx::Loop::Future: on_ready callback died: %s",
                     SvPV_nolen(ERRSV));
            FREETMPS; LEAVE;
        } else {
            av_push(f->cbs, newSVsv(cb));
        }
        RETVAL = SvREFCNT_inc(self);
    }
    OUTPUT:
        RETVAL

# then($on_done [, $on_fail]) / else($on_fail) -> a new future.
#
# The continuation is an AV on the callback queue, not a closure, so a chain
# costs one array per link and settling it runs no Perl frame but the user's
# own callbacks. `else` is the same thing with only the failure half, which is
# why it is an ALIAS rather than a second body.
SV *
then(self, on_done = &PL_sv_undef, on_fail = &PL_sv_undef)
        SV *self
        SV *on_done
        SV *on_fail
    ALIAS:
        else = 1
    CODE:
    {
        SV *next;
        /* else($cb): the one argument is the failure handler */
        if (ix == 1) { on_fail = on_done; on_done = &PL_sv_undef; }
        (void)dbil_future_of(aTHX_ self);         /* croak early if not one */
        next = dbil_future_new(aTHX_ "DBIx::Loop::Future");
        dbil_then_attach(aTHX_ self, next, on_done, on_fail);
        RETVAL = next;
    }
    OUTPUT:
        RETVAL

int
is_ready(self)
        SV *self
    ALIAS:
        AWAIT_IS_READY = 1
    CODE:
        PERL_UNUSED_VAR(ix);
        RETVAL = dbil_future_of(aTHX_ self)->state != 0;
    OUTPUT:
        RETVAL

int
is_done(self)
        SV *self
    CODE:
        RETVAL = dbil_future_of(aTHX_ self)->state == 1;
    OUTPUT:
        RETVAL

int
is_failed(self)
        SV *self
    CODE:
        RETVAL = dbil_future_of(aTHX_ self)->state == 2;
    OUTPUT:
        RETVAL

# This future settles exactly once, into done or failed; there is no third
# outcome and no cancel method to reach one. The protocol allows an
# implementation without cancellation to answer constantly here and to ignore
# the two registration methods, which is what these do.
int
AWAIT_IS_CANCELLED(self)
        SV *self
    CODE:
        (void)dbil_future_of(aTHX_ self);   /* croak early if not one */
        RETVAL = 0;
    OUTPUT:
        RETVAL

void
AWAIT_ON_CANCEL(self, thing)
        SV *self
        SV *thing
    ALIAS:
        AWAIT_CHAIN_CANCEL = 1
    CODE:
        PERL_UNUSED_ARG(self);
        PERL_UNUSED_ARG(thing);
        PERL_UNUSED_VAR(ix);

SV *
failure(self)
        SV *self
    CODE:
    {
        dbil_future *f = dbil_future_of(aTHX_ self);
        RETVAL = (f->state == 2 && f->error) ? newSVsv(f->error) : newSV(0);
    }
    OUTPUT:
        RETVAL

# get already reads rather than waits, which is what AWAIT_GET wants.
# AWAIT_WAIT is meant to run the event system until the future is ready, and
# this distribution has no blocking wait to run - awaiting is the loop's job -
# so it is the same method, and a toplevel await on a pending future gets the
# same advice as a premature get.
void
get(self)
        SV *self
    ALIAS:
        AWAIT_GET  = 1
        AWAIT_WAIT = 2
    PPCODE:
    {
        dbil_future *f = dbil_future_of(aTHX_ self);
        PERL_UNUSED_VAR(ix);
        if (f->state == 0)
            croak("DBIx::Loop::Future->get: future is not ready "
                  "(await it on your event loop first)");
        if (f->state == 2)
            croak_sv(f->error ? f->error : sv_2mortal(newSVpvs("failed")));
        {
            AV *res = (AV *)SvRV(f->result);
            SSize_t i, n = av_len(res) + 1;
            EXTEND(SP, n);
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(res, i, 0);
                PUSHs(e && *e ? sv_2mortal(newSVsv(*e)) : &PL_sv_undef);
            }
        }
    }

MODULE = Punk::Mailer    PACKAGE = Punk::Plugin::Mailer

# plugin 'Mailer' => \%opts, via Punk: builds the engine, reads mail_dir,
# declares the queue task, installs the helpers (pmail_plugin.h).
void
register(class, app, opts = &PL_sv_undef)
        SV *class
        SV *app
        SV *opts
    CODE:
        PERL_UNUSED_VAR(class);
        pm_register(aTHX_ app, opts);

# The configuration for an application class - the test and introspection
# seam; the hash is live.
SV *
state_for(...)
    CODE:
    {
        SV **e = NULL;
        if (items > 0 && PM_PLUGIN_STATE) {
            STRLEN kl;
            const char *k = SvPV_const(ST(items - 1), kl);
            e = hv_fetch(PM_PLUGIN_STATE, k, (I32)kl, 0);
        }
        RETVAL = (e && *e) ? newSVsv(*e) : newSV(0);
    }
    OUTPUT:
        RETVAL

# The Punk::Mailer an application class registered, for code that has the
# class and no context - a job body in a site, a script.
SV *
engine_for(...)
    CODE:
    {
        SV **e = NULL;
        if (items > 0 && PM_PLUGIN_STATE) {
            STRLEN kl;
            const char *k = SvPV_const(ST(items - 1), kl);
            e = hv_fetch(PM_PLUGIN_STATE, k, (I32)kl, 0);
        }
        if (!(e && *e && SvROK(*e)))
            croak("Punk::Plugin::Mailer: no application class has registered plugin 'Mailer'%s",
                  items > 0 ? " under that name" : "");
        {
            SV *eng = pm_hget(aTHX_ (HV *)SvRV(*e), "engine");
            RETVAL = eng ? newSVsv(eng) : newSV(0);
        }
    }
    OUTPUT:
        RETVAL

MODULE = Punk::Mailer    PACKAGE = Punk::Mailer::Job

# The task body behind `later`: ($job, $class, \%spec). accepted returns
# the job's result; deferred and failed die so the queue retries; rejected
# notes `final` and dies, since no retry will change a 5xx.
SV *
send(job, klass, spec)
        SV *job
        SV *klass
        SV *spec
    CODE:
        RETVAL = pm_job_send(aTHX_ job, klass, spec);
    OUTPUT:
        RETVAL

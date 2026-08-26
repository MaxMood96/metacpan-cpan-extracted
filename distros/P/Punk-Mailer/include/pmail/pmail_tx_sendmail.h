#ifndef PMAIL_TX_SENDMAIL_H
#define PMAIL_TX_SENDMAIL_H

#include <signal.h>
#include <sys/wait.h>

/* pmail_tx_sendmail.h - a local MTA's command-line interface.
 *
 * `command` is an argv list, never a string: it is run with execvp, so no
 * shell ever sees it and a recipient address cannot become a shell
 * expression. `-f <sender>` and the envelope recipients are appended, so
 * Bcc works without asking sendmail to parse headers (-t), and the
 * message is streamed straight from the builder into the child's stdin -
 * an attachment never sits in this process. A non-zero exit is a Result,
 * not an exception.
 *
 * The default command carries -i, because without it a line holding a
 * single "." ends the message for most sendmails - and the builder does
 * not dot-stuff for this transport, since the MTA does not unstuff. */

static const char *const PMAIL_SENDMAIL_OPTS[] = { "command" };

static SV *pmail_sendmail_new(pTHX_ const char *class, SV *opts_sv)
{
    HV *opts = pmail_opts_hv(aTHX_ opts_sv, "the sendmail transport");
    HV *self = newHV();
    SV *cmd = pmail_opt(aTHX_ opts, "command");
    AV *argv;
    pmail_opts_check(aTHX_ "the sendmail transport", opts, PMAIL_SENDMAIL_OPTS, 1);
    if (!cmd) {
        argv = newAV();
        av_push(argv, newSVpvs("/usr/sbin/sendmail"));
        av_push(argv, newSVpvs("-i"));
    }
    else {
        SSize_t i, n;
        if (!SvROK(cmd) || SvTYPE(SvRV(cmd)) != SVt_PVAV)
            croak("Punk::Mailer: the sendmail transport's 'command' is a list of "
                  "arguments, not a shell string");
        n = av_len((AV *)SvRV(cmd)) + 1;
        if (n == 0) croak("Punk::Mailer: the sendmail transport's 'command' is empty");
        argv = newAV();
        for (i = 0; i < n; i++) {
            SV **e = av_fetch((AV *)SvRV(cmd), i, 0);
            if (!e || !*e || !SvOK(*e) || SvROK(*e)) {
                SvREFCNT_dec((SV *)argv);
                croak("Punk::Mailer: the sendmail transport's 'command' has a "
                      "non-string element");
            }
            av_push(argv, newSVsv(*e));
        }
    }
    (void)hv_stores(self, "command", newRV_noinc((SV *)argv));
    return pmail_bless(aTHX_ self, class);
}

/* what must be undone if the build croaks mid-stream: the child would
 * otherwise wait forever on a pipe nobody closes */
typedef struct { int fd; pid_t pid; struct sigaction old_pipe; int restored; } pmail_child;

static void pmail_child_cleanup(pTHX_ void *p)
{
    pmail_child *c = (pmail_child *)p;
    if (c->fd >= 0) { close(c->fd); c->fd = -1; }
    if (c->pid > 0) {
        int st;
        while (waitpid(c->pid, &st, 0) < 0 && errno == EINTR) { /* retry */ }
        c->pid = 0;
    }
    if (!c->restored) { sigaction(SIGPIPE, &c->old_pipe, NULL); c->restored = 1; }
}

static SV *pmail_sendmail_deliver(pTHX_ SV *self_sv, SV *spec_sv, SV *env_sv)
{
    HV *self = pmail_self(aTHX_ self_sv, "deliver");
    HV *spec = pmail_spec_hv(aTHX_ spec_sv, "deliver");
    HV *env = pmail_spec_hv(aTHX_ env_sv, "deliver");
    AV *cmd = (AV *)SvRV(pmail_hv_get(aTHX_ self, "command"));
    AV *rcpts = pmail_env_to(aTHX_ env);
    SV *from = pmail_env_from(aTHX_ env);
    SSize_t ncmd = av_len(cmd) + 1, nr = av_len(rcpts) + 1, i;
    char **argv;
    int fds[2];
    pid_t pid;
    pmail_child child;
    struct sigaction ign;
    pmail_sink s;
    int wrote, wrote_errno = 0;
    int status = 0;
    SV *result, *id = NULL;
    SV *bytes_for_id;

    /* the message is validated before anything is forked, so a bad spec is
     * a croak with no child to clean up */
    {
        pmail_msg m;
        ENTER;
        pmail_msg_read(aTHX_ spec, &m);
        LEAVE;
    }

    Newxz(argv, ncmd + 2 + nr + 1, char *);
    SAVEFREEPV(argv);
    for (i = 0; i < ncmd; i++) argv[i] = SvPV_nolen(*av_fetch(cmd, i, 0));
    argv[ncmd] = (char *)"-f";
    argv[ncmd + 1] = SvPV_nolen(from);
    for (i = 0; i < nr; i++) argv[ncmd + 2 + i] = SvPV_nolen(*av_fetch(rcpts, i, 0));
    argv[ncmd + 2 + nr] = NULL;

    if (pipe(fds) != 0)
        return pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "sendmail", NULL,
                                 "cannot create a pipe: %s", strerror(errno));
    PERL_FLUSHALL_FOR_CHILD;
    pid = fork();
    if (pid < 0) {
        int e = errno;
        close(fds[0]); close(fds[1]);
        return pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "sendmail", NULL,
                                 "cannot fork: %s", strerror(e));
    }
    if (pid == 0) {
        /* the child: stdin from the pipe, then the command */
        close(fds[1]);
        if (fds[0] != 0) { dup2(fds[0], 0); close(fds[0]); }
        signal(SIGPIPE, SIG_DFL);
        execvp(argv[0], argv);
        _exit(127);
    }
    close(fds[0]);

    child.fd = fds[1]; child.pid = pid; child.restored = 0;
    memset(&ign, 0, sizeof ign);
    ign.sa_handler = SIG_IGN;
    sigemptyset(&ign.sa_mask);
    sigaction(SIGPIPE, &ign, &child.old_pipe);
    ENTER;
    SAVEDESTRUCTOR_X(pmail_child_cleanup, &child);

    pmail_sink_fd(&s, child.fd);
    wrote = pmail_build(aTHX_ spec, &s);
    wrote_errno = errno;        /* before close/waitpid/sigaction touch it */
    close(child.fd); child.fd = -1;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) { /* retry */ }
    child.pid = 0;
    sigaction(SIGPIPE, &child.old_pipe, NULL); child.restored = 1;
    LEAVE;

    /* the Message-ID, from a second render of the headers only - cheaper
     * than keeping the bytes that went down the pipe */
    {
        HV *copy = newHVhv(spec);
        SV *ref = sv_2mortal(newRV_noinc((SV *)copy));
        (void)hv_stores(copy, "attachments", newSV(0));
        bytes_for_id = sv_2mortal(pmail_build_bytes(aTHX_ copy));
        id = pmail_message_id_of(aTHX_ bytes_for_id);
        if (id) sv_2mortal(id);
        (void)ref;
    }

    /* the exit status is read first even when the write failed: a command
     * that cannot be exec'd dies before it reads a byte, so whether the
     * parent saw EPIPE is a race against the fork - and 127 says far more
     * than "broken pipe" does. Only a child that exited 0 leaves the write
     * failure as the whole story. */
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0)
        result = wrote != 0
            ? pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "sendmail", id,
                                "%s stopped reading: %s", argv[0], strerror(wrote_errno))
            : pmail_result_newf(aTHX_ PMAIL_ST_ACCEPTED, 0, NULL, "sendmail", id,
                                "%s accepted the message", argv[0]);
    else if (WIFEXITED(status))
        result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, (IV)WEXITSTATUS(status), NULL,
                                   "sendmail", id, "%s exited %d%s", argv[0],
                                   WEXITSTATUS(status),
                                   WEXITSTATUS(status) == 127 ? " (not found or not executable)" : "");
    else
        result = pmail_result_newf(aTHX_ PMAIL_ST_FAILED, 0, NULL, "sendmail", id,
                                   "%s was killed by signal %d", argv[0],
                                   WIFSIGNALED(status) ? WTERMSIG(status) : 0);
    return result;
}

#endif /* PMAIL_TX_SENDMAIL_H */

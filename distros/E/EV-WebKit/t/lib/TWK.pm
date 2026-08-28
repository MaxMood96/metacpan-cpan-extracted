package TWK;
use v5.10; use strict; use warnings;
use Test::More;
use EV::WebKit ();

# Whether a browser can actually START here, which the typelibs and $DISPLAY do
# NOT tell you. Where WebKitGTK's bubblewrap sandbox cannot initialise -- a
# container, or a host with unprivileged user namespaces restricted -- the web
# process dies and the API call aborts the whole program with SIGABRT from
# inside a GI call. That cannot be trapped, so without this every
# browser-touching file dies with NO PLAN AND NO TAP, which a CPAN smoker
# reports as a mass FAIL rather than a skip. This project's own CI measured 55
# of 64 programs dying that way on a stock GitHub runner.
#
# So find out in a CHILD, which is allowed to die, and turn it into a skip with
# the one-line fix in the message.
# Memoised WITHIN a process only, deliberately. An earlier version cached the
# answer in a file under tmpdir keyed on $DISPLAY, on the theory that
# `xvfb-run -a` takes a fresh display each run. It does not -- `-a` picks the
# lowest FREE display, which is the same number every time (measured: :101 on
# three consecutive runs). So that cache outlived the environment it described,
# in both directions:
#
#   - a cached 0 survived the user doing exactly what the skip message tells
#     them to do, because the key ignored
#     WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS -- they set it, reran, and were
#     skipped again with the same message, fixable only by deleting an
#     undocumented dotfile in /tmp;
#   - a cached 1 waved every file past the gate into the abort this gate exists
#     to prevent, on a host whose namespaces had since been restricted.
#
# It was also shared between concurrent runs on one machine. The probe costs
# about half a second per file; the whole suite pays roughly 45 seconds for it,
# which is a great deal cheaper than silently skipping or aborting everything.
my $STARTS;
sub _browser_starts {
    return $STARTS if defined $STARTS;
    my $inc  = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" } @INC;
    # It has to LOAD something. Constructing a browser and quitting does not
    # touch the web process, so it succeeds even where the sandbox is broken --
    # the abort comes later, the first time a page is actually needed.
    my $prog = 'alarm 30; use EV; use EV::WebKit; '
             . 'my $b = EV::WebKit->new(window => [80,60], ephemeral => 1, timeout => 8); '
             . 'my $ok = 0; '
             . '$b->load_html(q{<p>x</p>}, sub { $ok = !defined $_[1]; EV::break }); '
             . 'my $wd = EV::timer(20, 0, sub { EV::break }); EV::run; '
             . '$b->quit; print "EVWK-STARTS\n" if $ok;';
    my $out = `'$^X' $inc -e '$prog' 2>&1`;
    return $STARTS = (defined $out && $out =~ /EVWK-STARTS/) ? 1 : 0;
}

sub skip_unless_available {
    plan(skip_all => 'WebKit-6.0/Gtk-4.0 typelibs not available')
        unless EV::WebKit::available();
    plan(skip_all => 'no X display (run tests under `xvfb-run -a`)')
        unless defined $ENV{DISPLAY} && length $ENV{DISPLAY};
    plan(skip_all => 'a browser cannot start here: WebKit\'s sandbox failed to '
                   . 'initialise (usual in containers, and where unprivileged '
                   . 'user namespaces are restricted). Set '
                   . 'WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1, or grant the '
                   . 'container the permissions bubblewrap needs')
        unless _browser_starts();
}

sub run_with_timeout {
    my ($secs) = @_;
    my $t = EV::timer($secs, 0, sub { fail("timeout after ${secs}s"); EV::break });
    EV::run;
}
1;

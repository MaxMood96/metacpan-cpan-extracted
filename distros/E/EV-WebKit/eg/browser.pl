#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

# A real, visible browser window -- optionally one you can drive from elsewhere.
#
#     perl eg/browser.pl [uri]
#     perl eg/browser.pl --control /path/to.sock [uri]
#     perl eg/browser.pl --control                    # socket path chosen for you
#
# Give --control a path (attached or as the next word), or give it nothing AND
# no uri after it. `--control https://perl.org` is the one shape that misfires:
# Getopt::Long takes the next word as the path, so it would listen on a socket
# named after the URI and then load the default page. Spell that one
# `--control= https://perl.org`.
#
# Needs a real display -- EV::WebKit never starts an X server, it uses the one
# you give it. Just run it from a desktop session (DISPLAY is already set).
# Under xvfb-run you get the same browser with nobody to look at it.
#
# Type a URI in the address bar and press Enter; back / forward / reload work;
# right-click gives you Inspect Element. Close the window to exit.
#
# With --control it also listens on a unix socket, so another process can drive
# this same window while you watch (and while you click around in it yourself):
#
#     perl eg/browser.pl --control /tmp/evwk.sock &
#     perl eg/control.pl /tmp/evwk.sock https://perl.org
#
# NOTE: anyone who can open that socket can run arbitrary JavaScript in this
# browser and read every cookie it holds. It is created 0600 for that reason.

use Getopt::Long;
use EV;
use EV::WebKit;

$| = 1;   # so the running commentary shows up even when piped to a file

my $control;
GetOptions('control:s' => \$control)
    or die "usage: browser.pl [--control[=path]] [uri]\n";

die "WebKitGTK 6.0 / GTK4 typelibs not available\n" unless EV::WebKit->available;
die "no \$DISPLAY -- run this from a desktop session (it needs a real screen)\n"
    unless defined $ENV{DISPLAY} && length $ENV{DISPLAY};

my $uri = shift // 'https://example.com';

my $b;
$b = EV::WebKit->new(
    window   => [1100, 800],
    chrome   => 1,         # header bar: back / forward / reload + address entry
    title    => 'EV::WebKit',
    devtools => 1,         # right-click -> Inspect Element

    # Closing the window tears the instance down for us; EV::break is what ends
    # the program, and on_close is safe to call it from -- it is deferred to a
    # clean tick, unlike on_dialog/on_policy/on_console, which run nested.
    on_close => sub { say '[closed]'; EV::break },

    on_load    => sub { printf "[load ] %-50s %s\n", $b->uri // '?', $b->title // '' },
    on_error   => sub { say "[error] $_[0]" },
    on_console => sub { say "[js   ] $_[0]" },
    on_dialog  => sub {
        my ($d) = @_;
        say sprintf '[dialog] %s: %s', $d->type, $d->message;
        $d->accept;        # a real browser would ask you; just say yes
    },
);

# Optionally put this window on a socket, so another process can drive it while
# you watch. The server is a plain consumer of the public API -- it can do
# nothing to the browser that this script could not do itself.
my $ctl;
if (defined $control) {
    require EV::WebKit::Control;
    $control ||= ($ENV{XDG_RUNTIME_DIR} || '/tmp') . "/ev-webkit-$$.sock";
    $ctl = EV::WebKit::Control->listen($b, path => $control);
    say "[ctl  ] listening on $control";
    say "[ctl  ] anyone who can open that socket owns this browser -- it is 0600 for a reason";
}

say "opening $uri ... (close the window to exit)";

$b->go($uri, sub {
    my (undef, $err) = @_;
    return say "[error] $err" if $err;

    # the element API and the JS bridge, in the window you are looking at
    $b->find('h1', sub {
        my ($el) = @_;
        $el->text(sub { say "[h1   ] $_[0]" }) if $el;
    });
});

EV::run;   # returns when you close the window
say 'bye.';

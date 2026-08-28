#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

# Drive a browser that is already running somewhere else.
#
#     perl eg/browser.pl --control /tmp/evwk.sock &     # in one terminal
#     perl eg/control.pl /tmp/evwk.sock https://perl.org
#
# The window you are looking at navigates. Nothing here starts a browser: it
# attaches to one, does its work, and leaves it running -- which is the point.
# The next script to attach picks up the same session, cookies, logins and all.

use EV::WebKit::Client;

$| = 1;

my $path = shift or die <<'USAGE';
usage: control.pl <socket> [uri]

Start a browser to control with:
    perl eg/browser.pl --control /tmp/evwk.sock
USAGE
my $uri = shift;

my $c = EV::WebKit::Client->connect($path);

# The greeting says where the browser already is -- so a script attaching to a
# long-lived session knows what it is looking at before it touches anything.
my $hello = $c->hello;
say 'attached: ', ($hello->{uri} // '(nothing loaded)'),
    ($hello->{title} ? "  -- $hello->{title}" : '');

if (defined $uri) {
    say "navigating to $uri ...";
    eval { $c->go($uri); 1 } or die "navigation failed: $@";
}

say 'title: ', ($c->title // '(none)');

if (my $h1 = $c->find('h1')) {
    say 'h1:    ', $h1->text;
}

say 'links: ', scalar @{ $c->find_all('a') };

# Anything EV::WebKit can do, this can do -- it is the same API over a socket.
say 'ua:    ', $c->script('return navigator.userAgent');

$c->disconnect;
say 'detached (the browser is still running)';

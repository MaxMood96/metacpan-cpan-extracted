#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

# Intercept every request the browser makes: log it, block it, rewrite it, or
# answer it locally without touching the network.
#
#     xvfb-run -a perl eg/intercept.pl [uri]
#
# Needs Proxy::Impersonate 0.01 (and its Curl::Impersonate toolchain): WebKitGTK
# 6.0 exposes no mutable request hook of its own, so this routes the browser
# through the in-process MITM proxy, which is the one place the plaintext exists.
#
# TWO THINGS THAT WILL CONFUSE YOU IF NOBODY SAYS THEM:
#
#   * Requests to LOCAL addresses are not intercepted. WebKit routes localhost
#     and private addresses directly, bypassing the proxy, so this script needs
#     a real external URI to have anything to show.
#   * Your TLS fingerprint changes. The proxy always re-originates through
#     libcurl-impersonate; there is no passthrough. Pass a fingerprint => too if
#     you want that to be a deliberate choice rather than a side effect.

use EV;
use EV::WebKit;

my $uri = shift(@ARGV) // 'https://example.com/';

die "WebKitGTK 6.0 / GTK4 typelibs not available\n" unless EV::WebKit->available;
unless (eval { require Proxy::Impersonate; Proxy::Impersonate->VERSION('0.01'); 1 }) {
    die "on_request needs Proxy::Impersonate 0.01 (found "
      . (eval { Proxy::Impersonate->VERSION } // 'nothing') . ")\n";
}

my @log;

my $b = EV::WebKit->new(
    window      => [1024, 768],
    timeout     => 30,
    fingerprint => 'windows-chrome',   # so the connection fingerprint is chosen, not accidental
    on_error    => sub { warn "browser error: $_[0]\n" },

    on_request  => sub {
        my ($req) = @_;
        push @log, "$req->{method} $req->{url}";

        # 1. BLOCK: refuse a whole class of request, with a visible answer.
        if ($req->{host} =~ /(?:^|\.)(?:doubleclick|googlesyndication)\./) {
            return { status => 403, body => 'blocked by eg/intercept.pl' };
        }

        # 2. MOCK: answer locally, without the network seeing anything.
        if ($req->{url} =~ m{/robots\.txt$}) {
            return { status => 200,
                     headers => { 'content-type' => 'text/plain' },
                     body    => "User-agent: *\nDisallow: /\n" };
        }

        # 3. REWRITE: change the request that does go out. Anything set here
        #    overrides curl-impersonate's own template header of the same name.
        $req->{headers}{'x-intercepted-by'} = 'eg/intercept.pl';
        return;   # ...and let it proceed
    },
);

say "proxy listening on 127.0.0.1:", $b->proxy_port // '(none)';
say "navigating to $uri\n";

$b->go($uri, sub {
    my (undef, $err) = @_;
    say $err ? "navigation failed: $err" : 'navigation ok; title: ' . ($b->title // '(none)');

    say "\nrequests seen (", scalar @log, "):";
    say "  $_" for @log[0 .. ($#log < 9 ? $#log : 9)];
    say '  ...' if @log > 10;

    # Prove the mock is served from here rather than from the origin.
    $b->script('return fetch("/robots.txt").then(r => r.text())', sub {
        my ($body, $serr) = @_;
        # no /r here: it needs 5.14 and this dist declares 5.010.
        my $shown = $body // '';
        $shown =~ s/\s+/ /g;
        say "\nfetched /robots.txt through the hook: ",
            $serr ? "failed: $serr" : $shown;
        EV::break;
    });
});

EV::run;
$b->quit;

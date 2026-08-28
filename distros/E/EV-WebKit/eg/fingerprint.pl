#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

# Present as a different, coherent device -- and show what the page actually
# sees, rather than asking you to take it on faith.
#
#     xvfb-run -a perl eg/fingerprint.pl [profile] [uri]
#     xvfb-run -a perl eg/fingerprint.pl pixel-chrome
#
# Profiles: windows-chrome, macos-safari, iphone-safari, pixel-chrome.
#
# Without a uri it reports against a local page, so it needs no network. Give it
# one (e.g. a fingerprinting test site) to see the same values through a real
# page's eyes.
#
# Read the Ceiling section of EV::WebKit's POD before trusting this for anything
# that matters: it is thorough, not perfect, and the residuals are documented.

use EV;
use EV::WebKit;

my $profile = shift(@ARGV) // 'windows-chrome';
my $uri     = shift(@ARGV);

die "WebKitGTK 6.0 / GTK4 typelibs not available\n" unless EV::WebKit->available;
unless (EV::WebKit->fingerprint_available) {
    die "the web-process extension was not built at install -- fingerprint is unavailable\n";
}
my @known = EV::WebKit->fingerprint_profiles;
die "unknown profile '$profile' (have: @known)\n" unless grep { $_ eq $profile } @known;

my $b = EV::WebKit->new(
    window      => [1280, 900],
    fingerprint => $profile,
    # A seed additionally perturbs canvas/audio/WebGL READBACK, so a hash of the
    # rendered output differs from this host's. Optional, and off by default
    # because it is detectable in its own way (again: see the Ceiling).
    seed        => 12345,
    on_error    => sub { warn "browser error: $_[0]\n" },
);

# What the profile claims, from the Perl side.
my $fp = $b->fingerprint;
say "profile: $profile";
say "  UA:        $fp->{user_agent}";
say "  platform:  $fp->{platform}";
say "  vendor:    $fp->{vendor}";
say "  screen:    ", join('x', @{ $fp->{screen} }[0,1]), " @ dpr ", $fp->{devicePixelRatio} // 1;
say "  webgl:     $fp->{webgl_renderer}";

$b->mock_scheme('fp', sub { ('<html><title>fp</title><body>probe</body></html>', 'text/html') });

my $target = $uri // 'fp://local/probe';
$b->go($target, sub {
    my (undef, $err) = @_;
    if ($err) { warn "navigation failed: $err\n"; return EV::break }

    # ...and what the PAGE sees. These are the values a fingerprinter reads.
    $b->script(<<'JS', sub {
      const gl = document.createElement('canvas').getContext('webgl');
      const dbg = gl && gl.getExtension('WEBGL_debug_renderer_info');
      return JSON.stringify({
        ua:        navigator.userAgent,
        platform:  navigator.platform,
        vendor:    navigator.vendor,
        languages: navigator.languages,
        cores:     navigator.hardwareConcurrency,
        memory:    navigator.deviceMemory,
        touch:     navigator.maxTouchPoints,
        screen:    [screen.width, screen.height, screen.colorDepth],
        dpr:       window.devicePixelRatio,
        coarse:    matchMedia('(pointer: coarse)').matches,
        renderer:  dbg ? gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) : null,
        maxTex:    gl ? gl.getParameter(gl.MAX_TEXTURE_SIZE) : null,
        uaData:    typeof navigator.userAgentData,
        pdf:       navigator.pdfViewerEnabled,
        plugins:   navigator.plugins.length,
        rtc:       ('RTCPeerConnection' in window),
      }, null, 1);
JS
        my ($json, $serr) = @_;
        if ($serr) { warn "probe failed: $serr\n"; return EV::break }
        say "\nwhat the page sees:";
        say $json;
        EV::break;
    });
});

EV::run;
$b->quit;

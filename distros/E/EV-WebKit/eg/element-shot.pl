#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

# Screenshot a single ELEMENT, by cropping a page capture to its box.
#
#     xvfb-run -a perl eg/element-shot.pl [uri] [css-selector]
#     xvfb-run -a perl eg/element-shot.pl https://www.perl.org/ '#pagestart'
#
# EV::WebKit captures pages, not elements: cropping needs an image library, and
# the distribution does not depend on one for a single method. So this is the
# recipe rather than an API -- $el->box gives you the rectangle, screenshot
# gives you the pixels, and any imaging module does the rest. Imager is used
# here because it is common and pure-ish; Image::Magick or GD would do as well.
#
# Optional dependency, checked at run time: with no Imager you still get the
# full-page PNG and a message saying what was skipped.

use EV;
use EV::WebKit;
use File::Temp qw(tempdir);
use File::Spec;

my $uri = shift(@ARGV) // 'https://www.perl.org/';
my $sel = shift(@ARGV) // 'h1';

die "WebKitGTK 6.0 / GTK4 typelibs not available\n" unless EV::WebKit->available;

my $have_imager = eval { require Imager; 1 };
say $have_imager ? "Imager $Imager::VERSION found -- will crop"
                 : "Imager not installed -- capturing the full page only";

my $dir  = tempdir(CLEANUP => 0);
my $full = File::Spec->catfile($dir, 'page.png');
my $crop = File::Spec->catfile($dir, 'element.png');

my $b = EV::WebKit->new(
    window   => [1280, 900],
    timeout  => 30,
    on_error => sub { warn "browser error: $_[0]\n" },
);

$b->go($uri, sub {
    my (undef, $err) = @_;
    if ($err) { warn "navigation failed: $err\n"; return EV::break }

    # A 4xx/5xx still "succeeds" as a navigation -- see $b->status in the POD --
    # so check it before cropping something out of an error page.
    my $st = $b->status // 0;
    if ($st >= 400) { warn "server said $st\n"; return EV::break }

    $b->find($sel, sub {
        my ($el, $ferr) = @_;
        if ($ferr)  { warn "find failed: $ferr\n"; return EV::break }
        if (!$el)   { warn "no element matches '$sel'\n"; return EV::break }

        $el->box(sub {
            my ($box, $berr) = @_;
            if ($berr) { warn "box failed: $berr\n"; return EV::break }
            # undef means the element is not rendered at all -- there is nothing
            # to crop, and a zero-size crop would be a confusing way to say so.
            if (!$box) { warn "'$sel' is not rendered (display:none?)\n"; return EV::break }
            printf "element: %.0fx%.0f at page (%.0f, %.0f)\n",
                   $box->{width}, $box->{height}, $box->{page_x}, $box->{page_y};

            # Capture the WHOLE document, not the viewport: box's page_x/page_y
            # are document coordinates, so no scrolling is needed and an element
            # below the fold works without any extra dance.
            $b->screenshot($full, full => 1, sub {
                my (undef, $serr) = @_;
                if ($serr) { warn "screenshot failed: $serr\n"; return EV::break }
                say "page shot: $full";
                return EV::break unless $have_imager;

                # innerWidth is needed to work out the scale -- see below.
                $b->script('return window.innerWidth', sub {
                    my ($inner_w) = @_;
                    crop($full, $crop, $box, $inner_w);
                    EV::break;
                });
            });
        });
    });
});

EV::run;
$b->quit;

sub crop {
    my ($src, $dst, $box, $inner_w) = @_;
    my $img = Imager->new(file => $src)
        or do { warn 'Imager: ' . Imager->errstr . "\n"; return };

    # SCALE, and why it is measured rather than read from the page.
    #
    # The capture is in DEVICE pixels while box() is in CSS pixels, so on a
    # HiDPI display they differ. The obvious source for the ratio is
    # window.devicePixelRatio -- and it is the wrong one here: EV::WebKit's
    # fingerprint option spoofs that value in JavaScript while the real
    # rendering scale is unchanged, so a spoofed profile would send the crop to
    # entirely the wrong place. The image's own width against the viewport width
    # is the truth, whatever the page has been told.
    my $scale = $inner_w ? $img->getwidth / $inner_w : 1;
    printf "scale: %.3f (image %dpx / viewport %dpx)\n", $scale, $img->getwidth, $inner_w // 0;

    my ($x, $y) = (int($box->{page_x} * $scale), int($box->{page_y} * $scale));
    my ($w, $h) = (int($box->{width}  * $scale), int($box->{height} * $scale));

    # Clamp to the image: a sticky header can report a box that extends past the
    # captured area, and Imager would refuse the crop rather than trim it.
    $x = 0 if $x < 0; $y = 0 if $y < 0;
    $w = $img->getwidth  - $x if $x + $w > $img->getwidth;
    $h = $img->getheight - $y if $y + $h > $img->getheight;
    if ($w <= 0 || $h <= 0) { warn "element lies outside the captured page\n"; return }

    my $out = $img->crop(left => $x, top => $y, width => $w, height => $h)
        or do { warn 'Imager crop: ' . $img->errstr . "\n"; return };
    $out->write(file => $dst)
        or do { warn 'Imager write: ' . $out->errstr . "\n"; return };
    say "element shot: $dst (${w}x${h})";
}

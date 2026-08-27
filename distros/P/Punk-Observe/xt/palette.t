#!perl
# The series ramp and the severity scale, MEASURED.
#
# Eight colours that must stay distinguishable from each other, in light and
# in dark, and under the common colour vision deficiencies. Roughly one man in
# twelve cannot separate the red and green that most default palettes put
# adjacent, so a legend that only works in light mode is a bug and not a
# preference.
#
# These are CHECKED, not chosen, and the numbers are printed so a change that
# degrades them is visible in the diff rather than in somebody's eyes.
use 5.010;
use strict;
use warnings;
use Test::More;

my $CSS = 'root/static/observe.css';
plan skip_all => "no $CSS" unless -f $CSS;

my $css = do { open my $fh, '<', $CSS or die; local $/; <$fh> };

sub block_after {
    my ($src, $sel) = @_;
    my $at = index($src, $sel);
    return '' if $at < 0;
    my $i = index($src, '{', $at);
    my ($depth, $j) = (0, $i);
    while ($j < length $src) {
        my $c = substr($src, $j, 1);
        $depth++ if $c eq '{';
        if ($c eq '}') { $depth--; last if $depth == 0 }
        $j++;
    }
    return substr($src, $i + 1, $j - $i - 1);
}

sub tokens_from {
    my ($blk, $prefix, @names) = @_;
    my %t;
    for my $n (@names) {
        $t{$n} = $1 if $blk =~ /\Q--$prefix$n\E:\s*(#[0-9a-fA-F]{6})/;
    }
    return \%t;
}

# --- colour maths -----------------------------------------------------------

sub hex_rgb { my ($h) = @_; $h =~ s/^#//;
              return map { hex(substr($h, $_ * 2, 2)) / 255 } 0 .. 2 }

sub srgb_lin { my ($c) = @_;
               return $c <= 0.04045 ? $c / 12.92 : (($c + 0.055) / 1.055) ** 2.4 }

# sRGB to CIE Lab, D65.
sub lab {
    my ($hex) = @_;
    my ($r, $g, $b) = map { srgb_lin($_) } hex_rgb($hex);
    my $X = ($r * 0.4124 + $g * 0.3576 + $b * 0.1805) / 0.95047;
    my $Y = ($r * 0.2126 + $g * 0.7152 + $b * 0.0722) / 1.00000;
    my $Z = ($r * 0.0193 + $g * 0.1192 + $b * 0.9505) / 1.08883;
    my $f = sub { my ($t) = @_;
                  return $t > 0.008856 ? $t ** (1/3) : (7.787 * $t) + 16/116 };
    my ($fx, $fy, $fz) = map { $f->($_) } ($X, $Y, $Z);
    return (116 * $fy - 16, 500 * ($fx - $fy), 200 * ($fy - $fz));
}

# CIE76 distance. Not the most modern formula, but it is simple, it has no
# tuning constants to get wrong, and the threshold below is calibrated against
# it rather than borrowed.
sub dist {
    my ($a, $b) = @_;
    my @A = lab($a); my @B = lab($b);
    return sqrt(($A[0]-$B[0])**2 + ($A[1]-$B[1])**2 + ($A[2]-$B[2])**2);
}

# Brettel-style simulation, simplified: project onto the confusion axis.
# Enough to catch a ramp that collapses, which is what this is for.
sub simulate {
    my ($hex, $kind) = @_;
    my ($r, $g, $b) = map { srgb_lin($_) } hex_rgb($hex);
    my ($L, $M, $S) = (
        0.31399 * $r + 0.63951 * $g + 0.04649 * $b,
        0.15537 * $r + 0.75789 * $g + 0.08670 * $b,
        0.01775 * $r + 0.10944 * $g + 0.87262 * $b,
    );
    if    ($kind eq 'deuteranopia') { $M = 0.494207 * $L + 1.24827 * $S }
    elsif ($kind eq 'protanopia')   { $L = 2.02344 * $M - 2.52581 * $S }
    my ($r2, $g2, $b2) = (
         5.47221 * $L - 4.6419  * $M + 0.16963 * $S,
        -1.1252  * $L + 2.29317 * $M - 0.1678  * $S,
         0.02980 * $L - 0.19318 * $M + 1.16364 * $S,
    );
    my $back = sub { my ($c) = @_;
        $c = 0 if $c < 0; $c = 1 if $c > 1;
        $c = $c <= 0.0031308 ? $c * 12.92 : 1.055 * ($c ** (1/2.4)) - 0.055;
        return sprintf('%02x', int($c * 255 + 0.5));
    };
    return '#' . $back->($r2) . $back->($g2) . $back->($b2);
}

# --- the thresholds ---------------------------------------------------------
#
# Calibrated against CIE76 on this palette rather than borrowed from a
# textbook. Normal vision needs a comfortable separation; under a simulated
# deficiency the bar is lower, because the honest goal is "still tellable
# apart", not "equally pleasant".
my $MIN_NORMAL = 18;
my $MIN_CVD    = 9;

my @themes = (
    [ 'light', block_after($css, ':root[data-theme="light"]') ],
    [ 'dark',  block_after($css, ':root[data-theme="dark"]') ],
);

for my $th (@themes) {
    my ($name, $blk) = @$th;
    ok(length $blk, "the $name theme block was found") or next;

    # --- the series ramp ---
    my $ramp = tokens_from($blk, 'series-', 1 .. 8);
    is(scalar keys %$ramp, 8, "$name: all eight series colours parsed");

    for my $vision ('normal', 'deuteranopia', 'protanopia') {
        my %c = map {
            $_ => ($vision eq 'normal' ? $ramp->{$_} : simulate($ramp->{$_}, $vision))
        } keys %$ramp;

        my ($worst, $wa, $wb) = (1e9, '', '');
        for my $i (1 .. 8) {
            for my $j ($i + 1 .. 8) {
                my $d = dist($c{$i}, $c{$j});
                ($worst, $wa, $wb) = ($d, $i, $j) if $d < $worst;
            }
        }
        my $min = $vision eq 'normal' ? $MIN_NORMAL : $MIN_CVD;
        diag(sprintf('%-5s series %-13s worst pair %d/%d = %.1f (min %d)',
                     $name, $vision, $wa, $wb, $worst, $min));
        cmp_ok($worst, '>=', $min,
               "$name/$vision: every series pair is separable");
    }

    # --- the severity scale ---
    #
    # SIX STEPS CANNOT ALL BE PAIRWISE DISTINCT UNDER DICHROMACY, and pretending
    # otherwise would mean either a blanket threshold nothing can meet or one
    # so low it asserts nothing. Measured on this metric, even the standard
    # Okabe-Ito palette fails a pairwise dichromacy bar at eight entries.
    #
    # So severity is asserted on what it actually promises:
    #
    #   1. LIGHTNESS IS STRICTLY MONOTONIC. That is the ordering signal, and
    #      it is the one that survives desaturation - which is roughly what a
    #      colourblind reader sees.
    #   2. The ADJACENT steps an operator confuses when scanning a log list
    #      are clearly different at normal vision.
    #
    # Colour is never the only signal here: .row-error carries weight, an
    # inset rule and a text marker too, which t/90-assets.t asserts.
    my $sev = tokens_from($blk, 'sev-',
                          qw(trace debug info warn error fatal));
    is(scalar keys %$sev, 6, "$name: all six severity colours parsed");

    {
        my @order = qw(trace debug info warn error fatal);
        my @L = map { (lab($sev->{$_}))[0] } @order;
        diag(sprintf('%-5s sev lightness: %s',
                     $name, join(' ', map { sprintf '%.0f', $_ } @L)));
        my $mono = 1;
        for my $i (1 .. $#L) {
            # light theme darkens with severity; dark theme brightens
            $mono = 0 if $name eq 'light' ? $L[$i] >= $L[$i - 1]
                                          : $L[$i] <= $L[$i - 1];
        }
        ok($mono, "$name: severity lightness is strictly monotonic");
        cmp_ok(abs($L[-1] - $L[0]), '>=', 30,
               "$name: and spans a wide enough lightness range to read as one");
    }

    # The adjacent steps that actually matter: an operator scanning a log list
    # must never confuse warn with error.
    for my $pair ([ 'warn', 'error' ], [ 'error', 'fatal' ], [ 'info', 'warn' ],
                  [ 'debug', 'info' ], [ 'trace', 'debug' ]) {
        my $d = dist($sev->{$pair->[0]}, $sev->{$pair->[1]});
        diag(sprintf('%-5s sev %s/%s = %.1f', $name, @$pair, $d));
        cmp_ok($d, '>=', $MIN_NORMAL,
               "$name: adjacent steps $pair->[0] and $pair->[1] are distinct");
    }
}

# --- the light and dark ramps must not be the same colours ------------------

{
    my $l = tokens_from(block_after($css, ':root[data-theme="light"]'), 'series-', 1 .. 8);
    my $d = tokens_from(block_after($css, ':root[data-theme="dark"]'),  'series-', 1 .. 8);
    my $same = grep { lc($l->{$_}) eq lc($d->{$_}) } 1 .. 8;
    is($same, 0,
       'the dark ramp is a different set, not the light one on a dark ground');
}

# --- contrast against the ground --------------------------------------------

# A series colour has to be visible on the panel it is drawn on.
{
    for my $th (@themes) {
        my ($name, $blk) = @$th;
        my ($ground) = $blk =~ /--raised:\s*(#[0-9a-fA-F]{6})/;
        next unless $ground;
        my $ramp = tokens_from($blk, 'series-', 1 .. 8);
        my ($worst, $which) = (1e9, '');
        for my $i (1 .. 8) {
            my $d = dist($ramp->{$i}, $ground);
            ($worst, $which) = ($d, $i) if $d < $worst;
        }
        diag(sprintf('%-5s series vs ground: worst is series-%s = %.1f',
                     $name, $which, $worst));
        cmp_ok($worst, '>=', 25,
               "$name: every series colour stands off the panel ground");
    }
}

done_testing();

#!/usr/bin/env perl
use v5.10;
use strict;
use warnings;

# Scrape a page: navigate, pull structured data out of the DOM, save a shot.
#
#     xvfb-run -a perl eg/scrape.pl [uri]
#
# The commonest thing anyone actually does with a headless browser, and the
# shape every other script here is a variation of: one navigation, one EV::run,
# every result gathered before the loop is broken.
#
# Runs headless under xvfb-run; with a real $DISPLAY you get a visible window.

use EV;
use EV::WebKit;
use File::Temp qw(tempdir);
use File::Spec;

my $uri = shift(@ARGV) // 'https://www.perl.org/';

die "WebKitGTK 6.0 / GTK4 typelibs not available\n" unless EV::WebKit->available;

my $dir  = tempdir(CLEANUP => 0);
my $shot = File::Spec->catfile($dir, 'page.png');

my $b = EV::WebKit->new(
    window   => [1280, 900],
    timeout  => 30,
    on_error => sub { warn "browser error: $_[0]\n" },
);

$b->go($uri, sub {
    my (undef, $err) = @_;
    if ($err) { warn "navigation failed: $err\n"; return EV::break }

    # Everything below is one nested chain deliberately: each step's result is
    # the next one's precondition, and EV::break happens exactly once, at the
    # end. Kicking off independent calls and breaking on whichever finishes
    # first is the classic way to lose half your data.
    # title/uri are SYNCHRONOUS accessors -- no callback. (find/find_all/text
    # and friends are async; the difference is in each method's POD.)
    say 'title: ', $b->title // '(none)';
    say 'uri:   ', $b->uri   // '(none)';

    $b->find_all('a[href]', sub {
        my ($links, $e) = @_;
        return EV::break if $e;
        say 'links:  ', scalar @$links;

        # Read the first few. Element accessors are async too, so count the
        # outstanding reads and continue only when the last one lands.
        my @want = @$links[0 .. ($#$links < 4 ? $#$links : 4)];
        my $left = scalar @want or return EV::break;
        my @rows;
        for my $i (0 .. $#want) {
            $want[$i]->text(sub {
                my ($text) = @_;
                $text //= '';
                $text =~ s/\s+/ /g;
                $text =~ s/^\s+|\s+$//g;
                $rows[$i] = $text;
                return if --$left;

                say "  - $_" for grep { length } @rows;
                $b->screenshot($shot, sub {
                    my (undef, $serr) = @_;
                    say $serr ? "screenshot failed: $serr" : "shot:   $shot";
                    EV::break;
                });
            });
        }
    });
});

EV::run;
$b->quit;

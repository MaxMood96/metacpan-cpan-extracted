#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib', 'blib/lib', 'blib/arch';
use File::Path qw(make_path);
use PDF::Make::Builder;

my $in  = $ARGV[0] // 'corpus/blog_tests/source_demo.pdf';
my $out = $ARGV[1] // 'corpus/blog_tests/source_demo_highlighted.pdf';
my $re  = $ARGV[2] // 'PDF::Make';

my $out_dir = 'corpus/blog_tests';
make_path($out_dir) unless -d $out_dir;

my $b = PDF::Make::Builder->open_existing($in, file_name => $out);
my $pages = $b->page_count;

for my $page_index (0 .. $pages - 1) {
    my $res = $b->extract_structured($in, page => $page_index, invisible => 1);
    my $blocks = $res->data || [];

    $b->open_page($page_index + 1); # builder pages are 1-based
    my $canvas = $b->page->canvas;

    for my $block (@$blocks) {
        for my $line (@{ $block->{lines} || [] }) {
            for my $word (@{ $line->{words} || [] }) {
                my $text = $word->{text} // '';
                next unless $text =~ /$re/i;

                my ($x0, $y0, $x1, $y1) = @{$word}{qw/x0 y0 x1 y1/};
                next unless defined $x0 && defined $y0 && defined $x1 && defined $y1;

                my $pad = 1.5;
                my $x = $x0 - $pad;
                my $y = $y0 - $pad;
                my $w = ($x1 - $x0) + 2 * $pad;
                my $h = ($y1 - $y0) + 2 * $pad;

                # border highlight (red stroke, no fill)
                $canvas->q->w(0.8)->RG(1, 0, 0)->re($x, $y, $w, $h)->S->Q;
            }
        }
    }
}

$b->save;
print "Created $out\n";

#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib', 'blib/lib', 'blib/arch';
use File::Path qw(make_path);
use PDF::Make::Builder;

my $out_dir = 'corpus/blog_tests';
make_path($out_dir) unless -d $out_dir;

my $out = "$out_dir/source_demo.pdf";

my $pdf = PDF::Make::Builder->new(
    file_name => $out,
    configure => {
        text => {
            font => {
                family => 'Helvetica',
                size   => 12,
                colour => '#222222',
            },
        },
    },
);

$pdf->add_page(page_size => 'Letter')
    ->add_h1(text => 'PDF::Make blog demo')
    ->add_text(text => 'PDF::Make builds and edits PDF files directly from Perl.')
    ->add_text(text => 'In the next step we extract text coordinates and highlight matches.')
    ->add_text(text => 'Target terms: PDF::Make, extract_structured, highlight.')
    ->add_text(text => 'This line repeats PDF::Make so multiple boxes are drawn around matches.')
    ->save;

print "Created $out\n";

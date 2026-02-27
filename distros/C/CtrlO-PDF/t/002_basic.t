use Test::More tests => 1;
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use File::Compare qw(compare);

use CtrlO::PDF;

use lib '.';
use t::lib::Tools qw(compare_pdf);

subtest baisc => sub {
    my $pdf = CtrlO::PDF->new(
        footer => "My PDF document footer",
    );

    # Add a page
    $pdf->add_page;

    # Add headings
    $pdf->heading('This is the main heading');
    $pdf->heading('This is a sub-heading', size => 12);

    # Add paragraph text
    $pdf->text("Foobar");

    compare_pdf($pdf, '002_basic.pdf');
};

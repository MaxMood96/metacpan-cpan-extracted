use strict;
use warnings;

use Test::More;

use CtrlO::PDF;

use lib '.';
use t::lib::Tools qw(compare_pdf);

subtest image => sub {
    my $pdf = CtrlO::PDF->new(
        logo        => "sample/logo.png",
        footer      => "My PDF document footer",
    );

    $pdf->add_page;

    # Add headings
    $pdf->heading('This is the main heading');
    $pdf->heading('This is a sub-heading', size => 12);

    # Add paragraph text
    $pdf->text("Foobar");

    compare_pdf($pdf, '004_image.pdf');
};

done_testing();



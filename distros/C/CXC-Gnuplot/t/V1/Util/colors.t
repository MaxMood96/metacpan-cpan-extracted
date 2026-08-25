#! perl

use Test::Lib;
use My::Test;

use CXC::Gnuplot::V1::Util 'gnuplot_color', 'gnuplot_color_names';

# check for some random names

is(
    [gnuplot_color_names],
    bag {
        item 'white';
        item 'forest-green';
        etc;
    },
    'gnuplot_color_names',
);

is(
    gnuplot_color( 'yellow4' ),
    object {
        call name => 'yellow4';
        call rgb  => '#808000';
        call r    => 128;
        call g    => 128;
        call b    => 0;
    },
    'gnuplot_color',
);

done_testing;

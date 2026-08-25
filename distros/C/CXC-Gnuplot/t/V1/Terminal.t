#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::Terminal';

ok( dies { Terminal->new }, "virtual class" );

my $term;
ok(
    lives {
        $term = Terminal->new( terminal => 'pngcairo' )
    },
    'factory'
) or bail_out $@;

isa_ok( $term, ['CXC::Gnuplot::V1::Terminal::pngcairo'], 'correct class' );

done_testing;

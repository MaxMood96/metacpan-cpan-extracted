#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::Range';
use aliased 'CXC::Gnuplot::V1::Bound';

my %args = (
    min => '1 < * < 4',
    max => '8 < * < 10',
);

my $range    = Range->new( %args );
my $expected = object {
    prop blessed => Range;
    call min => object {
        prop isa => Bound;
        call lower_bound => 1;
        call upper_bound => 4;
        call bound       => q{*};
    };
    call max => object {
        prop isa => Bound;
        call lower_bound => 8;
        call upper_bound => 10;
        call bound       => q{*};
    };
    call_list opts => array {
        item q{[1 < * < 4:8 < * < 10]};
    };
};


is( $range, $expected, 'new' );

done_testing;

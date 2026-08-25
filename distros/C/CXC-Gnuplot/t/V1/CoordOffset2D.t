#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::CoordOffset2D';
use aliased 'CXC::Gnuplot::V1::CoordValue';
use Data::Dump 'pp';

subtest 'new' => sub {

    is(
        CoordOffset2D->new(
            x => 3,
            y => 4,
        ),
        object {
            prop blessed => CoordOffset2D;
            call x => object {
                prop blessed => CoordValue;
                call value => 3;
            };
            call y => object {
                prop blessed => CoordValue;
                call value => 4;
            };
            call_list opts => [q{3,4}];
        },
        '3,4',
    );

    is(
        CoordOffset2D->new(
            x => 3,
        ),
        object {
            prop blessed => CoordOffset2D;
            call x => object {
                prop blessed => CoordValue;
                call value => 3;
            };
            call y => object {
                prop blessed => CoordValue;
                call value => 0;
            };
            call_list opts => [q{3}];
        },
        '3',
    );

};

done_testing;

#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::CoordOffset3D';
use aliased 'CXC::Gnuplot::V0::CoordValue';
use Data::Dump 'pp';

subtest 'new' => sub {

    is(
        CoordOffset3D->new(
            x => 3,
            y => 4,
            z => 5,
        ),
        object {
            prop blessed => CoordOffset3D;
            call x => object {
                prop blessed => CoordValue;
                call value => 3;
            };
            call y => object {
                prop blessed => CoordValue;
                call value => 4;
            };
            call z => object {
                prop blessed => CoordValue;
                call value => 5;
            };
            call_list opts => [q{3,4,5}];
        },
        '3,4,5',
    );

    is(
        CoordOffset3D->new(
            x => 3,
            z => 5,
        ),
        object {
            prop blessed => CoordOffset3D;
            call x => object {
                prop blessed => CoordValue;
                call value => 3;
            };
            call y => 0;
            call z => object {
                prop blessed => CoordValue;
                call value => 5;
            };
            call_list opts => [q{3,0,5}];
        },
        '3,,5',
    );


};

subtest 'assert_coerce' => sub {

    my %args = (
        x => 3,
        y => 4,
        z => 5,
    );

    my $expected = object {
        prop blessed => CoordOffset3D;
        call x => 3;
        call y => 4;
        call z => 5;
    };

    is( CoordOffset3D->assert_coerce( \%args ), $expected, 'hashref', );

    is( CoordOffset3D->assert_coerce( CoordOffset3D->new( %args ) ), $expected, 'Object', );

};

done_testing;

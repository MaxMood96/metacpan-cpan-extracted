#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::CoordOffset2D';
use aliased 'CXC::Gnuplot::V0::CoordValue';
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

subtest 'assert_coerce' => sub {

    my %args = (
        x => 3,
        y => 4,
    );

    my $expected = object {
        prop blessed => CoordOffset2D;
        call x => 3;
        call y => 4;
    };

    is( CoordOffset2D->assert_coerce( \%args ), $expected, 'hashref', );

    is( CoordOffset2D->assert_coerce( CoordOffset2D->new( %args ) ), $expected, 'Object', );

};

done_testing;

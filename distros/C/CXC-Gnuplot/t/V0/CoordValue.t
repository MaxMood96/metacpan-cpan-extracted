#! perl

use v5.10;

use Test::Lib;
use My::Test;

use CXC::Gnuplot::V0::Types 'COORDSYS';
use aliased 'CXC::Gnuplot::V0::CoordValue';
use aliased 'CXC::Gnuplot::V0::LiteralDataValue';
use Data::Dump 'pp';

subtest 'new' => sub {

    is(
        CoordValue->new(
            value => 3,
        ),
        object {
            prop blessed => CoordValue;
            call value => object {
                prop blessed => LiteralDataValue;
                call value => 3;
            };
            call stringify => q{3};
        },
        '3',
    );

    is(
        CoordValue->new(
            value => '2000-01-01',
        ),
        object {
            prop blessed => CoordValue;
            call value => object {
                prop blessed => LiteralDataValue;
                call value => '2000-01-01';
            };
            call stringify => q{"2000-01-01"};
        },
        '"2000-01-01"',
    );

    for my $coordsys ( COORDSYS ) {
        subtest $coordsys => sub {
            is(
                CoordValue->new(
                    value    => 3,
                    coordsys => $coordsys,
                ),
                object {
                    prop blessed => CoordValue;
                    call value => object {
                        prop blessed => LiteralDataValue;
                        call value => 3;
                    };
                    call coordsys  => $coordsys;
                    call stringify => qq{$coordsys 3};
                },
                '3',
            );

            is(
                CoordValue->new(
                    value    => '2000-01-01',
                    coordsys => $coordsys,
                ),
                object {
                    prop blessed => CoordValue;
                    call value => object {
                        prop blessed => LiteralDataValue;
                        call value => '2000-01-01';
                    };
                    call coordsys  => $coordsys;
                    call stringify => qq{$coordsys "2000-01-01"};
                },
                '"2000-01-01"',
            );

        }

    }

};

subtest 'assert_coerce' => sub {

    is(
        CoordValue->assert_coerce( { value => 3, coordsys => 'graph' } ),
        object {
            prop blessed => CoordValue;
            call value => object {
                prop blessed => LiteralDataValue;
                call value => 3;
            };
            call coordsys  => 'graph';
            call stringify => q{graph 3};
        },
        'hashref',
    );

    is(
        CoordValue->assert_coerce( 3 ),
        object {
            prop blessed => CoordValue;
            call value => object {
                prop blessed => LiteralDataValue;
                call value => 3;
            };
            call stringify => q{3};
        },
        '3',
    );

    is(
        CoordValue->assert_coerce( CoordValue->new( value => 3 ), ),
        object {
            prop blessed => CoordValue;
            call value => object {
                prop blessed => LiteralDataValue;
                call value => 3;
            };
            call stringify => q{3};
        },
        'Object',
    );

};

done_testing;

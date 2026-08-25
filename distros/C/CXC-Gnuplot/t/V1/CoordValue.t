#! perl

use v5.10;

use Test::Lib;
use My::Test;

use CXC::Gnuplot::V1::Types 'COORDSYS';
use aliased 'CXC::Gnuplot::V1::CoordValue';
use aliased 'CXC::Gnuplot::V1::LiteralDataValue';
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

done_testing;

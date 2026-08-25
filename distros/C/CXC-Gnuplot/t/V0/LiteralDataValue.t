#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::LiteralDataValue';
use Data::Dump 'pp';

subtest 'new' => sub {

    is(
        LiteralDataValue->new(
            value => 3,
        ),
        object {
            prop blessed => LiteralDataValue;
            call value     => 3;
            call stringify => q{3};
        },
        'number',
    );

    is(
        LiteralDataValue->new(
            value => 'frank',
        ),
        object {
            prop blessed => LiteralDataValue;
            call value     => q{frank};
            call stringify => q{"frank"};
        },
        'string',
    );

};

subtest 'assert_coerce' => sub {

    is(
        LiteralDataValue->assert_coerce( { value => 3 } ),
        object {
            prop blessed => LiteralDataValue;
            call value     => 3;
            call stringify => q{3};
        },
        'hashref',
    );


    is(
        LiteralDataValue->assert_coerce( 3 ),
        object {
            prop blessed => LiteralDataValue;
            call value     => 3;
            call stringify => q{3};
        },
        'number',
    );

    is(
        LiteralDataValue->assert_coerce( 'frank' ),
        object {
            prop blessed => LiteralDataValue;
            call value     => 'frank';
            call stringify => q{"frank"};
        },
        'string',
    );

    is(
        LiteralDataValue->assert_coerce( LiteralDataValue->new( value => 'frank' ), ),
        object {
            prop blessed => LiteralDataValue;
            call value     => 'frank';
            call stringify => q{"frank"};
        },
        'Object',
    );

};

done_testing;

#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::LiteralDataValue';
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

done_testing;

#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::Font';
use Data::Dump 'pp';

subtest 'new' => sub {

    is(
        Font->new(
            name => 'foo',
            size => 12
        ),
        object {
            prop blessed => Font;
            call name => 'foo';
            call size => '12';
            call_list opts => [q{"foo,12"}];
        },
        'foo,12',
    );

    is(
        Font->new( name => 'foo' ),
        object {
            prop blessed => Font;
            call name => 'foo';
            call size => U();
            call_list opts => [q{"foo"}];
        },
        'foo',
    );

    is(
        Font->new( size => 12 ),
        object {
            prop blessed => Font;
            call name => U();
            call size => 12;
            call_list opts => [q{",12"}];
        },
        ',12',
    );

    subtest 'illegal' => sub {

        for my $test (
            [ { name => q{} },  qr/name.*non-empty/ ],
            [ { size => 0 },    qr/positive/ ],
            [ { size => 12.5 }, qr/integer/ ],
            [ { size => q{} },  qr/positive integer/ ],
          )
        {
            like(
                dies {
                    Font->new( $test->[0]->%* )
                },
                $test->[1],
                pp( $test->[0] ),
            );
        }

    }

};

subtest opts => sub {

    is(
        Font->new(
            name => 'foo',
            size => 12
        ),
        object {
            call_list opts => [q{"foo,12"}];
        },
        'foo,12',
    );

};

done_testing;

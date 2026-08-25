#! perl

use v5.28;
use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::AxisMinorTics';

my %setup = (
    intervals => {
        args => {
            intervals => 5,
        },

        expected => object {
            prop blessed => AxisMinorTics;
            call intervals => 5;
            call time      => undef;
        },

        to_hash => hash {
            field intervals => 5;
            end;
        },

        opts => [
            array {
                item 5;
            },
        ],

        clone => {
            args     => { intervals => 3 },
            expected => object {
                call intervals => 3;
                call time      => undef;
            },
        },

    },

    time => {
        args => {
            time => {
                multiple => 3,
                unit     => 'weeks',
            },
        },
        expected => object {
            prop blessed => AxisMinorTics;
            call time => hash {
                field multiple => 3;
                field unit     => 'weeks';
                end;
            };

        },
        to_hash => hash {
            field time => hash {
                field multiple => 3;
                field unit     => 'weeks';
                end;
            };
            end;
        },
        opts => [
            array {
                item 'time';
                item array {
                    item 3;
                    item 'weeks';
                    end;
                };
                end;
            },
        ],
        clone => {
            args     => { time => { unit => 'days' } },
            expected => object {
                call time => hash {
                    field multiple => 3;
                    field unit     => 'days';
                    end;
                };
            },
        },

    },
);

for my ( $name, $setup ) ( %setup ) {

    subtest $name => sub {
        my ( \%args, $expected, $to_hash, $opts, \%clone )
          = $setup->@{ 'args', 'expected', 'to_hash', 'opts', 'clone' };

        my $obj = AxisMinorTics->new( %args );
        is( $obj,           $expected, 'new' );
        is( $obj->to_hash,  $to_hash,  'to_hash' );
        is( [ $obj->opts ], $opts,     'opts' );

        subtest clone => sub {
            is( $obj->clone,                     $expected,        'no args' );
            is( $obj->clone( $clone{args}->%* ), $clone{expected}, 'args' );
        };

    };
}

done_testing;

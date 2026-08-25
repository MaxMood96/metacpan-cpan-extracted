#! perl

use v5.10;
use Test::Lib;
use My::Test;

use CXC::Gnuplot::V1::Types 'FORMAT_COORD_SYS';
use aliased 'CXC::Gnuplot::V1::AxisFormat';
use aliased 'CXC::Gnuplot::V1::LiteralDataValue';

subtest 'new w/ coord' => sub {

    for my $coord ( FORMAT_COORD_SYS ) {

        is(
            AxisFormat->new( coord => $coord, format => 'foo' ),
            object {
                prop blessed => AxisFormat;
                call coord  => $coord;
                call format => object {
                    prop blessed => LiteralDataValue;
                    value => 'foo';
                };
                call_list [ opts => q{"} ] => array {
                    item q{"foo"};
                    item $coord;
                    end;
                };
            },
            $coord,
        );
    }
};


is(
    AxisFormat->new(
        coord  => 'numeric',
        format => 'foo',
    )->to_hash,
    hash {
        field coord  => 'numeric';
        field format => q{foo};
        end;
    },
    'to_hash',
);

subtest clone => sub {

    my %args = (
        coord  => 'numeric',
        format => 'foo',
    );

    my $orig_expect = object {
        prop blessed => AxisFormat;
        call format => object {
            call value => 'foo';
        };
        call coord => 'numeric';
    };

    my $orig = AxisFormat->new( %args );

    is(
        $orig,
        object {
            prop blessed => AxisFormat;
            call format => object {
                call value => 'foo';
            };
            call coord => 'numeric';
        },
        'pre-clone',
    );

    subtest 'no args' => sub {
        is( $orig->clone, $orig_expect, 'cloned', );
        is( $orig,        $orig_expect, 'orig post-clone', );
    };

    subtest 'format' => sub {
        is(
            $orig->clone( format => 'bar' ),
            object {
                prop blessed => AxisFormat;
                call format => object {
                    call value => 'bar';
                };
                call coord => 'numeric';
            },
            'cloned',
        );
        is( $orig, $orig_expect, 'orig post-clone', );
    };

    subtest 'all' => sub {
        is(
            $orig->clone( format => 'bar', coord => 'geographic' ),
            object {
                prop blessed => AxisFormat;
                call format => object {
                    call value => 'bar';
                };
                call coord => 'geographic';
            },
            'cloned',
        );
        is( $orig, $orig_expect, 'orig post-clone', );
    };

};

done_testing;

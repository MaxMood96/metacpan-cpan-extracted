#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::Timestamp';
use aliased 'CXC::Gnuplot::V1::Font';
use aliased 'CXC::Gnuplot::V1::ColorSpec';
use aliased 'CXC::Gnuplot::V1::CoordOffset2D';
use aliased 'CXC::Gnuplot::V1::CoordValue';
use aliased 'CXC::Gnuplot::V1::LiteralDataValue';

subtest 'a mish-mash' => sub {

    my %args = (
        offset => { x => [ graph => 2 ], y => [ screen => 3 ] },
        font   => {
            name => 'foo',
            size => 12,
        },
        textcolor => 'blue',
        rotate    => false,
    );

    my $object   = Timestamp->new( %args );
    my $expected = object {
        prop blessed => Timestamp;
        call font => object {
            prop blessed => Font;
            call name => 'foo';
            call size => 12;
        };
        call format => undef;
        call offset => object {
            prop blessed => CoordOffset2D;
            call x => object {
                prop blessed => CoordValue;
                call coordsys => 'graph';
                call value    => 2;
            };
            call y => object {
                prop blessed => CoordValue;
                call coordsys => 'screen';
                call value    => 3;
            };
        };
        call rotate    => F();
        call textcolor => object {
            prop blessed => ColorSpec;
            call rgbcolor => 'blue';
        };
        call where => undef;

    };

    is( $object, $expected, 'object', );

    is(
        [ $object->opts ],
        bag {
            item [ font      => q{"foo,12"} ];
            item [ offset    => 'graph 2,screen 3' ];
            item [ textcolor => [ rgbcolor => q{"blue"} ] ];
            item q{norotate};
            end;
        },
        'opts',
    );


    is(
        $object->to_hash,
        hash {
            field font => hash { field name => 'foo'; field size => 12; end; };

            field offset => hash {
                field x => hash {
                    field coordsys => 'graph';
                    field value    => 2;
                    end;
                };
                field y => hash {
                    field coordsys => 'screen';
                    field value    => 3;
                    end;
                };
                end;
            };
            field textcolor => hash { field rgbcolor => 'blue'; end; };
            field rotate    => false;

        },
        'hash',
    );

    subtest 'clone' => sub {
        is( $object->clone, $expected, 'no args' );
        is(
            $object->clone(
                offset => { x => { value => 33 } },
            ),
            object {
                call offset => object {
                    call x => object {
                        call value => 33;
                    };
                };
            },
            'args',
        );
    };

};

subtest 'rotate' => sub {

    is(
        Timestamp->new,
        object {
            call_list opts => array {};
        },
        'unspecified',
    );

    is(
        Timestamp->new( rotate => true ),
        object {
            call_list opts => array { item 'rotate'; end; };
        },
        'rotate',
    );

    is(
        Timestamp->new( rotate => false ),
        object {
            call_list opts => array { item 'norotate'; end; };
        },
        'norotate',
    );

    is(
        Timestamp->new( rotate => -333 ),
        object {
            call_list opts => array { item [ 'rotate by', '-333' ]; end; };
        },
        'degrees',
    );

};

done_testing;

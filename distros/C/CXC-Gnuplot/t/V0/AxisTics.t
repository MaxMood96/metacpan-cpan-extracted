#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::AxisTics';
use aliased 'CXC::Gnuplot::V0::Font';
use aliased 'CXC::Gnuplot::V0::ColorSpec';
use aliased 'CXC::Gnuplot::V0::CoordOffset3D';
use aliased 'CXC::Gnuplot::V0::CoordValue';
use aliased 'CXC::Gnuplot::V0::LiteralDataValue';

subtest 'a mish-mash' => sub {

    my %args = (
        offset => { x => [ graph => 2 ], y => [ screen => 3 ] },
        font   => {
            name => 'foo',
            size => 12,
        },
        textcolor => 'blue',
        enhanced  => true,
        rotate    => false,
        positions => [ { label => q{}, pos => 3 } ],
    );

    my $object   = AxisTics->new( %args );
    my $expected = object {
        prop blessed => AxisTics;
        call direction => undef;
        call enhanced  => T();
        call font      => object {
            prop blessed => Font;
            call name => 'foo';
            call size => 12;
        };
        call format   => undef;
        call justify  => undef;
        call logscale => undef;
        call mirror   => undef;
        call offset   => object {
            prop blessed => CoordOffset3D;
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
        call positions => array {
            item hash {
                field label => q{};
                field pos   => object {
                    prop blessed => LiteralDataValue;
                    call value => 3;
                };
                end;
            };
            end;
        };
        call rangelimited => undef;
        call rotate       => F();
        call scale        => undef;
        call textcolor    => object {
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
            item q{enhanced};
            item q{norotate};
            item q{( "" 3 )};
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
                field z => hash {
                    field value => 0;
                    end;
                };
                end;
            };
            field textcolor => hash { field rgbcolor => 'blue'; end; };
            field enhanced  => true;
            field rotate    => false;

            field positions => array {
                item hash {
                    field label => q{};
                    field pos   => { value => 3 };
                    end;
                };
                end;
            };
            end;
        },
        'hash',
    );

    subtest 'assert_coerce' => sub {
        is( AxisTics->assert_coerce( \%args ),                 $expected, 'hashref' );
        is( AxisTics->assert_coerce( AxisTics->new( %args ) ), $expected, 'object' );
    };

    subtest 'clone' => sub {
        is( $object->clone, $expected, 'no args' );
        is(
            $object->clone(
                offset => { z => { value => 33 } },
            ),
            object {
                call offset => object {
                    call z => object {
                        call value => 33;
                    };
                };
            },
            'args',
        );
    };

};

subtest 'positions' => sub {

    subtest 'Num' => sub {

        subtest 'series' => sub {

            my %args = ( positions => { start => 0, end => 2, incr => 0.2 } );

            my $object   = AxisTics->new( %args );
            my $expected = object {
                prop blessed => AxisTics;
                call positions => hash {
                    field start => object {
                        prop blessed => LiteralDataValue;
                        value => 0;
                    };
                    field end => object {
                        prop blessed => LiteralDataValue;
                        value => 2;
                    };
                    field incr => 0.2;
                    end;
                },
            };

            is( $object, $expected, 'object' );
            is(
                $object->to_hash,
                hash {
                    field positions => hash {
                        field start => { value => 0 };
                        field end   => { value => 2 };
                        field incr  => 0.2;
                        end;
                    };
                    end;
                },
                'to_hash'
            );

            is(
                [ $object->opts ],
                array {
                    item match qr/0,\s*0.2,\s*2/;
                    end;
                },
                'opts',
            );

            subtest 'assert_coerce' => sub {
                is( AxisTics->assert_coerce( \%args ),                 $expected, 'hashref' );
                is( AxisTics->assert_coerce( AxisTics->new( %args ) ), $expected, 'object' );
            };

        };

        is(
            AxisTics->new( positions => [ 1, 2, 3, 4, 5 ] ),
            object {
                call_list opts => [q{( 1, 2, 3, 4, 5 )}];
            },
            'list',
        );

        is(
            AxisTics->new( positions => 3 ),
            object {
                call_list opts => [q{3}];
            },
            'incr',
        );

    };

    subtest 'time' => sub {

        is(
            AxisTics->new(
                positions => { start => '2000-01-01', end => '2001-01-02', incr => [ 1, 'years' ] },
            ),
            object {
                call_list opts => [q{"2000-01-01", 1 years, "2001-01-02"}];
            },
            'range',
        );

        is(
            AxisTics->new( positions => [ 1, 2, 3, 4, 5 ] ),
            object {
                call_list opts => [q{( 1, 2, 3, 4, 5 )}];
            },
            'series',
        );

        is(
            AxisTics->new( positions => 3 ),
            object {
                call_list opts => [q{3}];
            },
            'incr',
        );

    };
};

subtest 'enhanced' => sub {

    is(
        AxisTics->new,
        object {
            call_list opts => array {};
        },
        'unspecified',
    );

    is(
        AxisTics->new( enhanced => true ),
        object {
            call_list opts => array { item 'enhanced'; end; };
        },
        'true',
    );

    is(
        AxisTics->new( enhanced => false ),
        object {
            call_list opts => array { item 'noenhanced'; end; };
        },
        'false',
    );

};


subtest 'rotate' => sub {

    is(
        AxisTics->new,
        object {
            call_list opts => array {};
        },
        'unspecified',
    );

    is(
        AxisTics->new( rotate => true ),
        object {
            call_list opts => array { item 'rotate'; end; };
        },
        'rotate',
    );

    is(
        AxisTics->new( rotate => false ),
        object {
            call_list opts => array { item 'norotate'; end; };
        },
        'norotate',
    );

    is(
        AxisTics->new( rotate => -333 ),
        object {
            call_list opts => array { item [ 'rotate by', '-333' ]; end; };
        },
        'degrees',
    );

};


subtest 'assert_coerce' => sub {

    my %args = (
        font      => { name  => 'foo', size => 12 },
        positions => { start => 1,     incr => 3 },
    );

    my $expected = object {
        prop blessed => AxisTics;
        call font => object {
            prop blessed => Font;
            call name => 'foo';
            call size => 12;
        };
        call positions => hash {
            field incr  => 3;
            field start => object {
                prop blessed => LiteralDataValue;
                call value => 1;
            };
            end;
        };
    };

    is( AxisTics->assert_coerce( \%args ),                 $expected, 'hashref' );
    is( AxisTics->assert_coerce( AxisTics->new( %args ) ), $expected, 'object' );

};

done_testing;

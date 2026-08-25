#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::ColorSpec';
use aliased 'CXC::Gnuplot::V0::CoordOffset3D';
use aliased 'CXC::Gnuplot::V0::CoordPosition3D';
use aliased 'CXC::Gnuplot::V0::Font';
use aliased 'CXC::Gnuplot::V0::Label';

subtest 'new' => sub {

    my %args = (
        tag     => 3,
        text    => 'frank',
        at      => { x => [ graph => 3 ], y => '2000-12-31T00:0):00' },
        justify => 'center',
        rotate  => true,
        font    => {
            name => 'foo',
            size => 12,
        },
        enhanced  => false,
        layer     => 'back',
        textcolor => 'blue',
        point     => { type => 3, color => 'red' },
        offset    => { x    => 22 },
        boxed     => true,
        hypertext => true,
    );

    my $label = Label->new( %args );

    my $expected = object {
        prop blessed => Label;
        call tag  => 3;
        call text => 'frank';
        call at   => object {
            prop blessed => CoordPosition3D;
            call x => object {
                call coordsys => 'graph';
                call value    => object {
                    call value => 3;
                };
            };
            call y => object {
                call value => object {
                    call value => '2000-12-31T00:0):00';
                };
            };
        };
        call justify => 'center';
        call rotate  => T();
        call font    => object {
            prop blessed => Font;
            call name => 'foo';
            call size => 12;
        };
        call enhanced  => F();
        call layer     => 'back';
        call textcolor => object {
            prop blessed => ColorSpec;
            call rgbcolor => 'blue';
        };
        call point  => { type => 3, color => 'red' };
        call offset => object {
            prop blessed => CoordOffset3D;
            call x => object {
                value => 22;
            };
            call y => object {
                value => 0;
            };
            call z => object {
                value => 0;
            };
        };
        call boxed     => T();
        call hypertext => T();
    };

    is( $label, $expected, 'object' );

    is(
        [ $label->opts ],
        array {
            item 3;
            item q{"frank"};
            item array {
                item 'at';
                item q{graph 3,"2000-12-31T00:0):00"};
                end;
            };
            item 'center';
            item 'rotate';
            item array {
                item 'font';
                item q{"foo,12"};
                end;
            };
            item q{noenhanced};
            item q{back};
            item array {
                item 'textcolor';
                item array {
                    item 'rgbcolor';
                    item q{"blue"};
                    end;
                };
                end;
            };
            item 'hypertext';
            item array {
                item 'point';
                item 'lc';
                item 'red';
                item 'pt';
                item 3;
                end;
            };
            item array { item 'offset'; item 22; end; };
            item q{boxed};
            end;
        },
        'opts',
    );

    subtest 'enhanced' => sub {

        is(
            Label->new,
            object {
                call_list opts => array {};
            },
            'unspecified',
        );

        is(
            Label->new( enhanced => true ),
            object {
                call_list opts => array { item 'enhanced'; end; };
            },
            'true',
        );

        is(
            Label->new( enhanced => false ),
            object {
                call_list opts => array { item 'noenhanced'; end; };
            },
            'false',
        );

    };


    subtest 'rotate' => sub {

        is(
            Label->new,
            object {
                call_list opts => array {};
            },
            'unspecified',
        );

        is(
            Label->new( rotate => false ),
            object {
                call_list opts => array { item 'norotate'; end; };
            },
            'norotate',
        );

        is(
            Label->new( rotate => -333 ),
            object {
                call_list opts => array { item [ 'rotate by', '-333' ]; end; };
            },
            'degrees',
        );

    };


};


subtest 'assert_coerce' => sub {

    is(
        Label->assert_coerce( { font => { name => 'foo', size => 12 } } ),
        object {
            prop blessed => Label;
            call_list opts => array {
                item [ font => q{"foo,12"} ];
                end;
            };
        },
        'hashref',
    );

    is(
        Label->assert_coerce( Label->new( font => { name => 'foo', size => 12 } ) ),
        object {
            prop blessed => Label;
            call_list opts => array {
                item [ font => q{"foo,12"} ];
                end;
            };
        },
        'Object',
    );

    is(
        Label->assert_coerce( 'frank' ),
        object {
            prop blessed => Label;
            call text => 'frank';
        },
        'scalar',
    );


};

done_testing;

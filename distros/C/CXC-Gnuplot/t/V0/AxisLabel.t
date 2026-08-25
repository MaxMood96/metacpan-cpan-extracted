#! perl

use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::AxisLabel';

my %args = (
    text => "frank",
    font => {
        name => 'foo',
        size => 12,
    },
    offset    => { x => 22 },
    textcolor => 'blue',
    enhanced  => true,
    rotate    => false,
);

my $expected = object {
    prop blessed => AxisLabel;
    call text => 'frank';
    call font => object {
        call name => 'foo';
        call size => 12;
    };
    call offset => object {
        call x => object {
            call value => object {
                call value => 22;
            }
        };
    };
    call textcolor => object {
        call rgbcolor => 'blue';
    };
    call enhanced => T();
    call rotate   => F();
};

subtest 'new' => sub {

    is( AxisLabel->new( %args ), $expected, 'everything' );

    subtest 'enhanced' => sub {

        is(
            AxisLabel->new,
            object {
                call_list opts => array {};
            },
            'unspecified',
        );

        is(
            AxisLabel->new( enhanced => true ),
            object {
                call enhanced => T();
                call_list opts => array { item 'enhanced'; end; };
            },
            'true',
        );

        is(
            AxisLabel->new( enhanced => false ),
            object {
                call enhanced => F();
                call_list opts => array { item 'noenhanced'; end; };
            },
            'false',
        );

    };


    subtest 'rotate' => sub {

        is(
            AxisLabel->new,
            object {
                call_list opts => array {};
            },
            'unspecified',
        );

        is(
            AxisLabel->new( rotate => 'norotate' ),
            object {
                call rotate => 'norotate';
                call_list opts => array { item 'norotate'; end; };
            },
            'norotate',
        );

        is(
            AxisLabel->new( rotate => false ),
            object {
                call rotate => F();
                call_list opts => array { item 'norotate'; end; };
            },
            'false',
        );

        is(
            AxisLabel->new( rotate => 'parallel' ),
            object {
                call_list opts => array { item [ rotate => 'parallel' ]; end; };
            },
            'parallel',
        );

        is(
            AxisLabel->new( rotate => -333 ),
            object {
                call_list opts => array { item [ 'rotate by', '-333' ]; end; };
            },
            'degrees',
        );
    };
};

is(
    AxisLabel->new( %args )->to_hash,
    hash {
        field text => "frank";
        field font => hash {
            field name => 'foo';
            field size => 12;
            end;
        };
        field offset => hash {
            field x => hash { field value => 22; end; };
            field y => hash { field value => 0;  end; };
            field z => hash { field value => 0;  end; };
            end;
        };
        field textcolor => hash { field rgbcolor => 'blue'; end; };
        field enhanced  => true;
        field rotate    => false;
        end;
    },
    'to_hash'
);


subtest 'assert_coerce' => sub {

    is( AxisLabel->assert_coerce( \%args ), $expected, 'hashref', );

    is( AxisLabel->assert_coerce( AxisLabel->new( %args ) ), $expected, 'Object', );

    is(
        AxisLabel->assert_coerce( 'frank' ),
        object {
            prop blessed => AxisLabel;
            call text => 'frank';
        },
        'scalar',
    );

};

subtest clone => sub {

    my $orig = AxisLabel->new( %args );

    is( $orig, $expected, 'pre-clone', );

    subtest 'no args' => sub {
        is( $orig->clone, $expected, 'cloned', );
        is( $orig,        $expected, 'orig post-clone', );
    };

    subtest 'font size' => sub {
        is(
            $orig->clone( font => { size => 22 } ),
            object {
                prop blessed => AxisLabel;
                call font => object {
                    call name => 'foo';
                    call size => 22;
                };
            },
            'cloned',
        );
        is( $orig, $expected, 'orig post-clone', );
    };

    subtest 'delete' => sub {
        is(
            $orig->clone( font => { -delete => 'name', size => 33 } ),
            object {
                prop blessed => AxisLabel;
                call font => object {
                    call size => 33;
                };
            },
            'cloned',
        );
        is( $orig, $expected, 'orig post-clone', );
    };

};

done_testing;

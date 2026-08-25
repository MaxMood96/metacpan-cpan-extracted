#! perl

use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::Axis';
use aliased 'CXC::Gnuplot::V0::AxisRange';
use aliased 'CXC::Gnuplot::V0::AxisLabel';
use aliased 'CXC::Gnuplot::V0::Font';
use aliased 'CXC::Gnuplot::V0::Bound';

use Data::Dump 'pp';

my %args = (
    label => {
        text => 'frank',
        font => {
            name => 'foo',
            size => 12,
        },
    },
    range => {
        min => '22',
        max => '44',
    },
);

my $expected = object {
    prop isa => Axis;
    call label => object {
        prop blessed => AxisLabel;
        call text => 'frank';
        call font => object {
            prop blessed => Font;
            call name => 'foo';
            call size => 12;
        };
    };
    call range => object {
        prop blessed => AxisRange;
        call min => object {
            prop isa => Bound;
            call bound => 22;
        };
        call max => object {
            prop isa => Bound;
            call bound => 44;
        };
    };
};


subtest 'new' => sub {

    is( Axis->new( %args ), $expected, pp( \%args ), );

    is(
        [ Axis->new( %args )->set( 'x', as => 'array' ) ],
        bag {
            item [ set => xrange => '[22:44]' ];
            item [ set => xlabel => q{"frank"}, [ font => q{"foo,12"} ] ];
            end;
        },
        'set',
    );

    is(
        [ Axis->new( %args, format => 'ABC' )->set( 'x', as => 'array' ) ],
        bag {
            item [ set => xrange => '[22:44]' ];
            item [ set => format => 'x',        q{"ABC"} ];
            item [ set => xlabel => q{"frank"}, [ font => q{"foo,12"} ] ];
            end;
        },
        'set w/ format',
    );

};

is(
    Axis->new( %args )->to_hash,
    hash {
        field label => hash {
            field text => 'frank';
            field font => hash {
                field name => 'foo';
                field size => 12;
                end;
            };
            end;
        };
        field range => hash {
            field min => hash {
                field bound => '22';
                end;
            };
            field max => hash {
                field bound => '44';
                end;
            };
            end;
        };
        end;
    },
    'to_hash',
);

subtest 'assert_coerce' => sub {
    is( Axis->assert_coerce( \%args ),             $expected, 'hashref', );
    is( Axis->assert_coerce( Axis->new( %args ) ), $expected, 'Object', );
};

subtest 'clone' => sub {
    my $axis = Axis->new( %args );
    is( $axis->clone, $expected, 'no args', );
    is(
        $axis->clone(
            label => { font => { -delete => 'name', size => 24 } }
        ),
        object {
            call label => object {
                call text => 'frank';
                call font => object {
                    call name => undef;
                    call size => 24;
                };
            };
            call range => object {
                call min => object {
                    call bound => 22;
                };
                call max => object {
                    call bound => 44;
                };
            };
        },
        'args',
    );
};



done_testing;

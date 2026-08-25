#! perl

use v5.28;
use Test::Lib;
use My::Test;

use Ref::Util 'is_ref';

use aliased 'CXC::Gnuplot::V0::MultiPlot';
use aliased 'CXC::Gnuplot::V0::ColorSpec';
use aliased 'CXC::Gnuplot::V0::MultiPlot::Title';
use aliased 'CXC::Gnuplot::V0::Font';
use aliased 'CXC::Gnuplot::V0::MultiPlot::Margins';

my %args = (
    title => {
        text => 'frank',
        font => {
            name => 'foo',
            size => 12,
        },
        textcolor => 'red',
        justify   => 'center',
        enhanced  => true,
    },
    layout    => { nrows => 3, ncols => 8, },
    order     => 'columnsfirst',
    direction => 'upwards',
    scale     => 3,
    offset    => { x    => 0.2, y     => 0.9 },
    margins   => { left => 0.1, right => 0.9, bottom => 0.2, top => 0.8 },
    spacing   => 0.1,
);

my $multiplot = MultiPlot->new( %args );

my $expected = object {
    prop isa => MultiPlot;
    call title => object {
        prop blessed => Title;
        call text => 'frank';
        call font => object {
            prop blessed => Font;
            call name => 'foo';
            call size => 12;
        };
        call textcolor => object {
            prop blessed => ColorSpec;
            call rgbcolor => 'red';
        };
        call justify  => 'center';
        call enhanced => T();
    };
    call layout    => hash { field nrows => 3; field ncols => 8; };
    call order     => 'columnsfirst';
    call direction => 'upwards';
    call scale     => hash { field x => 3;   end; };
    call offset    => hash { field x => 0.2; field y => 0.9; end; };
    call margins   => object {
        prop blessed => Margins;
        call left   => 0.1;
        call right  => 0.9;
        call bottom => 0.2;
        call top    => 0.8;
    };
    call spacing => hash { field x => 0.1; end; };
};

is( $multiplot, $expected, 'new' );

subtest 'opts' => sub {

    my ( $opts, @extra ) = $multiplot->opts( as => 'string' );
    ok( !is_ref( $opts ), 'result is a string' );
    is( 0+ @extra, 0, 'no extra results' );

    my $space = q{};
    for my $token (
        'title "frank"',    # this must be the first token in $opts;
        'font "foo,12"',
        'enhanced',
        'center',
        'textcolor',
        'rgbcolor',
        '"red"',
      )
    {
        my $expect = $space . $token;
        my $idx    = index( $opts, $expect );
        isnt( $idx, -1, $token );
        substr( $opts, $idx, length( $expect ), q{} );

        $space = q{ };
    }
};

subtest 'set' => sub {

    my ( \@args ) = $multiplot->set( as => 'array' );

    is( [ splice( @args, 0, 2 ) ], [ set => 'multiplot' ], 'set command' );

    my \@title = shift @args;

    is( [ splice( @title, 0, 2 ) ], [ title => q{"frank"} ], 'set title, text' );

    is(
        \@title,
        bag {
            item array {
                item 'font';
                item q{"foo,12"};
                end;
            };
            item 'enhanced';
            item 'center';
            item array {
                item 'textcolor';
                item array {
                    item 'rgbcolor';
                    item q{"red"};
                    end;
                };
                end;
            };
            end;
        },
        'title',
    );

    is( shift( @args ), [ layout => q{3,8} ], 'set layout' );

    is(
        \@args,
        bag {
            item 'columnsfirst';
            item 'upwards';
            item [ scale   => 3 ];
            item [ offset  => q{0.2,0.9} ];
            item [ margins => q{0.1,0.9,0.2,0.8} ];
            item [ spacing => q{0.1} ];
            end;
        },
        'layout',
    );
};

subtest 'clone' => sub {
    is( $multiplot->clone, $expected, 'no args', );

    is(
        $multiplot->clone(
            title => {
                textcolor => {
                    -delete => 'rgbcolor',
                    palette => { frac => 0.9 },
                },
            },
        ),
        object {
            call title => object {
                call text => 'frank';
                call font => object {
                    call name => 'foo';
                    call size => 12;
                };
                call textcolor => object {
                    call palette => hash { field frac => 0.9; end; };
                };
                call justify  => 'center';
                call enhanced => T();
            };
        },
        'args',
    );
};

done_testing;

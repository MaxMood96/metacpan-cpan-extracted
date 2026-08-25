#! perl


use Test2::Tools::TypeTiny;
use Test::Lib;
use My::Test;
use feature 'say', 'signatures';
use Ref::Util 'is_arrayref', 'is_ref', 'is_hashref';

use CXC::Gnuplot::V1::LiteralDataValue;
use CXC::Gnuplot::V1::Range;

my sub fLiteralDataValue { CXC::Gnuplot::V1::LiteralDataValue->new( value => @_ ) }

use CXC::Gnuplot::V1::Types -all;


sub check2D ( $class, $x, $y ) {
    object {
        prop blessed => $class;
        call x => object { $x->() };
        call y => object { $y->() };
    };
}

sub check3D ( $class, $x, $y, $z ) {
    object {
        prop blessed => $class;
        call x => object { $x->() };
        call y => object { $y->() };
        call z => object { $z->() };
    };
}

sub check_LiteralDataValue ( $expected ) {
    object {
        prop blessed => 'CXC::Gnuplot::V1::LiteralDataValue';
        call value => $expected;
    };
}


type_subtest LiteralDataValue, sub ( $type ) {

    should_pass_initially( $type, fLiteralDataValue( 3 ), fLiteralDataValue( 'foo' ), );

    my sub check ( $value, $expected = $value ) {
        $value => check_LiteralDataValue( $expected );
    }

    should_coerce_into( $type, check( 3 ), check( 'foo' ) );

};

type_subtest CoordSys, sub ( $type ) {

    subtest pass => sub {
        should_pass_initially( $type, qw( first second polar graph screen character char ) );
    };
    subtest fail => sub {
        should_fail( CoordSys, 'not a CoordSys' );
    };
};

type_subtest CoordValue, sub ( $type ) {

    my sub check ( $value, $sub ) {
        $value => object {
            prop blessed => 'CXC::Gnuplot::V1::CoordValue';
            $sub->();
        };
    }

    should_coerce_into(
        $type,
        map {
            check(
                $_,
                sub {
                    call value => object { call value => $_; };
                } )
        } -1.5,
        -1, 1,
        1.5
    );

    should_coerce_into(
        $type,
        check(
            [ first => 1 ],
            sub {
                call coordsys => 'first';
                call value    => object {
                    call value => 1;
                };
            }
        ),

    );
};


type_subtest FormatCoordSys, sub ( $type ) {
    should_pass( $type, qw( numeric timedate geographic ) );
    should_fail( $type, 'not a FormatCoordSys' );

};

type_subtest CoordOffset2D, sub ( $type ) {

    my sub check ( $value, $x, $y ) {
        $value => check2D( 'CXC::Gnuplot::V1::CoordOffset2D', $x, $y );
    }

    should_coerce_into(
        $type,
        check(
            { x => 1, y => 2 },
            sub { call value => 1; },
            sub { call value => 2; },
        ),

        check(
            { x => [ second => 1 ], y => 2 },
            sub {
                call coordsys => 'second';
                call value    => 1;
            },
            sub {
                call value => 2;
            },
        ),

        check(
            { x => 1, y => [ first => 2 ] },
            sub { call value => 1; },
            sub {
                call coordsys => 'first';
                call value    => 2;
            },
        ),
    );
};

type_subtest CoordOffset3D, sub ( $type ) {

    my sub check ( $value, $x, $y, $z ) {
        $value => check3D( 'CXC::Gnuplot::V1::CoordOffset3D', $x, $y, $z );
    }

    should_coerce_into(
        $type,
        check(
            { x => 1, y => 2, z => -3 },
            sub { call value => 1 },
            sub { call value => 2 },
            sub { call value => -3 },
        ),

        check(
            { x => [ second => 1 ], y => 2, z => -3 },
            sub {
                call value    => 1;
                call coordsys => 'second';
            },
            sub { call value => 2 },
            sub { call value => -3 },
        ),

        check(
            { x => 1, y => [ first => 2 ], z => -3 },
            sub { call value => 1 },
            sub {
                call value    => 2;
                call coordsys => 'first';
            },
            sub { call value => -3 },
        ),

        check(
            { x => 1, y => 2, z => [ screen => -3 ] },
            sub { call value => 1 },
            sub { call value => 2 },
            sub {
                call value    => -3;
                call coordsys => 'screen';
            },
        ),
    );
};


type_subtest CoordPosition2D, sub ( $type ) {

    my sub check ( $value, $x, $y ) {
        $value => check2D( 'CXC::Gnuplot::V1::CoordPosition2D', $x, $y );
    }

    should_coerce_into(
        $type,
        check( { x => 1, y => 2 },
            sub { call value => 1 },
            sub { call value => 2 },
        ),

        check(
            { x => [ second => 1 ], y => 2 },
            sub {
                call value    => 1;
                call coordsys => 'second';
            },
            sub { call value => 2; },
        ),

        check(
            { x => 1, y => [ first => 2 ] },
            sub { call value => 1; },
            sub {
                call value    => 2;
                call coordsys => 'first';
            },
        ),

        check(
            { x => { coordsys => 'second', value => 1 }, y => { value => 1 } },
            sub {
                call value    => 1;
                call coordsys => 'second';
            },
            sub { call value => 1; },
        ),

    );
};

type_subtest CoordPosition3D, sub ( $type ) {

    my sub check ( $value, $x, $y, $z ) {
        $value => check3D( 'CXC::Gnuplot::V1::CoordPosition3D', $x, $y, $z );
    }

    should_coerce_into(
        $type,
        check(
            { x => 1, y => 2, z => -3 },
            sub { call value => 1; },
            sub { call value => 2; },
            sub { call value => -3; },
        ),

        check(
            { x => [ second => 1 ], y => 2, z => -3 },
            sub {
                call value    => 1;
                call coordsys => 'second';
            },
            sub { call value => 2; },
            sub { call value => -3; },
        ),

        check(
            { x => 1, y => [ first => 2 ], z => -3 },
            sub { call value => 1; },
            sub {
                call value    => 2;
                call coordsys => 'first';
            },
            sub { call value => -3; },
        ),

        check(
            { x => 1, y => 2, z => [ screen => -3 ] },
            sub { call value => 1; },
            sub { call value => 2; },
            sub {
                call value    => -3;
                call coordsys => 'screen';
            },
        ),
    );

};


sub check_TicPosition ( $expected ) {
    check_LiteralDataValue( $expected );
}

type_subtest TicPosition, sub ( $type ) {

    my sub check ( $value, $expected = $value ) {
        $value => check_TicPosition( $expected );
    }

    should_coerce_into( $type, check( 33 ), check( '2000-01-20' ) );
};


sub check_TicEntry ( $expected ) {

    my %check = (
        pos   => sub { check_TicPosition( $_[0] ) },
        label => sub { $_[0]; },
        level => sub { $_[0]; },
    );

    hash {
        if ( is_hashref( $expected ) ) {
            field $_ => $check{$_}->( $expected->{$_} ) for keys $expected->%*;
        }
        else {
            field pos => $check{pos}->( $expected );
        }
        end;
    }
}


type_subtest TicEntry, sub ( $type ) {

    my sub check ( $value, $expected = $value ) {
        $value => check_TicEntry( $expected );
    }

    should_pass_initially( $type, { pos => fLiteralDataValue( 33 ) }, );

    should_coerce_into(
        $type,
        check( 33 => { pos => 33 } ),
        check( { pos => 33 } ),
        check( { pos => 33, label => 'foo' } ),
        check( { pos => 33, label => 'foo', level => 0 } ),
    );

    should_fail( $type, { pos => 33, level => -1 } );
};

sub check_TicEntries ( $expected ) {

    $expected = [$expected] unless is_arrayref( $expected );
    array {
        for my $entry ( $expected->@* ) {
            item check_TicEntry( $entry );
        }
        end;
    };

}

type_subtest TicEntries, sub ( $type ) {

    my sub check ( $value, $expected = $value ) {
        $value => check_TicEntries( $expected );
    }

    should_coerce_into(
        $type,
        check( { pos => 33 } ),
        check( [ { pos => 33 } ] ),
        check( { pos => 33, label => 'foo' } ),
        check( [ { pos => 33, label => 'foo' } ] ),
        check( { pos => 33, label => 'foo', level => 0 } ),
        check( [ { pos => 33, label => 'foo', level => 0 } ] ),
    );

    should_fail( $type, { pos => 33, level => -1 } );
};

sub check_TicTimeIncr ( $expected ) {
    hash {
        field $_ => $expected->{$_} for keys $expected->%*;
        end;
    };
}

type_subtest TicTimeIncr, sub ( $type ) {

    my sub check ( $value, $expected ) {
        $value => check_TicTimeIncr( $expected );
    }

    should_pass_initially( $type, { multiple => 1, unit => 'seconds' } );

    should_coerce_into( $type, check( [ 1, 'seconds' ] => { multiple => 1, unit => 'seconds' } ), );
};

sub check_TicIncr( $expected ) {
    !is_ref( $expected )
      ? $expected
      : hash {
        field $_ => $expected->{$_} for keys $expected->%*;
        end;
      };
}

type_subtest TicIncr, sub ( $type ) {

    should_pass_initially( $type, 33, { multiple => 1, unit => 'seconds' } );

    should_coerce_into( $type, [ 1, 'seconds' ] => { multiple => 1, unit => 'seconds' } );
};

sub check_TicSeries ( $expected ) {

    my %check = (
        start => sub { check_TicPosition( $_[0] ) },
        incr  => sub { check_TicIncr( $_[0] ) },
        end   => sub { check_TicPosition( $_[0] ) },
    );

    hash {
        field $_ => $check{$_}->( $expected->{$_} ) for keys $expected->%*;
        end;
    };

}

type_subtest TicSeries, sub ( $type ) {

    my sub check ( $value, $expected = $value ) {
        $value => check_TicSeries( $expected );
    }

    should_pass_initially( $type, { incr => -33 } );

    should_coerce_into(
        $type,
        check( { start => 0, incr => -2 }, ),
        check( { start => 0, incr => -2, end => 33 } ),
        check(
            { start => 0, incr => [ 2, 'seconds' ], end => 33 },
            {
                start => 0,
                incr  => { multiple => 2, unit => 'seconds' },
                end   => 33
            },
        ),
    );

};

sub check_AddTicEntries ( $expected ) {

    my ( $add, @entries ) = $expected->@*;

    array {
        item $add;
        for my $entry ( @entries ) {
            item check_TicEntry( $entry );
        }
        end;
    }
}

sub check_TicList ( $expected ) {
    my $is_add = is_arrayref( $expected ) && !is_ref $expected->[0];

    $is_add
      ? check_AddTicEntries( $expected )
      : check_TicEntries( $expected );
}

type_subtest TicList, sub ( $type ) {

    my sub check( $value, $expected = $value ) {
        $value => check_TicList( $expected );
    }

    should_pass_initially(
        $type,
        [ { pos => fLiteralDataValue( 3 ) } ],
        [ add => { pos => fLiteralDataValue( -33 ) } ],
    );

    should_coerce_into(
        $type,
        check( 3,   [ { pos => 3 } ] ),
        check( [3], [ { pos => 3 } ] ),
        check( { pos => 3 } => [ { pos => 3 } ] ),
        check( [ { pos => 3 } ] ),

        check( [ { pos => -33, label => 'l1', level => 1 }, { pos => -44, label => 'l2', level => 1 } ] ),

        check( [ add => -33 ], [ add => { pos => -33 } ], ),

        check(
            [ add => { pos => -33, label => 'l1', level => 1 }, { pos => -44, label => 'l2', level => 1 } ],
            [
                add => { pos => -33, label => 'l1', level => 1 },
                { pos => -44, label => 'l2', level => 1 } ]
        ),
    );
};


type_subtest MultiPlotLayout, sub ( $type ) {

    should_pass_initially( $type, { nrows => 1, ncols => 2 } );

    should_coerce_into(
        $type,
        [ 1, 2 ] => { nrows => 1, ncols => 2 },
        '1,2'    => { nrows => 1, ncols => 2 },
    );

    should_fail(
        $type, [1],
        [ -1,  2 ],
        [  1, -2 ],
        '1', '-1,2', '1,-2',
        { nrows => 1 },
        { ncols => 1 },
        { nrows => -1, ncols =>  2 },
        { nrows =>  1, ncols => -2 },
    );
};

type_subtest RGBColor, sub ( $type ) {

    should_pass_initially( $type, '0x012345', '0xABCDEFED', '#ABCDEF', '#DEFEDCBA', );
};


sub check_Palette( $expected ) {

    !is_ref( $expected )
      and return $expected;

    defined $expected->{cb}
      and return hash {
        field cb => object {
            prop blessed => 'CXC::Gnuplot::V1::Range';
            call $_ => $expected->{cb}{$_} for keys $expected->{cb}->%*;
        };
        end;
      };

    return hash {
        field $_ => $expected->{$_} for keys $expected->%*;
    };

}

type_subtest Palette, sub ( $type ) {

    my sub check ( $value, $expected = $value ) {
        $value => check_Palette( $expected );
    }

    my %range = ( min => 0, max => 1 );

    should_pass_initially(
        $type, 'z',
        { frac => 0.2 },
        { cb   => CXC::Gnuplot::V1::Range->new( %range ) },
    );

    should_coerce_into( $type, check( { cb => \%range } ), );

};

done_testing;

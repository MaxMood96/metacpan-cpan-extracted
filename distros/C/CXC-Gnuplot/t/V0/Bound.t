#! perl

use v5.38;

use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::Bound::Numeric';

sub expect_pass ( $input, $expected ) {

    my $ctx = context;

    is(
        Numeric->new( $input->%* ),
        object {
            prop blessed => Numeric;
            call $_ => $expected->{$_} for keys $expected->%*;
        },
        'contents',
    );

    $ctx->release;
}

subtest 'new' => sub {

    subtest 'bound' => sub {

        subtest 'legal' => sub {

            subtest 'Num' => sub {

                expect_pass(
                    { bound => 3 },
                    {
                        bound       => 3,
                        lower_bound => U(),
                        upper_bound => U(),
                        to_string   => '3',
                    } );
            };

            subtest '"*"' => sub {

                expect_pass(
                    { bound => q{*} },
                    {
                        bound       => q{*},
                        lower_bound => U(),
                        upper_bound => U(),
                        to_string   => q{*},
                    } );

            };

        };

        subtest 'illegal' => sub {

            like( dies { Numeric->new( bound => 'q' ) }, qr/must be a number/, '"q"' );

            like( dies { Numeric->new( lower_bound => 'q' ) }, qr/validate/, '"q"' );

            like( dies { Numeric->new( upper_bound => 'q' ) }, qr/validate/, '"q"' );

        };

    };

    subtest 'lower_bound' => sub {

        expect_pass(
            { lower_bound => 3 },
            {
                bound       => q{*},
                lower_bound => 3,
                upper_bound => U(),
                to_string   => '3 < *',
            } );
    };

    subtest 'upper_bound' => sub {

        expect_pass(
            { upper_bound => 3 },
            {
                bound       => q{*},
                upper_bound => 3,
                lower_bound => U(),
                to_string   => '* < 3',
            } );

    };

    subtest 'lb, ub' => sub {

        expect_pass( {
                lower_bound => 1,
                upper_bound => 3
            },
            {
                bound       => q{*},
                upper_bound => 3,
                lower_bound => 1,
                to_string   => '1 < * < 3',
            } );

    };

    subtest 'lb, b' => sub {

        subtest 'lb, bound ne "*"' => sub {
            like( dies { Numeric->new( lower_bound => 1, bound => 3 ) }, qr/cannot be a number/, 'construct' );
        };

        subtest 'lb, bound eq "*"' => sub {

            expect_pass( {
                    lower_bound => 1,
                    bound       => q{*},
                },
                {
                    bound       => q{*},
                    upper_bound => U(),
                    lower_bound => 1,
                    to_string   => '1 < *',
                } );
        };

    };

    subtest 'ub, b' => sub {

        subtest 'ub, bound ne "*"' => sub {
            like( dies { Numeric->new( upper_bound => 1, bound => 3 ) }, qr/cannot be a number/, 'construct' );
        };

        subtest 'ub, bound eq "*"' => sub {

            expect_pass( {
                    upper_bound => 1,
                    bound       => q{*},
                },
                {
                    bound       => q{*},
                    lower_bound => U(),
                    upper_bound => 1,
                    to_string   => '* < 1',
                } );

        };
    };

};


sub expect_pass_from_string ( $string, $expected ) {

    my $ctx = context;

    is(
        Numeric->new_from_string( $string ),
        object {
            prop blessed => Numeric;
            call $_ => $expected->{$_} for keys $expected->%*;
        },
        $string,
    );

    $ctx->release;
}

subtest new_from_string => sub {

    subtest 'legal' => sub {

        expect_pass_from_string(
            '1 < * < 4',
            {
                lower_bound => 1,
                bound       => q{*},
                upper_bound => 4,
                to_string   => q{1 < * < 4},
            } );


        expect_pass_from_string(
            '0 < * < 4',
            {
                lower_bound => 0,
                bound       => q{*},
                upper_bound => 4,
                to_string   => q{0 < * < 4},
            } );


        expect_pass_from_string(
            '-1 < * < 0',
            {
                lower_bound => -1,
                bound       => q{*},
                upper_bound => 0,
                to_string   => q{-1 < * < 0},
            } );


        expect_pass_from_string(
            '* < 4',
            {
                lower_bound => U(),
                bound       => q{*},
                upper_bound => 4,
                to_string   => q{* < 4},
            } );

        expect_pass_from_string(
            '* < 0',
            {
                lower_bound => U(),
                bound       => q{*},
                upper_bound => 0,
                to_string   => q{* < 0},
            } );

        expect_pass_from_string(
            '1 < *',
            {
                lower_bound => 1,
                bound       => q{*},
                upper_bound => U(),
                to_string   => q{1 < *},
            } );

        expect_pass_from_string(
            '0 < *',
            {
                lower_bound => 0,
                bound       => q{*},
                upper_bound => U(),
                to_string   => q{0 < *},
            } );

        expect_pass_from_string(
            q{*},
            {
                lower_bound => U(),
                bound       => q{*},
                upper_bound => U(),
                to_string   => q{*},
            } );

        expect_pass_from_string(
            q{-22.2},
            {
                lower_bound => U(),
                bound       => q{-22.2},
                upper_bound => U(),
                to_string   => q{-22.2},
            } );

    };

    subtest 'illegal' => sub {

        for my $test (
            [ '3 < 4',     qr/illegal/ ],
            [ '1 < * < *', qr/illegal/ ],
            [ '* < * < 4', qr/illegal/ ],
            [ '1 < 2 < 4', qr/illegal/ ],
          )
        {
            like(
                dies {
                    Numeric->new_from_string( $test->[0] )
                },
                $test->[1],
                $test->[0],
            );
        }

    };

};

subtest assert_coerce => sub {

    subtest 'hashref' => sub {

        is(
            Numeric->assert_coerce( {
                    upper_bound => 1,
                    bound       => q{*},
                },
            ),
            object {
                prop blessed => Numeric;
                call bound       => q{*};
                call lower_bound => U();
                call upper_bound => 1;
                call to_string   => '* < 1';
            } );

    };

    subtest 'hash' => sub {

        is(
            Numeric->assert_coerce(
                upper_bound => 1,
                bound       => q{*},
            ),
            object {
                prop blessed => Numeric;
                call bound       => q{*};
                call lower_bound => U();
                call upper_bound => 1;
                call to_string   => '* < 1';
            } );

    };

    subtest 'string' => sub {
        is(
            Numeric->assert_coerce( '* < 4', ),
            object {
                prop blessed => Numeric;
                call lower_bound => U();
                call bound       => q{*};
                call upper_bound => 4;
                call to_string   => q{* < 4};
            } );

    };

    subtest 'object' => sub {
        is(
            Numeric->assert_coerce( Numeric->assert_coerce( '* < 4', ) ),
            object {
                prop blessed => Numeric;
                call lower_bound => U();
                call bound       => q{*};
                call upper_bound => 4;
                call to_string   => q{* < 4};
            } );

    };

};

done_testing;

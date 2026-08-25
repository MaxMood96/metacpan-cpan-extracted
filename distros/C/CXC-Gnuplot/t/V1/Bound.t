#! perl

use v5.38;

use Test::Lib;
use My::Test;
use Data::Dump 'pp';

use aliased 'CXC::Gnuplot::V1::Bound';
use aliased 'CXC::Gnuplot::V1::Bound::Numeric';
use aliased 'CXC::Gnuplot::V1::Bound::TimeDate';

my %cases = (
    Numeric() => {
        pass => [ {
                input    => { bound => 3 },
                expected => {
                    bound       => 3,
                    lower_bound => U(),
                    upper_bound => U(),
                    to_string   => '3',
                },
            },
            {
                input    => { bound => q{*} },
                expected => {
                    bound       => q{*},
                    lower_bound => U(),
                    upper_bound => U(),
                    to_string   => q{*},
                },
            },
            {
                input    => { lower_bound => 3 },
                expected => {
                    bound       => q{*},
                    lower_bound => 3,
                    upper_bound => U(),
                    to_string   => '3 < *',
                },
            },
            {
                input    => { upper_bound => 3 },
                expected => {
                    bound       => q{*},
                    upper_bound => 3,
                    lower_bound => U(),
                    to_string   => '* < 3',
                },
            },
            {
                input => {
                    upper_bound => 1,
                    bound       => q{*},
                },
                expected => {
                    bound       => q{*},
                    lower_bound => U(),
                    upper_bound => 1,
                    to_string   => '* < 1',
                },
            },
            {
                input => {
                    lower_bound => 1,
                    upper_bound => 3,
                },
                expected => {
                    bound       => q{*},
                    upper_bound => 3,
                    lower_bound => 1,
                    to_string   => '1 < * < 3',
                },
            },
            {
                input => {
                    lower_bound => 1,
                    bound       => q{*},
                },
                expected => {
                    bound       => q{*},
                    upper_bound => U(),
                    lower_bound => 1,
                    to_string   => '1 < *',
                },
            },
            {
                input    => { bound => '1 < * < 4' },
                expected => {
                    lower_bound => 1,
                    bound       => q{*},
                    upper_bound => 4,
                    to_string   => q{1 < * < 4},
                },
            },
            {
                input    => { bound => '0 < * < 4' },
                expected => {
                    lower_bound => 0,
                    bound       => q{*},
                    upper_bound => 4,
                    to_string   => q{0 < * < 4},
                },
            },
            {
                input    => { bound => '-1 < * < 0' },
                expected => {
                    lower_bound => -1,
                    bound       => q{*},
                    upper_bound => 0,
                    to_string   => q{-1 < * < 0},
                },
            },
            {
                input    => { bound => '* < 4' },
                expected => {
                    lower_bound => U(),
                    bound       => q{*},
                    upper_bound => 4,
                    to_string   => q{* < 4},
                },
            },
            {
                input    => { bound => '* < 0' },
                expected => {
                    lower_bound => U(),
                    bound       => q{*},
                    upper_bound => 0,
                    to_string   => q{* < 0},
                },
            },
            {
                input    => { bound => '1 < *' },
                expected => {
                    lower_bound => 1,
                    bound       => q{*},
                    upper_bound => U(),
                    to_string   => q{1 < *},
                },
            },
            {
                input    => { bound => '0 < *' },
                expected => {
                    lower_bound => 0,
                    bound       => q{*},
                    upper_bound => U(),
                    to_string   => q{0 < *},
                },
            },
            {
                input    => { bound => q{-22.2} },
                expected => {
                    lower_bound => U(),
                    bound       => q{-22.2},
                    upper_bound => U(),
                    to_string   => q{-22.2},
                },
            },
        ],

        fail => [ {
                input    => { bound => 'q' },
                expected => {
                    direct  => qr/must be a number/,
                    factory => qr/illegal bounds specification/,
                },
            },
            {
                input    => { lower_bound => 'q' },
                expected => {
                    direct  => qr/validate/,
                    factory => qr/unable to construct object/,
                },
            },
            {
                input    => { upper_bound => 'q' },
                expected => {
                    direct  => qr/validate/,
                    factory => qr/unable to construct object/,
                },
            },
            {
                input    => { lower_bound => 1, bound => 3 },
                expected => {
                    direct  => qr/cannot be a number/,
                    factory => qr/cannot be a number/,
                },
            },
            {
                input    => { upper_bound => 1, bound => 3 },
                expected => {
                    direct  => qr/cannot be a number/,
                    factory => qr/cannot be a number/,
                },
            },
            {
                input    => { bound => '3 < 4' },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
            {
                input    => { bound => '1 < * < *' },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
            {
                input    => { bound => '* < * < 4' },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
            {
                input    => { bound => '1 < 2 < 4' },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
        ],
    },

    TimeDate() => {
        pass => [ {
                input    => { bound => q{"2020-01-01"} },
                expected => {
                    bound       => q{"2020-01-01"},
                    lower_bound => U(),
                    upper_bound => U(),
                    to_string   => q{"2020-01-01"},
                },
            },
            {
                input => {
                    lower_bound => q{"2020-01-01"},
                    bound       => q{*},
                },
                expected => {
                    bound       => q{*},
                    lower_bound => q{"2020-01-01"},
                    upper_bound => U(),
                    to_string   => q{"2020-01-01" < *},
                },
            },
            {
                input => {
                    upper_bound => q{"2020-02-01"},
                    bound       => q{*},
                },
                expected => {
                    bound       => q{*},
                    lower_bound => U(),
                    upper_bound => q{"2020-02-01"},
                    to_string   => q{* < "2020-02-01"},
                },
            },
            {
                input => {
                    lower_bound => q{"2020-01-01"},
                    upper_bound => q{"2020-02-01"},
                },
                expected => {
                    bound       => q{*},
                    lower_bound => q{"2020-01-01"},
                    upper_bound => q{"2020-02-01"},
                    to_string   => q{"2020-01-01" < * < "2020-02-01"},
                },
            },
        ],

        fail => [ {
                input    => { bound => q{"2020-01-01" < "2020-02-01"} },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
            {
                input    => { bound => q{"2020-01-01" < * < *} },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
            {
                input    => { bound => q{* < * < "2020-02-01"} },
                expected => {
                    direct  => qr/illegal/,
                    factory => qr/illegal/,
                },
            },
        ],
    },
);

sub expect_object ( $class, $input, $expected, $name ) {

    my $ctx = context;

    is(
        $class->new( $input->%* ),
        object {
            prop blessed => $class;
            call $_ => $expected->{$_} for keys $expected->%*;
        },
        $name,
    );

    $ctx->release;
}

sub expect_factory_object ( $input, $subclass, $expected, $name ) {

    my $ctx = context;

    is(
        Bound->new( $input->%* ),
        object {
            prop isa     => Bound;
            prop blessed => $subclass;
            call $_ => $expected->{$_} for keys $expected->%*;
        },
        $name,
    );

    $ctx->release;
}

sub run_factory_pass_cases ( $subclass, $tests ) {
    subtest 'factory pass' => sub {
        for my $test ( $tests->@* ) {
            expect_factory_object( $test->{input}, $subclass, $test->{expected}, pp( $test->{input} ) );
        }
    };
}

sub run_direct_pass_cases ( $class, $tests ) {
    subtest 'direct pass' => sub {
        for my $test ( $tests->@* ) {
            expect_object( $class, $test->{input}, $test->{expected}, pp( $test->{input} ) );
        }
    };
}

sub run_fail_cases ( $label, $constructor, $tests ) {
    subtest "$label fail" => sub {
        for my $test ( $tests->@* ) {
            like( dies { $constructor->( $test->{input} ) }, $test->{expected}{$label}, pp( $test->{input} ) );
        }
    };
}

subtest factory => sub {
    for my $class ( Numeric, TimeDate ) {
        subtest $class => sub {
            run_factory_pass_cases( $class, $cases{$class}{pass} );
            run_fail_cases( 'factory', sub ( $input ) { Bound->new( $input->%* ) }, $cases{$class}{fail} );
        };
    }

    subtest 'mixed args fail' => sub {
        like(
            dies {
                Bound->new(
                    lower_bound => 1,
                    upper_bound => q{"2020-02-01"},
                );
            },
            qr/unable to construct object/,
            'mixed numeric and timedate',
        );
    };
};

for my $class ( Numeric, TimeDate ) {
    subtest $class => sub {
        run_direct_pass_cases( $class, $cases{$class}{pass} );
        run_fail_cases( 'direct', sub ( $input ) { $class->new( $input->%* ) }, $cases{$class}{fail} );
    };
}

done_testing;

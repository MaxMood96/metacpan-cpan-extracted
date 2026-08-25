#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::Terminal::pngcairo';
use Data::Dump 'pp';

sub expect_fields ( $input, $expected ) {

    my $ctx = context;

    subtest pp( $input ) => sub {

        my $term;
        ok( lives { $term = pngcairo->new( $input->%* ) }, 'construct' )
          or bail_out( $@ );

        is(
            $term,
            object {
                prop blessed => pngcairo;
                call $_ => $expected->{$_} for keys $expected->%*;
            },
            'contents',
        );
    };

    $ctx->release;
}

sub expect_opts ( $input, $expected ) {

    my $ctx = context;

    subtest pp( $input ) => sub {

        my $term;
        ok( lives { $term = pngcairo->new( $input->%* ) }, 'construct' )
          or bail_out( $@ );

        is(
            [ $term->opts ],
            validator(
                sub {
                    my @array = $_->@*;
                    is( shift @array, q{pngcairo} );
                    is(
                        \@array,
                        bag {
                            item $_ for $expected->@*;
                            end;
                        },
                    );
                },
            ),
            'opts',
        );
    };

    $ctx->release;
}

expect_opts( {}, [] );

subtest 'boolean' => sub {

    for my $opt ( qw( enhanced transparent crop ) ) {
        expect_opts( { $opt => undef }, [] );
        expect_opts( { $opt => true },  [$opt] );
        expect_opts( { $opt => false }, ["no$opt"] );
    }

    expect_opts( { color => undef }, [] );
    expect_opts( { color => true },  ['color'] );
    expect_opts( { color => false }, ['mono'] );

};

expect_opts( { background => undef },     [] );
expect_opts( { background => q{'blue'} }, [ [ background => q{'blue'} ] ] );

expect_opts( { fontscale => undef }, [] );
expect_opts( { fontscale => 1.2 },   [ [ fontscale => q{1.2} ] ] );
expect_opts( { linewidth => undef }, [] );
expect_opts( { linewidth => 1.3 },   [ [ linewidth => q{1.3} ] ] );

expect_opts( { linejoin => undef },     [] );
expect_opts( { linejoin => 'rounded' }, ['rounded'] );
expect_opts( { linejoin => 'butt' },    ['butt'] );
expect_opts( { linejoin => 'square' },  ['square'] );

expect_opts( { dashlength => undef }, [] );
expect_opts( { dashlength => 1.4 },   [ [ dashlength => q{1.4} ] ] );

expect_opts( { pointscale => undef }, [] );
expect_opts( { pointscale => 1.5 },   [ [ pointscale => q{1.5} ] ] );


done_testing;

1;

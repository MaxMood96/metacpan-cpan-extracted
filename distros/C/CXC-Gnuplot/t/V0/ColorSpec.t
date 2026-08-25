#! perl

use v5.28;

use Test::Lib;
use My::Test;

use CXC::Gnuplot::V0::Util 'gnuplot_color_names';

use aliased 'CXC::Gnuplot::V0::ColorSpec';
use aliased 'CXC::Gnuplot::V0::Range';

subtest 'palette' => sub {

    subtest 'frac' => sub {

        my %args     = ( palette => { frac => 0.2 } );
        my $palette  = ColorSpec->new( %args );
        my $expected = object {
            prop blessed => ColorSpec;
            call palette => hash {
                field frac => 0.2;
                end;
            };
        };

        is( $palette, $expected, 'new' );

        is(
            [ $palette->opts ],
            array {
                item array {
                    item 'palette';
                    item array {
                        item 'frac';
                        item 0.2;
                        end;
                    };
                    end;
                };
                end;
            },
            'opts',
        );

        subtest 'assert_coerce' => sub {
            is( ColorSpec->assert_coerce( \%args ),                  $expected, 'hashref' );
            is( ColorSpec->assert_coerce( ColorSpec->new( %args ) ), $expected, 'Object' );

        };

    };

    subtest 'cb' => sub {

        my %args     = ( palette => { cb => { min => 0, max => 5 } } );
        my $palette  = ColorSpec->new( %args );
        my $expected = object {
            prop blessed => ColorSpec;
            call palette => hash {
                field cb => object {
                    prop blessed => Range;
                    call min => object {
                        call bound => 0;
                    };
                    call max => object {
                        call bound => 5;
                    };
                };
                end;
            };
        };

        is( $palette, $expected, 'new' );

        is(
            [ $palette->opts ],
            array {
                item array {
                    item 'palette';
                    item array {
                        item 'cb';
                        item q{[0:5]};
                        end;
                    };
                    end;
                };
                end;
            },
            'opts',
        );

        subtest 'assert_coerce' => sub {
            is( ColorSpec->assert_coerce( \%args ),                  $expected, 'hashref' );
            is( ColorSpec->assert_coerce( ColorSpec->new( %args ) ), $expected, 'Object' );

        };

    };


    subtest 'z' => sub {

        my %args     = ( palette => 'z' );
        my $palette  = ColorSpec->new( %args );
        my $expected = object {
            prop blessed => ColorSpec;
            call palette => 'z';
        };

        is( $palette, $expected, 'new' );

        is(
            [ $palette->opts ],
            array {
                item array {
                    item 'palette';
                    item 'z';
                    end;
                };
                end;
            },
            'opts',
        );

        subtest 'assert_coerce' => sub {
            is( ColorSpec->assert_coerce( \%args ),                  $expected, 'hashref' );
            is( ColorSpec->assert_coerce( ColorSpec->new( %args ) ), $expected, 'Object' );

        };

    };


};

subtest 'rgbcolor' => sub {

    subtest 'color' => sub {
        for my $color ( gnuplot_color_names, '0x00FF00', '0xEE00FFBB', '#FF00FF', '#ABCDEF00' ) {
            subtest $color => sub {
                my %args     = ( rgbcolor => $color );
                my $rgbcolor = ColorSpec->new( %args );
                my $expected = object {
                    prop blessed => ColorSpec;
                    call rgbcolor => $color;
                };

                is( $rgbcolor, $expected, 'new' );

                is(
                    [ $rgbcolor->opts ],
                    array {
                        item array {
                            item 'rgbcolor';
                            item qq{"$color"};
                            end;
                        };
                        end;
                    },
                    'opts',
                );

                subtest 'assert_coerce' => sub {
                    is( ColorSpec->assert_coerce( $color ),                  $expected, 'scalar' );
                    is( ColorSpec->assert_coerce( \%args ),                  $expected, 'hashref' );
                    is( ColorSpec->assert_coerce( ColorSpec->new( %args ) ), $expected, 'Object' );
                };
            };
        }
    };

    subtest 'integer' => sub {
        my $color    = 99;
        my %args     = ( rgbcolor => $color );
        my $rgbcolor = ColorSpec->new( %args );
        my $expected = object {
            prop blessed => ColorSpec;
            call rgbcolor => $color;
        };

        is( $rgbcolor, $expected, 'new' );

        is(
            [ $rgbcolor->opts ],
            array {
                item array {
                    item 'rgbcolor';
                    item $color;
                    end;
                };
                end;
            },
            'opts',
        );

        subtest 'assert_coerce' => sub {
            is( ColorSpec->assert_coerce( $color ),                  $expected, 'scalar' );
            is( ColorSpec->assert_coerce( \%args ),                  $expected, 'hashref' );
            is( ColorSpec->assert_coerce( ColorSpec->new( %args ) ), $expected, 'Object' );
        };
    };


};

subtest 'everything else' => sub {

    for my $color ( 'bgnd', 'variable' ) {

        subtest $color => sub {

            my %args     = ( rgbcolor => $color );
            my $rgbcolor = ColorSpec->new( %args );
            my $expected = object {
                prop blessed => ColorSpec;
                call rgbcolor => $color;
            };

            is( $rgbcolor, $expected, 'new' );

            is(
                [ $rgbcolor->opts ],
                array {
                    $color eq 'variable'
                      ? item array {
                        item 'rgbcolor';
                        item $color;
                        end;
                      }
                      : item $color;

                    end;
                },
                'opts',
            );

            subtest 'assert_coerce' => sub {
                is( ColorSpec->assert_coerce( $color ),                  $expected, 'scalar' );
                is( ColorSpec->assert_coerce( \%args ),                  $expected, 'hashref' );
                is( ColorSpec->assert_coerce( ColorSpec->new( %args ) ), $expected, 'Object' );
            };
        }

    }

};


done_testing;

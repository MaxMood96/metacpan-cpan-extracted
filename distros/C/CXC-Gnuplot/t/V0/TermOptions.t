#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::TermOptions';
use aliased 'CXC::Gnuplot::V0::Font';

subtest 'new' => sub {

    is(
        TermOptions->new(
            font => {
                name => 'foo',
                size => 12,
            },
            enhanced   => true,
            fontscale  => 2,
            linewidth  => 3,
            dashlength => 4,
            pointscale => 5,
        ),
        object {
            prop blessed => TermOptions;
            call_list [ set => as => 'array' ] => bag {
                item [ set => termoption => font => q{"foo,12"} ];
                item [ set => termoption => 'enhanced' ];
                item [ set => termoption => fontscale  => 2 ];
                item [ set => termoption => linewidth  => 3 ];
                item [ set => termoption => dashlength => 4 ];
                item [ set => termoption => pointscale => 5 ];
                end;
            };
        },
        'everything',
    );

    subtest 'enhanced' => sub {

        is(
            TermOptions->new,
            object {
                call_list set => array {};
            },
            'unspecified',
        );

        is(
            TermOptions->new( enhanced => true ),
            object {
                call_list [ set => as => 'array' ] => array {
                    item [ set => termoption => 'enhanced' ];
                    end;
                };
            },
            'true',
        );

        is(
            TermOptions->new( enhanced => false ),
            object {
                call_list [ set => as => 'array' ] => array {
                    item [ set => termoption => 'noenhanced' ];
                    end;
                };
            },
            'false',
        );

    };
};

subtest 'assert_coerce' => sub {

    is(
        TermOptions->assert_coerce( {
                font => {
                    name => 'foo',
                    size => 12,
                },
                enhanced   => true,
                fontscale  => 2,
                linewidth  => 3,
                dashlength => 4,
                pointscale => 5,
            },
        ),
        object {
            prop blessed => TermOptions;
            call font => object {
                prop blessed => Font;
                call name => 'foo';
                call size => 12;
            };
        },
        'hashref',
    );

};

done_testing;

#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::Margin';

subtest 'new' => sub {

    is(
        Margin->new(
            left  => [ at => screen => 22 ],
            top   => 33,
            right => false,
        ),
        object {
            prop blessed => Margin;
            call_list [ set => as => 'array' ] => bag {
                item [ set => lmargin => [ at => screen => 22 ] ];
                item [ set => rmargin => ];
                item [ set => tmargin => 33 ];
                end;
            };
        },
        'everything',
    );

};

subtest 'assert_coerce' => sub {

    is(
        Margin->assert_coerce( {
                left  => [ at => screen => 22 ],
                top   => 33,
                right => false,
            },
        ),
        object {
            prop blessed => Margin;
            call_list [ set => as => 'array' ] => bag {
                item [ set => lmargin => [ at => screen => 22 ] ];
                item [ set => rmargin => ];
                item [ set => tmargin => 33 ];
                end;
            };
        },
        'hashref',
    );

};

done_testing;

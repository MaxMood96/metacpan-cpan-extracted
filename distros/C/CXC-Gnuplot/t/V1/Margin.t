#! perl


use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::Margin';

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

done_testing;

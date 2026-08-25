#! perl

use Test2::V0;
use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V0::Title';

my %args = (
    text => "frank",
    font => {
        name => 'foo',
        size => 12,
    },
    offset    => 22,
    textcolor => 'blue',
    enhanced  => true,
);

my $expected = object {
    prop blessed => Title;
    call text => 'frank';
    call font => object {
        call name => 'foo';
        call size => 12;
    };
    call offset => object {
        call x => object {
            call value => 22;
        };
    };
    call textcolor => object {
        call rgbcolor => 'blue';
    };
};

my $title = Title->new( %args );

is( $title, $expected, 'new' );

subtest opts => sub {

    my @opts = $title->opts;

    is( shift @opts, q{"frank"}, 'text' );

    is(
        \@opts,
        bag {
            item [ font      => q{"foo,12"} ];
            item [ offset    => 22 ];
            item [ textcolor => [ rgbcolor => q{"blue"} ] ];
            item q{enhanced};
            end;
        },
        'options',
    );
};

is(
    $title->to_hash,
    hash {
        field text => 'frank';
        field font => hash {
            field name => 'foo';
            field size => 12;
            end;
        };
        field textcolor => hash {
            field rgbcolor => 'blue';
            end;
        };
        field offset => hash {
            field x => hash {
                field value => 22;
                end;
            };
            field y => hash {
                field value => 0;
                end;
            };
            field z => hash {
                field value => 0;
                end;
            };
        };
        field enhanced => true;
        end;
    },
    'to_hash',
);



subtest 'enhanced' => sub {

    is(
        Title->new,
        object {
            call_list [ set => as => 'array' ] => array {
                item array {
                    item 'set';
                    item 'title';
                    end;
                };
                end;
            };
        },
        'unspecified',
    );

    is(
        Title->new( enhanced => true ),
        object {
            call_list [ set => as => 'array' ] => array {
                item array {
                    item 'set';
                    item 'title';
                    item 'enhanced';
                    end;
                };
                end;
            };
        },
        'true',
    );

    is(
        Title->new( enhanced => false ),
        object {
            call_list [ set => as => 'array' ] => array {
                item array {
                    item 'set';
                    item 'title';
                    item 'noenhanced';
                    end;
                };
                end;
            };
        },
        'false',
    );

};


subtest 'assert_coerce' => sub {

    is( Title->assert_coerce( \%args ),              $expected, 'hashref' );
    is( Title->assert_coerce( Title->new( %args ) ), $expected, 'objct' );

    is(
        Title->assert_coerce( 'frank' ),
        object {
            call text => 'frank';
        },
        'scalar',
    );
};

done_testing;

#! perl

use Test::Lib;
use My::Test;

use aliased 'CXC::Gnuplot::V1::ColorSpec';
use aliased 'CXC::Gnuplot::V1::CoordOffset2D';
use aliased 'CXC::Gnuplot::V1::CoordOffset3D';
use aliased 'CXC::Gnuplot::V1::CoordPosition2D';
use aliased 'CXC::Gnuplot::V1::CoordPosition3D';
use aliased 'CXC::Gnuplot::V1::CoordValue';
use aliased 'CXC::Gnuplot::V1::Font';
use aliased 'CXC::Gnuplot::V1::Key';
use aliased 'CXC::Gnuplot::V1::Key::Title';

my %args = (
    at => {
        x => { coordsys => 'first', value => 1 },
        y => { value    => 1 },
    },
    autotitle => false,
    box       => true,
    columns   => 3,
    default   => false,
    enhanced  => true,
    font      => {
        name => 'foo',
        size => 12,
    },
    height           => 4,
    horiz            => 'left',
    invert           => false,
    justifyentrytext => 'right',
    keywidth         => [ screen => 2.5 ],
    layout           => 'horizontal',
    margin           => 'bottom',
    maxcols          => 'auto',
    maxrows          => 'auto',
    offset           => { x => { value => 1 }, y => { coordsys => 'second', value => 3 } },
    opaque           => true,
    region           => 'outside',
    reverse          => false,
    samplen          => 0.2,
    spacing          => 3,
    textcolor        => 'green',
    title            => {
        font => { size => 3 },
        text => 'Frank',
    },
    vert  => 'center',
    width => 3,
);

my $expected = object {
    prop blessed => Key;
    call at => object {
        prop blessed => CoordPosition2D;
        call x => object {
            call coordsys => 'first';
            call value    => 1;
        };
        call y => object {
            call value => 1;
        };
    };
    call autotitle => F();
    call box       => T();
    call columns   => 3;
    call default   => F();
    call enhanced  => T();
    call font      => object {
        prop blessed => Font;
        call name => 'foo';
        call size => 12;
    };
    call height           => 4;
    call horiz            => 'left';
    call invert           => F();
    call justifyentrytext => 'right';
    call keywidth         => array {
        item 'screen';
        item 2.5;
    };
    call layout  => 'horizontal';
    call margin  => 'bottom';
    call maxcols => 'auto';
    call maxrows => 'auto';
    call offset  => object {
        prop blessed => CoordOffset2D;
        call x => object {
            prop blessed => CoordValue;
            call value => 1;
        };
        call y => object {
            prop blessed => CoordValue;
            call coordsys => 'second';
            call value    => 3;
        };
    };
    call opaque    => T();
    call region    => 'outside';
    call reverse   => F();
    call samplen   => 0.2;
    call spacing   => 3;
    call textcolor => object {
        prop blessed => ColorSpec;
        call rgbcolor => 'green';
    };
    call title => object {
        prop blessed => Title;
        call font => object {
            prop blessed => Font;
            call size => 3;
        };
        call text => 'Frank';
    };
    call vert  => 'center';
    call width => 3;
};


is( Key->new( %args ), $expected, 'new' );

is(
    [ Key->new( %args )->opts ],
    bag {
        item array { item 'at'; item q{first 1,1}; end; };
        item 'box';
        item array { item 'columns'; item 3; end; };
        item 'enhanced';
        item array { item 'font';   item q{"foo,12"}; end; };
        item array { item 'height'; item 4;           end; };
        item 'left';
        item 'Right';
        item array { item 'keywidth'; item [ 'screen', 2.5 ]; end; };
        item 'horizontal';
        item 'bmargin';
        item array { item 'maxcols'; item 'auto'; end; };
        item array { item 'maxrows'; item 'auto'; end; };
        item 'noautotitle';
        item 'noinvert';
        item 'noreverse';
        item array { item 'offset'; item q{1,second 3}; end; };
        item array { item 'opaque'; item 1;             end; };
        item 'outside';
        item array { item 'samplen'; item 0.2; end; };
        item array { item 'spacing'; item 3;   end; };
        item array {
            item 'textcolor';
            item array {
                item 'rgbcolor';
                item q{"green"};
                end;
            };
            end;
        };

        item array {
            item 'title';
            item q{"Frank"};
            item array {
                item 'font';
                item q{",3"};
                end;
            };
            end;
        };
        item 'center';
        item array { item 'width'; item 3; end; };
        end;
    },
    'opts',
);

is(
    Key->new( %args )->to_hash,
    hash {
        field at => hash {
            field x => hash {
                field coordsys => 'first';
                field value    => 1;
                end;
            };
            field y => hash {
                field value => 1;
                end;
            };
        };
        field autotitle => false;
        field box       => true;
        field columns   => 3;
        field default   => false;
        field enhanced  => true;
        field font      => hash {
            field name => 'foo';
            field size => 12;
            end;
        };
        field height           => 4;
        field horiz            => 'left';
        field invert           => false;
        field justifyentrytext => 'right';
        field keywidth         => array {
            item 'screen';
            item 2.5;
            end;
        };
        field layout  => 'horizontal';
        field margin  => 'bottom';
        field maxcols => 'auto';
        field maxrows => 'auto';
        field offset  => hash {
            field x => hash {
                field value => 1;
                end;
            };
            field y => hash {
                field coordsys => 'second';
                field value    => 3;
                end;
            };
            end;
        };
        field opaque    => true;
        field region    => 'outside';
        field reverse   => false;
        field samplen   => 0.2;
        field spacing   => 3;
        field textcolor => hash { field rgbcolor => 'green'; end; };
        field title     => hash {
            field font => hash {
                field size => 3;
                end;
            };
            field text => 'Frank';
            end;
        };
        field vert  => 'center';
        field width => 3;
        end;
    },
    'to_hash',
);

done_testing;

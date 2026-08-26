use strict;
use warnings;

use Test::More;

use_ok 'Music::SimpleDrumMachine';

{
    package Test::FakeLoop;
    sub new { bless {}, shift }
    sub add { 1 }
    sub run { 1 } # return immediately instead of blocking forever
}

local *Music::SimpleDrumMachine::_loop = sub { Test::FakeLoop->new };

subtest defaults => sub {
    my $obj = new_ok 'Music::SimpleDrumMachine' => [ port_name => 'test' ];
    is $obj->beats,      16,               'beats';
    is $obj->bpm,        120,              'bpm';
    is $obj->chan,       9,                'chan';
    is $obj->divisions,  4,                'divisions';
    is $obj->fill_crash, 1,                'fill_crash';
    is $obj->filling,    1,                'filling';
    is $obj->next_fill,  '_default_fill',  'next_fill';
    is $obj->next_part,  '_default_part',  'next_part';
    is $obj->port_name,  'test',           'port_name';
    is $obj->ppqn,       24,               'ppqn';
    is $obj->velo_max,   10,               'velo_max';
    is $obj->velo_min,   -10,              'velo_min';
    is $obj->velo_off,   110,              'velo_off';
    is $obj->verbose,    0,                'verbose';
    is_deeply $obj->add_drums, [], 'add_drums';
    is ref($obj->drums), 'HASH', 'drums';
    is ref($obj->parts), 'HASH', 'parts';
    is ref($obj->fills), 'HASH', 'fills';
    ok exists $obj->parts->{_default_part}, 'default part exists';
    ok exists $obj->fills->{_default_fill}, 'default fill exists';
};

subtest drums => sub {
    my $obj = new_ok 'Music::SimpleDrumMachine' => [ port_name => 'test' ];
    my $drums = $obj->drums;
    is $drums->{kick}{num},   36, 'kick num';
    is $drums->{snare}{num},  38, 'snare num';
    is $drums->{closed}{num}, 42, 'closed num';
    is $drums->{kick}{chan},  9,  'kick chan uses the shared chan by default';
    is $drums->{snare}{chan}, 9,  'snare chan uses the shared chan by default';

    $obj = new_ok 'Music::SimpleDrumMachine' => [ port_name => 'test', chan => -1 ];
    isnt $obj->drums->{kick}{chan}, $obj->drums->{snare}{chan},
        'multi-timbral mode (chan => -1) assigns distinct channels';
};

subtest add_drums => sub {
    my $obj = new_ok 'Music::SimpleDrumMachine' => [
        port_name => 'test',
        add_drums => [ { drum => 'gong', num => 99 } ],
    ];
    ok exists $obj->drums->{gong}, 'added drum exists';
    is $obj->drums->{gong}{num},  99, 'added drum num';
    is $obj->drums->{gong}{chan}, 9,  'added drum uses the shared chan by default';

    $obj = new_ok 'Music::SimpleDrumMachine' => [
        port_name => 'test',
        chan      => -1,
        add_drums => [ { drum => 'gong', num => 99, chan => 5 } ],
    ];
    is $obj->drums->{gong}{chan}, 5, 'added drum honors an explicit chan';
};

subtest velocity => sub {
    my $obj = new_ok 'Music::SimpleDrumMachine' => [
        port_name => 'test',
        velo_min  => 0,
        velo_max  => 0,
        velo_off  => 127,
    ];
    is $obj->velocity, 127, 'fixed velocity when min == max == 0';

    $obj = new_ok 'Music::SimpleDrumMachine' => [
        port_name => 'test',
        velo_min  => -10,
        velo_max  => 10,
        velo_off  => 110,
    ];
    my $got = $obj->velocity;
    ok $got >= 100 && $got <= 120, "velocity in range: $got";
};

subtest parts_and_fills => sub {
    my $obj = new_ok 'Music::SimpleDrumMachine' => [ port_name => 'test' ];

    my ($next, $patterns) = $obj->_default_part;
    is $next, '_default_part', '_default_part next';
    is ref($patterns), 'HASH', '_default_part patterns';
    ok exists $patterns->{kick},   '_default_part has a kick pattern';
    ok exists $patterns->{snare},  '_default_part has a snare pattern';
    ok exists $patterns->{closed}, '_default_part has a closed pattern';

    my ($fnext, $fpatterns);
    for ( 1 .. 20 ) {
        my $ok = eval {
            ( $fnext, $fpatterns ) = $obj->_default_fill;
            1;
        };
        last if $ok;
    }
    is $fnext, '_default_fill', '_default_fill next';
    is ref($fpatterns), 'HASH', '_default_fill patterns';
    ok exists $fpatterns->{snare}, '_default_fill has a snare pattern';
};

done_testing();

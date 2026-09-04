#!/usr/bin/env perl

use Test::More;
use Data::Dumper::Compact qw(ddc);

use_ok 'Music::MelodicDevice::Arpeggiation';

subtest defaults => sub {
    my $mda = new_ok 'Music::MelodicDevice::Arpeggiation';# => [ verbose => 1 ];
    is $mda->duration, 1, 'duratiion';
    is $mda->type, 'up', 'type';
    is $mda->repeats, 1, 'repeats';
};

subtest arp => sub {
    my $mda = new_ok 'Music::MelodicDevice::Arpeggiation';# => [ verbose => 1 ];
    my $got = $mda->arp([60,64,67], 1, 'up');
    is_deeply $got, [['d32', 60],['d32', 64],['d32', 67]], 'arp';
    $got = $mda->arp([60,64,67], 1, 'down');
    is_deeply $got, [['d32', 67],['d32', 64],['d32', 60]], 'arp';
    $got = $mda->arp([60,64,67,69], 1, 'up');
    is_deeply $got, [['d24', 60],['d24', 64],['d24', 67], ['d24', 69]], 'arp';
    $mda->repeats(2);
    $got = $mda->arp([60,64,67], 1, 'up');
    is_deeply $got, [['d32', 60],['d32', 64],['d32', 67],['d32', 60],['d32', 64],['d32', 67]], 'arp';
    $mda->repeats(1);
    $got = $mda->arp([60,64,67], 0.5, 'up');
    is_deeply $got, [['d16', 60],['d16', 64],['d16', 67]], 'arp';
    # $mda->pattern([2,1,0]);
    # $got = $mda->arp([60,64,67]);
    # is_deeply $got, [['d16', 67],['d16', 64],['d16', 60]], 'arp';
};

subtest arp_type => sub {
    my $mda = new_ok 'Music::MelodicDevice::Arpeggiation';# => [ verbose => 1 ];
    my $got = $mda->arp_type;
    is ref($got), 'HASH', 'arp_type';
    $got = $mda->arp_type('up');
    is ref($got), 'CODE', 'arp_type';
    $mda->arp_type('foo', sub { [0,1] });
    $got = $mda->arp_type('foo');
    is ref($got), 'CODE', 'arp_type';
    $got = $mda->arp([60], 1, 'foo');
    is_deeply $got, [['d48', 60]], 'arp';
    $got = $mda->arp([60,64], 1, 'foo');
    is_deeply $got, [['d48', 60],['d48', 64]], 'arp';
    $got = $mda->arp([60,64,67], 1, 'foo');
    is_deeply $got, [['d48', 60],['d48', 64]], 'arp';
    $got = $mda->arp([60,64,67], 1, 'foo', 2);
    is_deeply $got, [['d48', 60],['d48', 64],['d48', 60],['d48', 64]], 'arp';
    $got = $mda->_build_pattern('updown', [60,61,62,63]);
    is_deeply $got, [0,1,2,3,2,1,0], 'build_pattern';
    $got = $mda->arp(['C4','E4','G4'], 1, 'up');
    is_deeply $got, [ [ 'd32', 'C4' ], [ 'd32', 'E4' ], [ 'd32', 'G4' ] ], 'up';
    $got = $mda->arp(['C4','E4','G4'], 1, 'down');
    is_deeply $got, [ [ 'd32', 'G4' ], [ 'd32', 'E4' ], [ 'd32', 'C4' ] ], 'down';
    $got = $mda->arp(['C4','E4','G4'], 1, 'updown');
    is_deeply $got, [
        ['d19','C4'], ['d19','E4'], ['d19','G4'], ['d19','E4'], ['d19','C4'],
    ], 'updown';

};

subtest pedal => sub {
    my $mda = new_ok 'Music::MelodicDevice::Arpeggiation';# => [ verbose => 1 ];

    my $got = $mda->_build_pattern('pedal_up', [60,61,62,63]);
    is_deeply $got, [0,1,0,2,0,3], 'build_pattern pedal_up';
    $got = $mda->_build_pattern('pedal_down', [60,61,62,63]);
    is_deeply $got, [3,2,3,1,3,0], 'build_pattern pedal_down';

    $got = $mda->arp([60,64,67,69], 1, 'pedal_up');
    is_deeply $got, [
        ['d16', 60],['d16', 64],['d16', 60],['d16', 67],['d16', 60],['d16', 69],
    ], 'pedal_up';
    $got = $mda->arp([60,64,67,69], 1, 'pedal_down');
    is_deeply $got, [
        ['d16', 69],['d16', 67],['d16', 69],['d16', 64],['d16', 69],['d16', 60],
    ], 'pedal_down';

    $got = $mda->arp(['C4','E4','G4'], 1, 'pedal_up');
    is_deeply $got, [
        ['d24','C4'], ['d24','E4'], ['d24','C4'], ['d24','G4'],
    ], 'pedal_up strings';
    $got = $mda->arp(['C4','E4','G4'], 1, 'pedal_down');
    is_deeply $got, [
        ['d24','G4'], ['d24','E4'], ['d24','G4'], ['d24','C4'],
    ], 'pedal_down strings';

    # a single note has nothing to step to or from
    $got = $mda->arp([60], 1, 'pedal_up');
    is_deeply $got, [ ['d96', 60] ], 'pedal_up single note';
    $got = $mda->arp([60], 1, 'pedal_down');
    is_deeply $got, [ ['d96', 60] ], 'pedal_down single note';

    $got = $mda->_build_pattern('pedal_updown', [60,61,62,63]);
    is_deeply $got, [0,1,0,2,0,3,2,3,1,3,0], 'build_pattern pedal_updown';

    $got = $mda->arp([60,64,67,69], 1, 'pedal_updown');
    is_deeply $got, [
        ['d9', 60],['d9', 64],['d9', 60],['d9', 67],['d9', 60],['d9', 69],
        ['d9', 67],['d9', 69],['d9', 64],['d9', 69],['d9', 60],
    ], 'pedal_updown';

    $got = $mda->arp(['C4','E4','G4'], 1, 'pedal_updown');
    is_deeply $got, [
        ['d14','C4'],['d14','E4'],['d14','C4'],['d14','G4'],
        ['d14','E4'],['d14','G4'],['d14','C4'],
    ], 'pedal_updown strings';

    $got = $mda->arp([60], 1, 'pedal_updown');
    is_deeply $got, [ ['d96', 60] ], 'pedal_updown single note';
};

done_testing();

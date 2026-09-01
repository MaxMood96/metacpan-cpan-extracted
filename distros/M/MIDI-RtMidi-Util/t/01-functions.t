#!/usr/bin/env perl

use Test::More;
use Test::Exception;

BEGIN {
    use_ok 'MIDI::RtMidi::Util', qw(out_port halt input_ports output_ports);
}

subtest throws => sub {
    throws_ok { out_port() }
        qr/Too few arguments/,
        'out_port() dies without port name';
    throws_ok { halt() }
        qr/Too few arguments/,
        'halt() dies without a port';
};

subtest defaults => sub {
    my $got = input_ports();
    is ref($got), 'ARRAY', 'input_ports';
    $got = output_ports();
    is ref($got), 'ARRAY', 'output_ports';
};

done_testing();

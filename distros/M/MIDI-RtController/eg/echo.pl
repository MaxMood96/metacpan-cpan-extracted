#!/usr/bin/env perl

# Monitor the MIDI messages of the given port.

use strict;
use warnings;
use MIDI::RtController;

my $in = $ARGV[0] || die "Usage: perl $0 midi-in-port";

my $rtc = MIDI::RtController->new( input => $in, output => $in );

$rtc->add_filter(
    'echo',
    all => sub {
        my ( $port, $dt, $event ) = @_;
        print "port: $port, dt: $dt, ev: ", join( ', ', @$event ), "\n"
            unless $event->[0] eq 'clock';
        return 0;
    }
);

$rtc->run;

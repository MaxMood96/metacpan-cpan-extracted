#!/usr/bin/env perl

# PERL_FUTURE_DEBUG=1 perl eg/tester.pl

use curry;
use Future::IO::Impl::IOAsync;
use MIDI::RtController ();
use MIDI::RtController::Filter::Gene ();

my $input_name  = shift || 'tempopad'; # midi controller device
my $output_name = shift || 'fluid';    # fluidsynth

my $rtc = MIDI::RtController->new(
    input  => $input_name,
    output => $output_name,
);

my $rtfg = MIDI::RtController::Filter::Gene->new(rtc => $rtc);

$rtc->add_filter('pedal', [qw(note_on note_off)], $rtfg->curry::pedal_tone);

$rtc->run;

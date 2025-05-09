#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper::Compact qw(ddc);
use Getopt::Long qw(GetOptions);
use MIDI::Util qw(setup_score midi_format play_fluidsynth);
use Music::Chord::Note ();
use Music::Dice ();

my %opt = (
    tonic     => 'C',
    scale     => 'major',
    octave    => 4,
    soundfont => $ENV{HOME} . '/Music/soundfont/FluidR3_GM.sf2',
    midi_file => "$0.mid",
);
GetOptions(\%opt,
    'tonic=s',
    'scale=s',
    'octave=i',
    'soundfont=s',
    'midi_file=s',
);

my $d = Music::Dice->new(
    scale_note => $opt{tonic},
    scale_name => $opt{scale},
);

my $score = setup_score(patch => 4);

my $cn = Music::Chord::Note->new;

my $phrase = $d->rhythmic_phrase->roll;

for (1 .. 4) {
    my @notes = map { $d->note->roll } 1 .. @$phrase;
    my @triads = map { $d->chord_triad->roll } 1 .. @$phrase;
    my @midi;
    for my $i (0 .. $#$phrase) {
        my $notes;
        my $quality = $d->chord_quality_triad_roll($notes[$i], $triads[$i]);
        push @midi, [ $phrase->[$i], "$notes[$i]$quality" ];
    }
    for my $spec (@midi) {
        print ddc $spec;
        my @tones;
        if ($spec->[1] =~ /\s+/) {
            @tones = split /\s+/, $spec->[1];
        }
        else {
            @tones = $cn->chord_with_octave($spec->[1], $opt{octave});
        }
        $score->n($spec->[0], midi_format(@tones))
    }
}

# $score->write_score($opt{midi_file});
play_fluidsynth($score, $opt{midi_file}, $opt{soundfont});

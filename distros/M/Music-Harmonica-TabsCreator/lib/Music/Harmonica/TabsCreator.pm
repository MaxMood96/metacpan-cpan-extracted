package Music::Harmonica::TabsCreator;

use 5.036;
use strict;
use warnings;
use utf8;

use English;
use Exporter qw(import);
use List::Util qw(min max none);
use Music::Harmonica::TabsCreator::NoteToToneConverter;
use Music::Harmonica::TabsCreator::TabParser;
use Music::Harmonica::TabsCreator::Warning;
use Readonly;
use Scalar::Util qw(looks_like_number);

our $VERSION = '1.02';

our @EXPORT_OK = qw(tune_to_tab get_tuning_details tune_to_tab_rendered
    transpose_tab transpose_tab_rendered list_tunings);

# Options to add:
# - print B as H (international convention), but probably not Bb which stays Bb.

Readonly my $TONES_PER_SCALE => 12;

# TODO: add a param so that the output prefers a tab starting at 1 rather than
# 1° when possible.
sub extend_chromatic_tuning ($tuning, $fix) {
  my $size = @{$tuning->{notes}};
  for my $i (0 .. $size - 1) {
    push @{$tuning->{tabs}}, sprintf('(%s)', $tuning->{tabs}[$i]);
    $tuning->{notes}[$i] =~ m/^(\w)(\d)$/ or die 'Unexpected error';
    push @{$tuning->{notes}}, "${1}#${2}";
  }
  if ($fix) {
    # Some brand use a D instead of a C (== B#) as the draw slide in, to give
    # one more note (instead of duplicating the C). It’s not really an issue if
    # the harmonica does not have it as the missing C is there anyway on the
    # harmonica (and worst case, the tab can’t be played if it requires (-12)).
    die 'Unexpected error' unless $tuning->{notes}[-1] =~ m/^B#(\d+)$/;
    $tuning->{notes}[-1] = 'D'.($1 + 1);
  }
  # We put the notes with the slides pushed-in at the beginning of the array so
  # that equivalent notes with the slide out, which comes later, are used by
  # default.
  push @{$tuning->{tabs}}, splice(@{$tuning->{tabs}}, 0, $size);
  push @{$tuning->{notes}}, splice(@{$tuning->{notes}}, 0, $size);
  @{$tuning->{bends}} = ((1) x ($size + 1), (0) x ($size));
  $tuning->{is_chromatic} = 1;
  return $tuning;
}

#<<<  let’s not run perltidy over this portion as I want to keep the arrays
# aligned for better readability.
Readonly my %ALL_TUNINGS => (
  # Written in the key of C to match the default key used in the note_to_tone
  # function.
  # Note that when we have the same note appear multiple time (like -2 and 3 in
  # Richter scale) we always use only the last appearance one when rendering a
  # tab (but other appearances are still used when reading a tab).
  richter => {
    tags => [qw(diatonic 10-holes major)],
    name => 'Richter',
    tabs => [qw(  1 -1  2 -2  3 -3  4 -4  5 -5  6 -6  7 -7  8 -8  9 -9 10 -10)],
    notes => [qw(C4 D4 E4 G4 G4 B4 C5 D5 E5 F5 G5 A5 C6 B5 E6 D6 G6 F6 C7  A6)],
    bends => [qw( 0  1  0  2  0  3  0  1  0  0  0  1  0  0  1  0  1  0  2   0)],
    key => 'C',
  },
  melody_maker => {
    tags => [qw(diatonic 10-holes major)],
    name => 'Melody Maker',
    tabs => [qw(  1 -1  2 -2  3 -3  4 -4  5  -5  6 -6  7 -7  8 -8  9  -9 10 -10)],
    notes => [qw(C4 D4 E4 G4 A4 B4 C5 D5 E5 F+5 G5 A5 C6 B5 E6 D6 G6 F+6 C7  A6)],
    bends => [qw( 0  1  0  2  0  1  0  1  0   1  0  1  0  0  1  0  0   0  2   0)],
    key => 'G',
    # TODO: Only the C, D, Eb, E, F, G, A and Bb keys exist (not the Db, F#, Ab
    # and B ones). But nothing prevents the missing ones from being generated
    # for now.
  },
  natural_minor => {
    tags => [qw(diatonic 10-holes minor)],
    name => 'Natural Minor',
    tabs => [qw(  1 -1   2 -2  3  -3  4 -4   5 -5  6 -6  7  -7   8 -8  9 -9 10 -10)],
    notes => [qw(C4 D4 Eb4 G4 G4 Bb4 C5 D5 Eb5 F5 G5 A5 C6 Bb5 Eb6 D6 G6 F6 C7  A6)],
    bends => [qw( 0  1   0  3  0   2  0  1   0  1  0  1  1   0   0  0  1  0  2   0)],
    # TODO: The real harmonica is labelled as Gm but we don’t support that
    # annotation for now.
    key => 'G',
  },
  harmonic_minor => {
    tags => [qw(diatonic 10-holes minor)],
    name => 'Harmonic Minor',
    tabs => [qw(  1 -1   2 -2  3 -3  4 -4   5 -5  6  -6  7 -7   8 -8  9 -9 10 -10)],
    notes => [qw(C4 D4 Eb4 G4 G4 B4 C5 D5 Eb5 F5 G5 Ab5 C6 B5 Eb6 D6 G6 F6 C7 Ab6)],
    bends => [qw( 0  1   0  3  0  3  0  1   0  1  0   0  0  0   0  0  1  0  3   0)],
    key => 'C',
  },
  solo_8 => extend_chromatic_tuning({
      tags => [qw(chromatic 8-holes major)],
      name => 'Solo 8 – Chrometta',
      tabs => [qw(  1 -1  2  -2 3 -3  4 -4  5 -5  6 -6  7 -7  8 -8)],
      notes => [qw(C4 D4 E4 F4 G4 A4 C5 B4 C5 D5 E5 F5 G5 A5 C6 B5)],
      key => 'C',
    },
    0
  ),
  chrometta_10 => extend_chromatic_tuning({
      tags => [qw(chromatic 10-holes major)],
      name => 'Chrometta 10',
      tabs => [qw(  3° -3° 4° -4° 1 -1  2  -2 3 -3  4 -4  5 -5  6 -6  7 -7  8 -8)],
      notes => [qw(G3  A3 C4  B3 C4 D4 E4 F4 G4 A4 C5 B4 C5 D5 E5 F5 G5 A5 C6 B5)],
      key => 'C',
    },
    0
  ),
  solo_10 => extend_chromatic_tuning({
      tags => [qw(chromatic 10-holes major)],
      name => 'Solo 10',
      tabs => [qw(  1 -1  2  -2 3 -3  4 -4  5 -5  6 -6  7 -7  8 -8  9 -9 10 -10)],
      notes => [qw(C4 D4 E4 F4 G4 A4 C5 B4 C5 D5 E5 F5 G5 A5 C6 B5 C6 D6 E6  F6)],
      key => 'C',
    },
    0
  ),
  solo_12 => extend_chromatic_tuning({
      tags => [qw(chromatic 12-holes major)],
      name => 'Solo 12',
      tabs => [qw(  1 -1  2  -2 3 -3  4 -4  5 -5  6 -6  7 -7  8 -8  9 -9 10 -10  11 -11 12 -12)],
      notes =>[qw( C4 D4 E4 F4 G4 A4 C5 B4 C5 D5 E5 F5 G5 A5 C6 B5 C6 D6 E6  F6  G6  A6 C7  B6)],
      key => 'C',
    },
    1
  ),
  solo_14 => extend_chromatic_tuning({
      tags => [qw(chromatic 14-holes major)],
      name => 'Solo 14',
      tabs => [qw(  3° -3° 4° -4° 1 -1  2  -2 3 -3  4 -4  5 -5  6 -6  7 -7  8 -8  9 -9 10 -10  11 -11 12 -12)],
      notes => [qw(G3  A3 C4  B3 C4 D4 E4 F4 G4 A4 C5 B4 C5 D5 E5 F5 G5 A5 C6 B5 C6 D6 E6  F6  G6  A6 C7  B6)],
      key => 'C',
      avoid_tones => 5,
    },
    1
  ),
  solo_16 => extend_chromatic_tuning({
      tags => [qw(chromatic 16-holes major)],
      name => 'Solo 16',
      tabs => [qw(  1° -1° 2° -2° 3° -3° 4° -4° 1 -1  2  -2 3 -3  4 -4  5 -5  6 -6  7 -7  8 -8  9 -9 10 -10  11 -11 12 -12)],
      notes => [qw(C3  D3 E3  F3 G3  A3 C4  B3 C4 D4 E4 F4 G4 A4 C5 B4 C5 D5 E5 F5 G5 A5 C6 B5 C6 D6 E6  F6  G6  A6 C7  B6)],
      key => 'C',
      avoid_tones => 12,
    },
    1
  ),
  xylophone => {
    tags => [qw(diatonic)],
    name => 'Xylophone',
    tabs => [qw(  1  2  3  4  5  6  7  8  9 10 11 12)],
    notes => [qw(C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 G5)],
    bends => [qw( 0  0  0  0  0  0  0  0  0  0  0  0)],
    key => 'C',
  },
);
#>>>

# We can’t use qw() because of the # that triggers a warning.
Readonly my @KEYS_OFFSET => split / /, q(C Db D Eb E F F# G Ab A Bb B);
Readonly my %KEYS_TO_TONE => map { $KEYS_OFFSET[$_] => $_ } 0 .. $#KEYS_OFFSET;

Readonly my $MAX_BENDS => 6;  # Probably higher than any realistic value.

sub get_preferred_key (%options) {
  my $key = $options{preferred_key} // 'C';
  my $note_converter = Music::Harmonica::TabsCreator::NoteToToneConverter->new();
  my @key_tone = eval { $note_converter->convert($key) };
  die "Invalid key: $key\n" if $@ || @key_tone != 1;
  return $key_tone[0] % $TONES_PER_SCALE;
}

sub tune_to_tab ($sheet, %options) {
  my $note_converter = Music::Harmonica::TabsCreator::NoteToToneConverter->new();
  my @tones = $note_converter->convert($sheet);
  my $tunings = generate_tunings($options{max_bends} // 0, $options{tunings} // []);
  return find_matching_tuning(\@tones, $tunings, get_preferred_key(%options));
}

sub transpose_tab ($tab, $tuning_id, $key, %options) {
  die "Unknown tuning: $tuning_id\n" unless exists $ALL_TUNINGS{$tuning_id};
  # For the input, we accept any level of bending.
  my $tuning = generate_tunings($MAX_BENDS, [$tuning_id])->{$tuning_id};
  my %tab_to_tones = map { $tuning->{tabs}[$_] => $tuning->{tones}[$_] } 0 .. $#{$tuning->{tabs}};
  my $parser = Music::Harmonica::TabsCreator::TabParser->new(\%tab_to_tones);
  my @tones = $parser->parse($tab);
  my $note_converter = Music::Harmonica::TabsCreator::NoteToToneConverter->new();
  my @key_tone = eval { $note_converter->convert($key) };
  die "Invalid key: $key\n" if $@ || @key_tone != 1;
  my $key_tone = $key_tone[0];
  @tones = map { looks_like_number($_) ? $_ + $key_tone : $_ } @tones;
  my $tunings = generate_tunings($options{max_bends} // 0, $options{tunings} // []);
  return find_matching_tuning(\@tones, $tunings, get_preferred_key(%options));
}

# Given the text representation of one note, and a bend level, generate the text
# of the bended note.
sub bend ($tab, $b) {
  return $tab if $b == 0;
  my $bend = ('"' x ($b / 2)).("'" x ($b % 2));
  if ($tab =~ m/^\((.+)\)$/) {
    return "(${1}${bend})";
  } else {
    return ${tab}.${bend};
  }
}

# We take the global %ALL_TUNINGS and generate a %tunings hash with the same
# keys but where the values only have the tab and a new matching 'tone' entries.
# But we have added the notes corresponding to the allowed bends.
sub generate_tunings ($max_bends, $tunings) {
  my %out;
  my $note_converter = Music::Harmonica::TabsCreator::NoteToToneConverter->new();
  while (my ($k, $v) = each %ALL_TUNINGS) {
    next if @{$tunings} && none { $_ eq $k } @{$tunings};
    for my $i (0 .. $#{$v->{notes}}) {
      my $base_tone = ($note_converter->convert($v->{notes}[$i]))[0];
      # We apply a correction so that we have the tones of a C-harmonica as the
      # offset we will compute in match_notes_to_tuning is assuming that the
      # tuning was given for a C-harmonica.
      $base_tone -= $KEYS_TO_TONE{$v->{key}};
      my $tab = $v->{tabs}[$i];
      for my $b (0 .. min($max_bends, $v->{bends}[$i])) {
        push @{$out{$k}{tones}}, $base_tone - $b;
        push @{$out{$k}{tabs}}, bend($tab, $b);
      }
      $out{$k}{is_chromatic} = $v->{is_chromatic};
      $out{$k}{avoid_tones} = $v->{avoid_tones} if exists $v->{avoid_tones};
    }
  }
  return \%out;
}

sub find_matching_tuning ($tones, $tunings, $preferred_key) {
  my %all_matches;
  while (my ($k, $v) = each %{$tunings}) {
    my @matches = match_notes_to_tuning($tones, $v, $preferred_key);
    for my $m (@matches) {
      push @{$all_matches{$k}{$m->[1]}}, $m->[0];
    }
  }
  return %all_matches;
}

sub tune_to_tab_rendered ($sheet, %options) {
  my %tabs = eval { tune_to_tab($sheet, %options) };
  return $@ if $@;
  return render_tabs(%tabs);
}

sub transpose_tab_rendered ($tab, $tuning, $key, %options) {
  my %tabs = eval { transpose_tab($tab, $tuning, $key, %options) };
  return $@ if $@;
  return render_tabs(%tabs);
}

sub render_tabs (%tabs) {
  if (!%tabs) {
    return 'No tabs found';
  }

  my $out;

  for my $type (sort keys %tabs) {
    my %details = get_tuning_details($type);
    $out .= sprintf "For %s %s tuning harmonicas:\n", join(' ', @{$details{tags}}), $details{name};
    for my $key (sort keys %{$tabs{$type}}) {
      $out .= "  In the key of ${key}:\n";
      for my $tab (@{$tabs{$type}{$key}}) {
        my $str_tab;
        my $was_nl = 1;
        for my $t (@{$tab}) {
          $str_tab .= ($was_nl ? '    ' : ' ').$t;
          $was_nl = $t =~ m/\v\z/;
        }
        $str_tab =~ s/\A\s+|\s+\Z//g;
        $out .= ${str_tab}."\n\n";
      }
    }
  }

  return $out;
}

sub get_tuning_details ($key) {
  return %{$ALL_TUNINGS{$key}}{qw(name tags)};
}

sub list_tunings () {
  return map { {id => $_, name => $ALL_TUNINGS{$_}{name}, tags => $ALL_TUNINGS{$_}{tags}} }
      sort keys %ALL_TUNINGS;
}

# Given all the tones (with C0 = 0) of a melody and the data of a given
# harmonica tuning, returns whether the melody can be played on this
# harmonica and, if yes, the octave shift to apply to the melody.
sub match_notes_to_tuning ($tones, $tuning, $preferred_key) {
  my $note_converter = Music::Harmonica::TabsCreator::NoteToToneConverter->new();
  my ($scale_min, $scale_max) = (min(@{$tuning->{tones}}), max(@{$tuning->{tones}}));
  my @real_tones = grep { looks_like_number($_) } @{$tones};
  die Music::Harmonica::TabsCreator::Warning->new('No melody found in input') unless @real_tones;
  my ($tones_min, $tones_max) = (min(@real_tones), max(@real_tones));
  my %scale_tones = map { $tuning->{tones}[$_] => $tuning->{tabs}[$_] } 0 .. $#{$tuning->{tones}};
  my ($o_min, $o_max) = ($scale_min - $tones_min, $scale_max - $tones_max);
  my @matches;

  # max_offset is set for Chromatic harmonicas to avoid generating the
  # same thing over and over again, transposed by a full octave.
  my $o_max_low = $o_max;
  $o_max_low = min($o_max, $o_min + $TONES_PER_SCALE - 1) if $tuning->{is_chromatic};
  # For some tunings we prefer not to generate the first few tones (typically
  # anything before middle C on a chromatic harmonica). This settings offset the
  # search pattern if possible. We note that if is_chromatic was not set, then
  # this will do nothing because $o_max == $o_max_low.
  if (exists $tuning->{avoid_tones}) {
    my $o = min($tuning->{avoid_tones}, $o_max - $o_max_low);
    $o_max_low += $o;
    $o_min += $o;
  }

  for my $o ($o_min .. $o_max_low) {  # (min($o_max, $o_min + $TONES_PER_SCALE - 1))) {
    my @tab = tab_from_tones($tones, $o, %scale_tones);
    if (@tab) {
      my $key = ($TONES_PER_SCALE - $o) % $TONES_PER_SCALE;
      my $match = [\@tab, $KEYS_OFFSET[$key]];
      if ($tuning->{is_chromatic} && $key == $preferred_key) {
        return $match;
      }
      push @matches, $match;
    }
  }
  return @matches;
}

sub tab_from_tones($tones, $offset, %scale_tones) {
  my @tab;
  for my $t (@{$tones}) {
    if (looks_like_number($t)) {
      return unless exists $scale_tones{$t + $offset};
      push @tab, $scale_tones{$t + $offset};
    } else {
      push @tab, $t;
    }
  }
  return @tab;
}

1;

# TODO: document the options of the methods.

__END__

=pod

=encoding utf8

=head1 NAME

Music::Harmonica::TabsCreator - Convert tunes into harmonica tabs

=head1 SYNOPSIS

  use Music::Harmonica::TabsCreator qw(sheet_to_tab_rendered);
  say sheet_to_tab_rendered('C D E F G A B C');

=head1 DESCRIPTION

=head2 tune_to_tab

  my %tabs = tune_to_tab($tune)

Convert a sheet music into harmonica tablatures. Sheets can be specified using
a flexible syntax like: C<C D E F>, C<C# Db>, C<Do ré mi>, C<C4 C5>,
C<< A B > C D E F G A B > C D D C < B A >> (that last example shows how you can
switch the current octave if you don’t specify octave numbers with each note).

For more details on the tune format, see the
L<GitHub README|https://github.com/mkende/harmonica_tabs_creator>.

The function returns a hash (not a hash-ref) where the keys are the identifier
of a given harmonica (you can learn more about that harmonica using the
C<get_harmonica_details()> function), and the values are hash-refs where the
keys are the key of the harmonica to use to play the tune. The values associated
to these keys are arrays of tablatures. Each tablature is itself an array of
strings, one for each note making up the tablature.

=head2 tune_to_tab_rendered

  say tune_to_tab_rendered('Kb B C D E F G A B C');

This is the same thing as C<tune_to_tab> but the output is returned in a string
ready to be displayed to a user. Also this function will not C<die> (instead a
user friendly error will be returned directly in the string).

=head2 get_harmonica_details

  my %details = get_harmonica_details($harmonica_id);

Given an ID that is one of the key of the hash returned by C<tune_to_tab()>
function this returns a hash containing two keys: C<name> and C<tags> where the
first has a human readable name for the harmonica and the second a list of
tags relevant to the harmonica.

=head1 AUTHOR

Mathias Kende <mathias@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2025 Mathias Kende

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=head1 SEE ALSO

=over

=item L<harmonica-tabs-creator>

=item L<Online version|https://harmonica-tabs-creator.com>

=back

=cut

#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'lib';
use Speak qw(speak);

# We need to capture what Speak tries to send to the TTS engine.
# Speak uses LWP::UserAgent::get request.
# We will mock the internal _fetch_mp3 function to capture the text.
# However, Speak.pm uses Speak::speak -> _split_text -> _fetch_mp3 (internal).
# Tests usually shouldn't mock internals, but here it's the most direct way
# to see what text is being processed without making network calls.

our @captured_text;

# Mock the internal function
no warnings 'redefine';
*Speak::_fetch_mp3 = sub {
  my ($ua, $text, $lang) = @_;
  push @captured_text, $text;
  return undef;    # Return undef so we don't try to save MP3s
};

sub run_speak_test {
  my ($input, $expected_parts, $name) = @_;
  @captured_text = ();
  speak ($input);

  # speak splits text into sentences/chunks.
  # We join them back with spaces to check the full logical content,
  # or just check that we got the expected transformed text.
  my $full_captured = join (' ', @captured_text);

  # Normalize spaces for comparison (collapse multiple spaces)
  $full_captured =~ s/\s+/ /g;
  $full_captured =~ s/^\s+|\s+$//g;

  is ($full_captured, $expected_parts, $name);
} ## end sub run_speak_test

plan tests => 6;

# 1. Literal escape sequences
run_speak_test (
  'Line 1\nLine 2',
  'Line 1 Line 2',
  'Literal \n should become space'
);

# 2. Literal tabs
run_speak_test (
  'Column 1\tColumn 2',
  'Column 1 Column 2',
  'Literal \t should become space'
);

# 3. Mixed literal escapes
run_speak_test ('Row 1\r\nRow 2',
  'Row 1 Row 2', 'Literal \r\n should become space');

# 4. Bell/Alarm (should be removed)
run_speak_test ('Ding\aDong', 'DingDong', 'Literal \a should be removed');

# 5. Backspace (should be space)
run_speak_test ('Back\bSpace', 'Back Space', 'Literal \b should become space');

# 6. Actual Control Characters (not literal backslashes)
# These should also be handled gracefully (usually treated as whitespace by regexes)
run_speak_test (
  "Actual\nNewline",
  'Actual Newline',
  'Actual newline char should be space'
);

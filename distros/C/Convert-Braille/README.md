# Convert-Braille
Conversions Between Braille Representations in Perl

## About This Release

  While not at the 100% point, `Convert::Braille` does a
  good bit and offers a starting point for anyone getting
  involved with Braille processing.

## Why Convert::Braille?

  Born out of my own need when working with the visually 
  impaired to translate lingo "Z is 1356" into a meaningful
  character code.  As everyone should be migrating to 
  Unicode, this package offers conversion between ASCII
  encoded Braille and the Unicode specification.

## What This Package Can Do

  Convert a string between:

    Braille-ASCII ⇔ Unicode
    Braille-ASCII ⇔ Dots
             Dots ⇔ Unicode

  Unicode here means "UTF-8" encoded text.

  8 dot Braiile in Unicode is convert into 6 dot Braille
  by simply stripping off the dots -there is probably a
  better solution that can be applied based on the context
  of dots 7 and 8. 

  `Convert::Braille::Ethiopic` is complete and requires
  `Convert::Number::Ethiopic`.  Perl 5.8 is recommended
  for this module.

## What This Package Can NOT Do

  This package can not convert between Braille-ASCII and
  English -which look a lot alike in the alphabetic range,
  but thats about it.  Only character codes are converted,
  no semantic checking is performed.

## What Next?

  I intend to work on conversion for Braille implementations:

    Convert::Braille::English   (started, need definitive info)
    Convert::Braille::Ethiopic  (done!)
    Convert::Braille::Japanese  (not started)

  Ethiopic and Japanese both use multi char Braille sequences
  to represent their systems of writing which presents some
  interesting challenges.

  ...the code will be commented, etc...

## More Info

  Traditional 6 dot Braille provides 63 printable sequences.
  Few of the Braille fonts I could find on the Internet, which
  are supposed to use Braille-ASCII, have the full repertoire
  or are even compatible with one another.  Very confusing...

  This module was developed with Braille-ASCII information
  presented here:
  
  http://www.uronramp.net/~lizgray/ascii.html
  http://www.cc.utah.edu/~nahaj/ada/braille/braille-ascii.ads.html

  It is also inspired by Convert-Morse-0.03. 

  See examples/demo.pl.

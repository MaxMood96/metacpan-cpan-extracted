# Convert-CEGH
Coptic/Ethiopic/Greek/Hebrew Gematria &amp; Transliteration with Perl

Why CEGH?
--------

The Coptic, Ethiopic, Greek and Hebrew cultures share a bit of common
vocabulary and writing practices as an outgrowth of that Judeo-Christian
thing they've got going over there.

Vocabulary, numerology, and numeral systems devised from their respective
alphabets are a few shared practices.  The CEGH package provides some
limited capability to convert between systems for investigative and
analytic uses.


Limitations:
-----------

Ancient phonetics and not modern are used for transliteration.  The reason
here is that the package is intended as tool for analyzing ancient texts.
"Ethiopic" in the package really means "Ge'ez" as it is "Ancient Ethiopic".

Ethiopic script has a 2nd type of Gematria, likely more widely used,
that uses the better known Halehame order.  This package will later be
updated to support this form of Gematria.

Unicode treats Coptic and Greek as equivalent for the most part, Coptic
simply has a number of additional letters not used in Greek.  This status
is subject to change after Unicode 4.0.

The transliteration system applies the Metaphone rule of stripping out
all but the first vowel in a word.  All vowels are mapped to "a".  This
is applied simply to make comparisons a little easier as vowels are the
first thing to when words cross language boundaries.


Why I Wrote this Package:
------------------------

Its always bugged me that Shin (U+05E9) and Sewt (U+1220) were not
the same characters.  They equate visually of course but according
to any phonetic tables that you find Sat (U+1330) and Sewt are
equivalents.  Numeral system tables support this equivalents where
both letters have the value of 300 while Sewt is 60.  Some Abugida
tables (not Abegede) do have Sat and Sewt exchanged, which is possibly
telling, or just confused.

Plausibly, at some point long ago someone screwed up a table and that
error has propagated forward into following work up to the present
day.  It happens.  So, I hoped through an analysis via transcription
and Gematria the truth might be brought out.

This is the extent of my interest in the package.  Given my limited
use of the package some bugs would likely go undetected for quite a
while.  If informed of any errors I will gladly update the package
accordingly.


Disclaimer:
----------

...and just for the record;  "No" I do not believe in, practice, 
govern my life, nor make any decisions based on Gematria.  Likewise
I do not live in fear of the number 13, read my horoscope, palm,
tea leaves, avoid stepping on cracks, etc.  No need to concern
myself with all that nonsense when I've got my lucky rabbit's foot
to protect me :-)

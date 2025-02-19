# Regexp-Cherokee
Regular Expressions Support for Cherokee Script.

## Overview
The `Regexp::Cherokee` package provides POSIX style character class
support for Cherokee script and languages.  The package should be
considered experimental at this time.  RE symbology and character
class data comes from the Grand Unified Syllabary project:

  [http://syllabary.sourceforge.net/Cherokee/](http://syllabary.sourceforge.net/Cherokee/)

In essence, what the package does is overload Perl's RE mechanism
to filter the convenient POSIX style classes and convert them into
big ungainly expressions that you would never care to type.

See the files in examples/ to get the gist of it.

The package is only known to work with Perl 5.8.0, it won't win
any points for efficiency, does not do error checking, etc, it
should be considered experimental at this time but does work
under normal conditions (ie you're not trying to break it).

This package is developed as a follow up to the extremely useful
`Regexp::Ethiopic` package and is a step in the direction towards
(possibly) a `Regexp::Syllabary` package.  I do not work in Cherokee
myself and some syllabary idioms that make sense for Ethiopic, and
Ethiopic REs, may not transfer to Cherokee.  It is hoped this
package will help bring out such descrepancies.

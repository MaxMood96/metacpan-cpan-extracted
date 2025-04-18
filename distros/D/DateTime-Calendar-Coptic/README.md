# DateTime-Calendar-Coptic
DateTime Module for the Coptic Calendar System with Perl

## About This Release

This is an development release of `DateTime::Calendar::Coptic` it should
be considered experimental at this time.  Be warned that this package
provides a slightly modified `DateTime::Language` from DateTime-0.09.
This module was renamed `DateTime::Languages` in v0.04 of this package
to avoid conflicts with the authoritative version. This will likely
be refactored later to apply the primary version.

The package will be a work in progress for quite a while.  Expect
internals will to change dramatically as the package matures.  The
intention of `DateTime::Calendar::Coptic` and `DateTime::Calendar::Ethiopic`
is to share the same to/from Gregorian conversion class.  It will
take a bit of experimentation to get the packages to play nice together.

Coptic holidays and feasts will be added in future versions.  Verification
of day names is under way.  Much data comes from:

  [http://www.copticchurch.net/easter.html](http://www.copticchurch.net/easter.html)


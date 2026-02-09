# NAME

Hash::Util::Merge - utility functions for merging hashes

# SYNOPSIS

```perl
use Hash::Util::Merge qw/ mergemap /;

my %a = ( x => 1, y => 2 );
my %b = ( x => 3, y => 7 );

my $c = mergemap { $a + $b } \%a, \%b;

# %c = ( x => 4, y => 9 );
```

# DESCRIPTION

This module provides some syntactic sugar for merging simple
hashes with a function.

# RECENT CHANGES

Changes for version v0.3.0 (2026-02-07)

- Enhancements
    - Any number of hashes can be merged.
    - Duplicate keys are not reprocessed.
- Bugs
    - Clean namespace.
- Documentation
    - Improved the discussion of the merge function.
    - Updated copyright year.
    - README.md is buillt using Dist::Zilla UsefulReadme plugin.
    - Replaced INSTALL with section in README.md.
    - Added a LICENSE and SECURITY.md to the distribution.
    - Reorganised POD with a SUPPORT section.
- Tests
    - Changed the module used for MANIFEST testing.
    - Moved author/release tests into the xt directory.
    - Added more author tests.
    - Switched to Test2::V0.
- Toolchain
    - Updated the Dist::Zilla configuration.

See the `Changes` file for more details.

# REQUIREMENTS

This module lists the following modules as runtime dependencies:

- [Exporter](https://metacpan.org/pod/Exporter) version 5.57 or later
- [List::Util](https://metacpan.org/pod/List%3A%3AUtil) version 1.45 or later
- [Sub::Util](https://metacpan.org/pod/Sub%3A%3AUtil) version 1.45 or later
- [perl](https://metacpan.org/pod/perl) version v5.14.0 or later
- [strict](https://metacpan.org/pod/strict)
- [warnings](https://metacpan.org/pod/warnings)

See the `cpanfile` file for the full list of prerequisites.

# INSTALLATION

The latest version of this module (along with any dependencies) can be installed from [CPAN](https://www.cpan.org) with the `cpan` tool that is included with Perl:

```
cpan Hash::Util::Merge
```

You can also extract the distribution archive and install this module (along with any dependencies):

```
cpan .
```

You can also install this module manually using the following commands:

```
perl Makefile.PL
make
make test
make install
```

If you are working with the source repository, then it may not have a `Makefile.PL` file.  But you can use the [Dist::Zilla](https://dzil.org/) tool in anger to build and install this module:

```
dzil build
dzil test
dzil install --install-command="cpan ."
```

For more information, see [How to install CPAN modules](https://www.cpan.org/modules/INSTALL.html).

# SUPPORT

Only the latest version of this module will be supported.

This module requires Perl v5.14 or later.

Future releases may only support Perl versions released in the last ten years.

## Reporting Bugs and Submitting Feature Requests

Please report any bugs or feature requests on the bugtracker website
[https://github.com/robrwo/Hash-Util-Merge/issues](https://github.com/robrwo/Hash-Util-Merge/issues)

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

If the bug you are reporting has security implications which make it inappropriate to send to a public issue tracker,
then see `SECURITY.md` for instructions how to report security vulnerabilities.

# SOURCE

The development version is on github at [https://github.com/robrwo/Hash-Util-Merge](https://github.com/robrwo/Hash-Util-Merge)
and may be cloned from [git://github.com/robrwo/Hash-Util-Merge.git](git://github.com/robrwo/Hash-Util-Merge.git)

# AUTHOR

Robert Rothenberg <rrwo@cpan.org>

This module uses code from [List::Util::PP](https://metacpan.org/pod/List%3A%3AUtil%3A%3APP).

This module was developed from work for Science Photo Library
[https://www.sciencephoto.com](https://www.sciencephoto.com).

# CONTRIBUTOR

Mohammad S Anwar <mohammad.anwar@yahoo.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2020-2026 by Robert Rothenberg.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```

# SEE ALSO

[Hash::Merge](https://metacpan.org/pod/Hash%3A%3AMerge)

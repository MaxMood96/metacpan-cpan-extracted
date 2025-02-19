# PDL-Stats

|  Build status |
| ------------- |
| ![Build Status](https://github.com/PDLPorters/PDL-Stats/workflows/perl/badge.svg?branch=master) |

[![Coverage Status](https://coveralls.io/repos/PDLPorters/PDL-Stats/badge.svg?branch=master&service=github)](https://coveralls.io/github/PDLPorters/PDL-Stats?branch=master)
[![CPAN version](https://badge.fury.io/pl/PDL-Stats.svg)](https://metacpan.org/pod/PDL::Stats)


This is a collection of statistics modules in Perl Data Language, with a quick-start guide for non-PDL people.

They make perldl--the simple shell for PDL--work like a teenie weenie R, but with PDL threading--"the fast (and automagic) vectorised iteration of 'elementary operations' over arbitrary slices of multidimensional data"--on procedures including t-test, ordinary least squares regression, and kmeans.

Of course, they also work in perl scripts.

## DEPENDENCIES

- PDL

  Perl Data Language. Preferably installed with a Fortran compiler. A
  few methods (logistic regression and all plotting methods) will only
  work with a Fortran compiler and some methods (ordinary least squares
  regression and pca) work much faster with a Fortran compiler.

  The required PDL version is 2.057.

- PDL::GSL (Optional)

  PDL interface to GNU Scientific Library. This provides PDL::Stats::Distr
  and PDL::GSL::CDF, the latter of which provides p-values for
  PDL::Stats::GLM. GSL is otherwise NOT required for the core PDL::Stats
  modules to work, ie Basic, Kmeans, and GLM.

- PGPLOT (Optional)

  PDL-Stats currently uses PGPLOT for plotting. There are
  three pgplot/PGPLOT modules, which cause much confusion upon
  installation. First there is the pgplot Fortran library. Then there is
  the perl PGPLOT module, which is the perl interface to pgplot. Finally
  there is PDL::Graphics::PGPLOT, which depends on pgplot and PGPLOT,
  that PDL-Stats uses for plotting.

## INSTALLATION

### \*nix

For standard perl module installation in \*nix environment form source, to install all included modules, extract the files from the archive by entering this at a shell,

    tar xvf PDL-Stats-xxx.tar.gz

then change to the PDL-Stats directory,

    cd PDL-Stats-xxx

and run the following commands:

    perl Makefile.PL
    make
    make test
    sudo make install

If you don't have permission to run sudo, you can specify an alternative path,

    perl Makefile.PL PREFIX=/home/user/my_perl_lib
    make
    make test
    make install

then add `/home/user/my_perl_lib` to your PERL5LIB environment variable.

If you have trouble installing PDL, you can look for help at the PDL wiki or PDL mailing list.

### Windows

Thanks to Sisyphus, Windows users can download and install the ppm version of PDL-Stats and all dependencies using the PPM utility included in ActiveState perl or Strawberry perl. You can also get the PPM utility from CPAN.

    ppm install http://www.sisyphusion.tk/ppm/PGPLOT.ppd
    ppm install http://www.sisyphusion.tk/ppm/PDL.ppd
    ppm install http://www.sisyphusion.tk/ppm/PDL-Stats.ppd


## SUPPORT AND DOCUMENTATION

After installing, you can find documentation for the modules with the
perldoc command.

    perldoc PDL::Stats
    perldoc PDL::Stats::Basic

etc.

You can also look for information at:

    Home
      https://github.com/PDLPorters/PDL-Stats

    Search CPAN
      https://metacpan.org/dist/PDL-Stats

    Mailing list (low traffic, open a GitHub issue instead)
      https://lists.sourceforge.net/lists/listinfo/pdl-stats-help

If you notice a bug or have a request, please submit a report at

[https://github.com/PDLPorters/PDL-Stats/issues](https://github.com/PDLPorters/PDL-Stats/issues)

If you would like to help develop or maintain the package, please email me at the address below.

## COPYRIGHT AND LICENCE

Copyright (C) 2009-2012 Maggie J. Xiong  <maggiexyz users.sourceforge.net>

All rights reserved. There is no warranty. You are allowed to redistribute this software / documentation as described in the file COPYING in the PDL distribution.

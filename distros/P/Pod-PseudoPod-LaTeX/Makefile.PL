# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.008006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "convert Pod::PseudoPod documents into LaTeX",
  "AUTHOR" => "chromatic",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Pod-PseudoPod-LaTeX",
  "EXE_FILES" => [
    "bin/ppod2latex"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008006",
  "NAME" => "Pod::PseudoPod::LaTeX",
  "PREREQ_PM" => {
    "File::Basename" => 0,
    "File::Path" => 0,
    "File::Spec::Functions" => 0,
    "Getopt::Long" => 0,
    "Pod::PseudoPod" => "0.16",
    "Pod::Usage" => 0,
    "base" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "IO::String" => 0,
    "Test::More" => "0.60"
  },
  "VERSION" => "1.20190729",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "File::Basename" => 0,
  "File::Path" => 0,
  "File::Spec::Functions" => 0,
  "Getopt::Long" => 0,
  "IO::String" => 0,
  "Pod::PseudoPod" => "0.16",
  "Pod::Usage" => 0,
  "Test::More" => "0.60",
  "base" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.014.
use strict;
use warnings;

use 5.014000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Just Another Serialized Object Notation library.",
  "AUTHOR" => "Bob Kleemann <bobk\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Jasonify",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.014000",
  "NAME" => "Jasonify",
  "PREREQ_PM" => {
    "Carp" => "1.25",
    "Datify" => "0.20.64",
    "LooksLike" => "0.20.60",
    "Scalar::Util" => 0,
    "String::Tools" => 0,
    "overload" => 0,
    "parent" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Carp" => "1.25",
    "Test2::V0" => 0
  },
  "VERSION" => "v0.20.064",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => "1.25",
  "Datify" => "0.20.64",
  "LooksLike" => "0.20.60",
  "Scalar::Util" => 0,
  "String::Tools" => 0,
  "Test2::V0" => 0,
  "overload" => 0,
  "parent" => 0,
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

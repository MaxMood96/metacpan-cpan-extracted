# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.012;

use ExtUtils::MakeMaker 6.78;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Compare simple hierarchical data",
  "AUTHOR" => "Graham Barr",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.78"
  },
  "DISTNAME" => "Data-Difference",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.012",
  "NAME" => "Data::Difference",
  "PREREQ_PM" => {
    "Exporter" => 0,
    "base" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::Differences" => 0,
    "Test::More" => "0.96"
  },
  "VERSION" => "0.113001",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Test::Differences" => 0,
  "Test::More" => "0.96",
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

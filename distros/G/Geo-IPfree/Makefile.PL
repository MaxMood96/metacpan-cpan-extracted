# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Geo::IPfree - Look up the country of an IPv4 address",
  "AUTHOR" => "Graciliano M. P. <gm\@virtuasites.com.br>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Geo-IPfree",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Geo::IPfree",
  "PREREQ_PM" => {
    "Carp" => 0,
    "ExtUtils::MakeMaker" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "Test2::Bundle::Extended" => 0,
    "Test2::Plugin::NoWarnings" => 0,
    "Test2::Tools::Explain" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.160000",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "Test2::Bundle::Extended" => 0,
  "Test2::Plugin::NoWarnings" => 0,
  "Test2::Tools::Explain" => 0,
  "Test::More" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

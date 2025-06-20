# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.020000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "module for working icon text",
  "AUTHOR" => "L\x{f6}wenfelsen UG (haftungsbeschr\x{e4}nkt) <support\@loewenfelsen.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Data-IconText",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.020000",
  "NAME" => "Data::IconText",
  "PREREQ_PM" => {
    "Carp" => "1.35",
    "Data::Identifier" => "0.12.0",
    "Encode" => "3.19",
    "File::Spec" => "3.84",
    "Scalar::Util" => "1.62"
  },
  "TEST_REQUIRES" => {
    "Test::Exception" => "0.30",
    "Test::More" => "1.3",
    "Test::Warn" => "0.30"
  },
  "VERSION" => "v0.03",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => "1.35",
  "Data::Identifier" => "0.12.0",
  "Encode" => "3.19",
  "File::Spec" => "3.84",
  "Scalar::Util" => "1.62",
  "Test::Exception" => "0.30",
  "Test::More" => "1.3",
  "Test::Warn" => "0.30"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

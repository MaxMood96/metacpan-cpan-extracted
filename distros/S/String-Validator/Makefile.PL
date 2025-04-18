# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.027.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A Collection of Routines for validating and transforming strings",
  "AUTHOR" => "John Karr <brainbuz\@brainbuz.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "String-Validator",
  "LICENSE" => "gpl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "String::Validator",
  "PREREQ_PM" => {
    "String::Validator::Common" => "2.04",
    "String::Validator::Email" => "2.00",
    "String::Validator::Language" => "2.04",
    "String::Validator::Password" => "2.01",
    "String::Validator::Phone::NANP" => "2.04"
  },
  "VERSION" => "2.04",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "String::Validator::Common" => "2.04",
  "String::Validator::Email" => "2.00",
  "String::Validator::Language" => "2.04",
  "String::Validator::Password" => "2.01",
  "String::Validator::Phone::NANP" => "2.04"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

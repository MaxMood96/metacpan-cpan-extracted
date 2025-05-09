# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.008.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Digest datatypes for Moose",
  "AUTHOR" => "Michael Langner",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "MooseX-Types-Digest",
  "LICENSE" => "perl",
  "NAME" => "MooseX::Types::Digest",
  "PREREQ_PM" => {
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::Types" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Moose" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.01",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Moose" => 0,
  "Moose::Util::TypeConstraints" => 0,
  "MooseX::Types" => 0,
  "Test::More" => 0,
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

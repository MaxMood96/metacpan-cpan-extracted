# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.014000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Log to TAP output",
  "AUTHOR" => "Robert Rothenberg <rrwo\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Log-Dispatch-TAP",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.014000",
  "NAME" => "Log::Dispatch::TAP",
  "PREREQ_PM" => {
    "Log::Dispatch::Output" => 0,
    "Params::ValidationCompiler" => 0,
    "Test2::API" => 0,
    "Types::Standard" => 0,
    "namespace::autoclean" => 0,
    "parent" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "Log::Dispatch" => 0,
    "Module::Metadata" => 0,
    "Test::More" => 0,
    "strict" => 0
  },
  "VERSION" => "v0.2.2",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "File::Spec" => 0,
  "Log::Dispatch" => 0,
  "Log::Dispatch::Output" => 0,
  "Module::Metadata" => 0,
  "Params::ValidationCompiler" => 0,
  "Test2::API" => 0,
  "Test::More" => 0,
  "Types::Standard" => 0,
  "namespace::autoclean" => 0,
  "parent" => 0,
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

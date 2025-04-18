# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.032.
use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Simple adapter for logging to redis",
  "AUTHOR" => "Michael Langner <mila\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Log-Any-Adapter-Redis",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "Log::Any::Adapter::Redis",
  "PREREQ_PM" => {
    "Log::Any" => "1.01",
    "Log::Any::Adapter::Base" => 0,
    "Log::Any::Adapter::Util" => 0,
    "RedisDB" => 0,
    "Sys::Hostname" => 0,
    "base" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Log::Any" => "1.01",
    "Log::Any::Adapter" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.000",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "ExtUtils::MakeMaker" => 0,
  "Log::Any" => "1.01",
  "Log::Any::Adapter" => 0,
  "Log::Any::Adapter::Base" => 0,
  "Log::Any::Adapter::Util" => 0,
  "RedisDB" => 0,
  "Sys::Hostname" => 0,
  "Test::More" => 0,
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

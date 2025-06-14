# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Perl API client for FreePublicAPI.com's API for for listing APIs.",
  "AUTHOR" => "oodler <oodler\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Acme-Free-Public-APIs",
  "EXE_FILES" => [
    "bin/freeapi"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Acme::Free::Public::APIs",
  "PREREQ_PM" => {
    "Dispatch::Fu" => "1.06",
    "HTTP::Tiny" => 0,
    "JSON" => 0,
    "Util::H2O::More" => "0.4.2"
  },
  "TEST_REQUIRES" => {
    "Dispatch::Fu" => "1.06",
    "HTTP::Tiny" => 0,
    "JSON" => 0,
    "Test::More" => 0,
    "Util::H2O::More" => "0.4.2"
  },
  "VERSION" => "0.9.10",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Dispatch::Fu" => "1.06",
  "HTTP::Tiny" => 0,
  "JSON" => 0,
  "Test::More" => 0,
  "Util::H2O::More" => "0.4.2"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

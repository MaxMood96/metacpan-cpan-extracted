# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.011.
use strict;
use warnings;

use 5.010000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "UserAgent based on libcurl",
  "AUTHOR" => "Julian Knocke, Othello Maurer",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "WWW-Curl-UserAgent",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010000",
  "NAME" => "WWW::Curl::UserAgent",
  "PREREQ_PM" => {
    "HTTP::Request" => 0,
    "HTTP::Response" => 0,
    "IO::Select" => 0,
    "Moose" => 0,
    "Time::HiRes" => 0,
    "WWW::Curl::Easy" => 0,
    "WWW::Curl::Multi" => 0,
    "bytes" => 0
  },
  "TEST_REQUIRES" => {
    "FindBin" => 0,
    "Sub::Override" => 0,
    "Test::MockObject" => 0,
    "Test::More" => 0,
    "lib" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.9.8",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "FindBin" => 0,
  "HTTP::Request" => 0,
  "HTTP::Response" => 0,
  "IO::Select" => 0,
  "Moose" => 0,
  "Sub::Override" => 0,
  "Test::MockObject" => 0,
  "Test::More" => 0,
  "Time::HiRes" => 0,
  "WWW::Curl::Easy" => 0,
  "WWW::Curl::Multi" => 0,
  "bytes" => 0,
  "lib" => 0,
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

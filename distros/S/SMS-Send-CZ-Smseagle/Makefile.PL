# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.015.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "SMS::Send driver for SMSEagle - Czech Republic ",
  "AUTHOR" => "Radek \x{160}iman <rbit\@rbit.cz>",
  "BUILD_REQUIRES" => {
    "Module::Build" => "0.28"
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.28"
  },
  "DISTNAME" => "SMS-Send-CZ-Smseagle",
  "LICENSE" => "perl",
  "NAME" => "SMS::Send::CZ::Smseagle",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Data::Dumper" => 0,
    "DateTime" => 0,
    "LWP::UserAgent" => 0,
    "Log::LogLite" => 0,
    "SMS::Send::Driver" => 0,
    "Text::Unidecode" => 0,
    "URI::Escape" => 0,
    "XML::Simple" => 0,
    "base" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "SMS::Send" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.001",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Dumper" => 0,
  "DateTime" => 0,
  "LWP::UserAgent" => 0,
  "Log::LogLite" => 0,
  "Module::Build" => "0.28",
  "SMS::Send" => 0,
  "SMS::Send::Driver" => 0,
  "Test::More" => 0,
  "Text::Unidecode" => 0,
  "URI::Escape" => 0,
  "XML::Simple" => 0,
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

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A simple interface to ArangoDB REST API",
  "AUTHOR" => "Alberto Sim\x{f5}es <ambs\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Arango-Tango",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Arango::Tango",
  "PREREQ_PM" => {
    "Clone" => 0,
    "Data::Dumper" => 0,
    "HTTP::Tiny" => 0,
    "JSON" => 0,
    "JSON::Schema::Fit" => "0.07",
    "MIME::Base64" => "3.11",
    "Sub::Install" => 0,
    "Sub::Name" => 0,
    "URI::Encode" => 0,
    "base" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test2::Tools::Exception" => 0,
    "Test2::V0" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.019",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Clone" => 0,
  "Data::Dumper" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "HTTP::Tiny" => 0,
  "JSON" => 0,
  "JSON::Schema::Fit" => "0.07",
  "MIME::Base64" => "3.11",
  "Sub::Install" => 0,
  "Sub::Name" => 0,
  "Test2::Tools::Exception" => 0,
  "Test2::V0" => 0,
  "Test::More" => 0,
  "URI::Encode" => 0,
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

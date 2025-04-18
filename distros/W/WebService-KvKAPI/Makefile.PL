# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.031.
use strict;
use warnings;

use 5.026000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Query the Dutch Chamber of Commerence (KvK) API",
  "AUTHOR" => "Wesley Schwengle <waterkip\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "WebService-KvKAPI",
  "EXE_FILES" => [
    "bin/query-kvk.pl"
  ],
  "LICENSE" => "open_source",
  "MIN_PERL_VERSION" => "5.026000",
  "NAME" => "WebService::KvKAPI",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Getopt::Long" => 0,
    "Object::Pad" => "0.66",
    "OpenAPI::Client" => "1.03",
    "Pod::Usage" => 0,
    "Sub::HandlesVia::Declare" => 0,
    "Try::Tiny" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Sub::Override" => 0,
    "Test::Deep" => 0,
    "Test::Exception" => 0,
    "Test::Mock::One" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.106",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "File::Spec" => 0,
  "Getopt::Long" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Object::Pad" => "0.66",
  "OpenAPI::Client" => "1.03",
  "Pod::Usage" => 0,
  "Sub::HandlesVia::Declare" => 0,
  "Sub::Override" => 0,
  "Test::Deep" => 0,
  "Test::Exception" => 0,
  "Test::Mock::One" => 0,
  "Test::More" => 0,
  "Try::Tiny" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

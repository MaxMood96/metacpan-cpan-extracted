# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.033.
use strict;
use warnings;

use 5.012001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Interact with the Opsview Rest API interface",
  "AUTHOR" => "Duncan Ferguson <duncan_j_ferguson\@yahoo.co.uk>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Opsview-RestAPI",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.012001",
  "NAME" => "Opsview::RestAPI",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Data::Dump" => 0,
    "JSON" => 0,
    "REST::Client" => 0,
    "URI::Encode::XS" => 0,
    "overload" => 0,
    "strict" => 0,
    "version" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Basename" => 0,
    "File::Temp" => 0,
    "FindBin" => 0,
    "POSIX" => 0,
    "Storable" => 0,
    "Test::Deep" => 0,
    "Test::More" => 0,
    "Test::Trap" => 0,
    "lib" => 0
  },
  "VERSION" => "1.251900",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Dump" => 0,
  "File::Basename" => 0,
  "File::Temp" => 0,
  "FindBin" => 0,
  "JSON" => 0,
  "POSIX" => 0,
  "REST::Client" => 0,
  "Storable" => 0,
  "Test::Deep" => 0,
  "Test::More" => 0,
  "Test::Trap" => 0,
  "URI::Encode::XS" => 0,
  "lib" => 0,
  "overload" => 0,
  "strict" => 0,
  "version" => 0,
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

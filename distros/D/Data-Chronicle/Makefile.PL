# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.014;

use ExtUtils::MakeMaker 7.64;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Chronicle storage system",
  "AUTHOR" => "DERIV <DERIV\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "7.64"
  },
  "DISTNAME" => "Data-Chronicle",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.014",
  "NAME" => "Data::Chronicle",
  "PREREQ_PM" => {
    "DBD::Pg" => 0,
    "DBIx::Connector" => 0,
    "Date::Utility" => 0,
    "JSON::MaybeUTF8" => 0,
    "Moose" => 0,
    "Test::Mock::Redis" => 0,
    "Test::MockModule" => 0,
    "Test::PostgreSQL" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "RedisDB" => 0,
    "Test::CheckDeps" => "0.010",
    "Test::Exception" => 0,
    "Test::MockModule" => 0,
    "Test::More" => "0.94",
    "Test::NoWarnings" => 0,
    "utf8" => 0
  },
  "VERSION" => "0.21",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "DBD::Pg" => 0,
  "DBIx::Connector" => 0,
  "Date::Utility" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON::MaybeUTF8" => 0,
  "Moose" => 0,
  "RedisDB" => 0,
  "Test::CheckDeps" => "0.010",
  "Test::Exception" => 0,
  "Test::Mock::Redis" => 0,
  "Test::MockModule" => 0,
  "Test::More" => "0.94",
  "Test::NoWarnings" => 0,
  "Test::PostgreSQL" => 0,
  "parent" => 0,
  "strict" => 0,
  "utf8" => 0,
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

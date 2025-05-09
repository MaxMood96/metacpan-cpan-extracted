# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.012000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Shorten URIs so that you don't have to rely on external services",
  "AUTHOR" => "George S. Baugh <george\@troglodyne.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "URI-Shortener",
  "LICENSE" => "mit",
  "MIN_PERL_VERSION" => "5.012000",
  "NAME" => "URI::Shortener",
  "PREREQ_PM" => {
    "Capture::Tiny" => 0,
    "Carp::Always" => 0,
    "Crypt::PRNG" => 0,
    "DBD::Pg" => 0,
    "DBD::SQLite" => 0,
    "DBD::mysql" => 0,
    "DBI" => 0,
    "File::Touch" => 0,
    "List::Util" => "1.33",
    "POSIX" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "FindBin::libs" => 0,
    "Test::Fatal" => 0,
    "Test::More" => 0
  },
  "VERSION" => "1.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Capture::Tiny" => 0,
  "Carp::Always" => 0,
  "Crypt::PRNG" => 0,
  "DBD::Pg" => 0,
  "DBD::SQLite" => 0,
  "DBD::mysql" => 0,
  "DBI" => 0,
  "File::Touch" => 0,
  "FindBin::libs" => 0,
  "List::Util" => "1.33",
  "POSIX" => 0,
  "Test::Fatal" => 0,
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

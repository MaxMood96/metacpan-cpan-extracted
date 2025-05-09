# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.020.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A Glimpse at an Enlightened Perl: Database Development",
  "AUTHOR" => "Chris Prather <chris\@prather.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Task-Kensho-DBDev",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Task::Kensho::DBDev",
  "PREREQ_PM" => {
    "DBD::SQLite" => 0,
    "DBI" => 0,
    "DBIx::Class" => 0,
    "DBIx::Class::Schema::Loader" => 0,
    "SQL::Translator" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.41",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "DBD::SQLite" => 0,
  "DBI" => 0,
  "DBIx::Class" => 0,
  "DBIx::Class::Schema::Loader" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "SQL::Translator" => 0,
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

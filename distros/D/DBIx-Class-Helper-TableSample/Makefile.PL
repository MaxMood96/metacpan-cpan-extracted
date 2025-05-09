# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.014000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Add support for tablesample clauses",
  "AUTHOR" => "Robert Rothenberg <rrwo\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "DBIx-Class-Helper-TableSample",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.014000",
  "NAME" => "DBIx::Class::Helper::TableSample",
  "PREREQ_PM" => {
    "DBIx::Class" => 0,
    "Ref::Util" => 0,
    "namespace::clean" => 0
  },
  "TEST_REQUIRES" => {
    "Class::Load" => 0,
    "DBD::SQLite" => 0,
    "DBIx::Class::Core" => 0,
    "DBIx::Class::ResultSet" => 0,
    "DBIx::Class::Schema" => 0,
    "File::Spec" => 0,
    "Module::Metadata" => 0,
    "SQL::Abstract" => "1.83",
    "SQL::Abstract::Test" => 0,
    "SQL::Translator" => "0.11018",
    "Test::More" => 0,
    "Test::Roo" => 0,
    "Test::Roo::Role" => 0,
    "base" => 0
  },
  "VERSION" => "v0.7.0",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Class::Load" => 0,
  "DBD::SQLite" => 0,
  "DBIx::Class" => 0,
  "DBIx::Class::Core" => 0,
  "DBIx::Class::ResultSet" => 0,
  "DBIx::Class::Schema" => 0,
  "File::Spec" => 0,
  "Module::Metadata" => 0,
  "Ref::Util" => 0,
  "SQL::Abstract" => "1.83",
  "SQL::Abstract::Test" => 0,
  "SQL::Translator" => "0.11018",
  "Test::More" => 0,
  "Test::Roo" => 0,
  "Test::Roo::Role" => 0,
  "base" => 0,
  "namespace::clean" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

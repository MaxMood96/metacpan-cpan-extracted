# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Auto-create Time::Piece objects from integer (number of seconds since epoch) columns",
  "AUTHOR" => "Renee Baecker <reneeb\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "DBIx-Class-InflateColumn-TimePiece",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "DBIx::Class::InflateColumn::TimePiece",
  "PREREQ_PM" => {
    "DBIx::Class" => 0,
    "Time::Piece" => 0,
    "parent" => 0
  },
  "TEST_REQUIRES" => {
    "DBD::SQLite" => 0,
    "DBI" => 0,
    "File::Basename" => 0,
    "SQL::Translator" => 0,
    "Scalar::Util" => 0
  },
  "VERSION" => "0.03",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "DBD::SQLite" => 0,
  "DBI" => 0,
  "DBIx::Class" => 0,
  "File::Basename" => 0,
  "SQL::Translator" => 0,
  "Scalar::Util" => 0,
  "Time::Piece" => 0,
  "parent" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.010.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "tersify DBIx::Class objects",
  "AUTHOR" => "Sam Kington <skington\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Data-Tersify-Plugin-DBIx-Class",
  "LICENSE" => "perl",
  "NAME" => "Data::Tersify::Plugin::DBIx::Class",
  "PREREQ_PM" => {
    "DBIx::Class" => 0,
    "Data::Tersify" => "1.003",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "DBIx::Class" => 0,
    "Data::Dumper" => 0,
    "Test::More" => 0,
    "Test::Pod" => 0,
    "Test::Pod::Coverage" => "1.08"
  },
  "VERSION" => "1.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "DBIx::Class" => 0,
  "Data::Dumper" => 0,
  "Data::Tersify" => "1.003",
  "Test::More" => 0,
  "Test::Pod" => 0,
  "Test::Pod::Coverage" => "1.08",
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

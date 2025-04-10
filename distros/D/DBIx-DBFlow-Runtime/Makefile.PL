# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Runtime utilities for DBIx::DBFlow",
  "AUTHOR" => "Jose Luis Martinez <pplusdomain\@gmail.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "DBIx-DBFlow-Runtime",
  "EXE_FILES" => [
    "bin/dbflow_upgrade_schema"
  ],
  "LICENSE" => "apache",
  "NAME" => "DBIx::DBFlow::Runtime",
  "PREREQ_PM" => {
    "DBIx::Class::DeploymentHandler" => 0,
    "MooseX::Getopt" => 0
  },
  "VERSION" => "0.03",
  "test" => {
    "TESTS" => ""
  }
);


my %FallbackPrereqs = (
  "DBIx::Class::DeploymentHandler" => 0,
  "MooseX::Getopt" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

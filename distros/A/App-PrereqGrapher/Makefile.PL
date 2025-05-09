# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.037.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "generate dependency graph using Perl::PrereqScanner",
  "AUTHOR" => "Neil Bowers <neil\@bowers.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-PrereqGrapher",
  "EXE_FILES" => [
    "bin/prereq-grapher"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "App::PrereqGrapher",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Getopt::Long" => 0,
    "Graph::Easy" => 0,
    "Graph::Easy::As_svg" => 0,
    "Module::CoreList" => 0,
    "Module::Path" => 0,
    "Moo" => 0,
    "Perl::PrereqScanner" => 0,
    "Pod::Usage" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Devel::FindPerl" => 0,
    "File::Compare" => 0,
    "File::Spec::Functions" => 0,
    "FindBin" => "0.05",
    "Test::More" => "0.88"
  },
  "VERSION" => "0.14",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Devel::FindPerl" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Compare" => 0,
  "File::Spec::Functions" => 0,
  "FindBin" => "0.05",
  "Getopt::Long" => 0,
  "Graph::Easy" => 0,
  "Graph::Easy::As_svg" => 0,
  "Module::CoreList" => 0,
  "Module::Path" => 0,
  "Moo" => 0,
  "Perl::PrereqScanner" => 0,
  "Pod::Usage" => 0,
  "Test::More" => "0.88",
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

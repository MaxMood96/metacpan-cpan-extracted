# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Write content into your source tree from your release staging",
  "AUTHOR" => "Kent Fredric <kentnl\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-App-Command-regenerate",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Dist::Zilla::App::Command::regenerate",
  "PREREQ_PM" => {
    "Beam::Emitter" => 0,
    "Beam::Event" => 0,
    "Carp" => 0,
    "Dist::Zilla::App" => 0,
    "Dist::Zilla::Role::Plugin" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Path::Tiny" => "0.017",
    "Safe::Isa" => 0,
    "namespace::clean" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Dist::Zilla::App::Tester" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::DZil" => 0,
    "Test::More" => 0,
    "Test::Needs" => 0,
    "Test::TempDir::Tiny" => 0
  },
  "VERSION" => "0.001003",
  "test" => {
    "TESTS" => "t/*.t t/plugin/*.t"
  }
);


my %FallbackPrereqs = (
  "Beam::Emitter" => 0,
  "Beam::Event" => 0,
  "Carp" => 0,
  "Dist::Zilla::App" => 0,
  "Dist::Zilla::App::Tester" => 0,
  "Dist::Zilla::Role::Plugin" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "Path::Tiny" => "0.017",
  "Safe::Isa" => 0,
  "Test::DZil" => 0,
  "Test::More" => 0,
  "Test::Needs" => 0,
  "Test::TempDir::Tiny" => 0,
  "namespace::clean" => 0,
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

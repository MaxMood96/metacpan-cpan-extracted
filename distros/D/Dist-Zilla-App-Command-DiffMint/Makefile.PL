# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.033.
use strict;
use warnings;

use 5.020000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Compare files to what a minting profile produces",
  "AUTHOR" => "Graham Knop <haarg\@haarg.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-App-Command-DiffMint",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.020000",
  "NAME" => "Dist::Zilla::App::Command::DiffMint",
  "PREREQ_PM" => {
    "Digest::SHA" => 0,
    "Dist::Zilla::App" => "6.000",
    "Dist::Zilla::Stash::Rights" => "6.000",
    "Moose" => "2.0000",
    "Term::ANSIColor" => 0,
    "Text::Diff" => 0,
    "namespace::autoclean" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.88"
  },
  "VERSION" => "v0.3.2",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Digest::SHA" => 0,
  "Dist::Zilla::App" => "6.000",
  "Dist::Zilla::Stash::Rights" => "6.000",
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Moose" => "2.0000",
  "Term::ANSIColor" => 0,
  "Test::More" => "0.88",
  "Text::Diff" => 0,
  "namespace::autoclean" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

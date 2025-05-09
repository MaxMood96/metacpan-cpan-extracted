# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.008.
use strict;
use warnings;

use 5.010000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Checks Changes for content using CPAN::Changes",
  "AUTHOR" => "Dave Rolsky <autarch\@urth.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-Plugin-EnsureChangesHasContent",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.010000",
  "NAME" => "Dist::Zilla::Plugin::EnsureChangesHasContent",
  "PREREQ_PM" => {
    "CPAN::Changes" => 0,
    "Dist::Zilla::Role::BeforeRelease" => 0,
    "Moose" => 0,
    "autodie" => 0,
    "namespace::autoclean" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => "0.96"
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "CPAN::Changes" => 0,
  "Dist::Zilla::Role::BeforeRelease" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Moose" => 0,
  "Test::More" => "0.96",
  "autodie" => 0,
  "namespace::autoclean" => 0,
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

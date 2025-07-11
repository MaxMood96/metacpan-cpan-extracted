# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.008.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Load and interpret a bundle",
  "AUTHOR" => "Kent Fredric <kentnl\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-Util-BundleInfo",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Dist::Zilla::Util::BundleInfo",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Dist::Zilla::Util" => 0,
    "Module::Runtime" => 0,
    "Moo" => "1.000008",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Dist::Zilla::Plugin::GatherDir" => 0,
    "Dist::Zilla::PluginBundle::Basic" => 0,
    "Dist::Zilla::PluginBundle::Classic" => 0,
    "Dist::Zilla::Role::Plugin" => 0,
    "Dist::Zilla::Role::PluginBundle" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Moose" => 0,
    "Test::More" => 0,
    "Test::Warnings" => 0
  },
  "VERSION" => "1.001005",
  "test" => {
    "TESTS" => "t/*.t t/00-compile/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Dist::Zilla::Plugin::GatherDir" => 0,
  "Dist::Zilla::PluginBundle::Basic" => 0,
  "Dist::Zilla::PluginBundle::Classic" => 0,
  "Dist::Zilla::Role::Plugin" => 0,
  "Dist::Zilla::Role::PluginBundle" => 0,
  "Dist::Zilla::Util" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Module::Runtime" => 0,
  "Moo" => "1.000008",
  "Moose" => 0,
  "Test::More" => 0,
  "Test::Warnings" => 0,
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

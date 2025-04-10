# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Build your distributions like FLORA does",
  "AUTHOR" => "Florian Ragwitz <rafl\@debian.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-PluginBundle-FLORA",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Dist::Zilla::PluginBundle::FLORA",
  "PREREQ_PM" => {
    "Dist::Zilla::Plugin::Authority" => 0,
    "Dist::Zilla::Plugin::AutoPrereqs" => 0,
    "Dist::Zilla::Plugin::MetaConfig" => 0,
    "Dist::Zilla::Plugin::MetaJSON" => 0,
    "Dist::Zilla::Plugin::MetaResources" => 3,
    "Dist::Zilla::Plugin::MinimumPerl" => "1.006",
    "Dist::Zilla::Plugin::PkgVersion" => 0,
    "Dist::Zilla::Plugin::PodCoverageTests" => 0,
    "Dist::Zilla::Plugin::PodSyntaxTests" => 0,
    "Dist::Zilla::Plugin::PodWeaver" => 0,
    "Dist::Zilla::Plugin::TaskWeaver" => 0,
    "Dist::Zilla::Plugin::Test::EOL" => "0.14",
    "Dist::Zilla::Plugin::Test::NoTabs" => "0.08",
    "Dist::Zilla::Plugin::Test::ReportPrereqs" => "0.019",
    "Dist::Zilla::PluginBundle::Basic" => 0,
    "Dist::Zilla::Role::PluginBundle::Config::Slicer" => 0,
    "Dist::Zilla::Role::PluginBundle::Easy" => 0,
    "Dist::Zilla::Role::PluginBundle::PluginRemover" => "0.103",
    "Method::Signatures::Simple" => 0,
    "Moose" => "1.00",
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::Types::Email" => 0,
    "MooseX::Types::Moose" => 0,
    "MooseX::Types::Structured" => "0.20",
    "MooseX::Types::URI" => 0,
    "Pod::Weaver::PluginBundle::FLORA" => "0.03",
    "namespace::autoclean" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.18",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Dist::Zilla::Plugin::Authority" => 0,
  "Dist::Zilla::Plugin::AutoPrereqs" => 0,
  "Dist::Zilla::Plugin::MetaConfig" => 0,
  "Dist::Zilla::Plugin::MetaJSON" => 0,
  "Dist::Zilla::Plugin::MetaResources" => 3,
  "Dist::Zilla::Plugin::MinimumPerl" => "1.006",
  "Dist::Zilla::Plugin::PkgVersion" => 0,
  "Dist::Zilla::Plugin::PodCoverageTests" => 0,
  "Dist::Zilla::Plugin::PodSyntaxTests" => 0,
  "Dist::Zilla::Plugin::PodWeaver" => 0,
  "Dist::Zilla::Plugin::TaskWeaver" => 0,
  "Dist::Zilla::Plugin::Test::EOL" => "0.14",
  "Dist::Zilla::Plugin::Test::NoTabs" => "0.08",
  "Dist::Zilla::Plugin::Test::ReportPrereqs" => "0.019",
  "Dist::Zilla::PluginBundle::Basic" => 0,
  "Dist::Zilla::Role::PluginBundle::Config::Slicer" => 0,
  "Dist::Zilla::Role::PluginBundle::Easy" => 0,
  "Dist::Zilla::Role::PluginBundle::PluginRemover" => "0.103",
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Method::Signatures::Simple" => 0,
  "Moose" => "1.00",
  "Moose::Util::TypeConstraints" => 0,
  "MooseX::Types::Email" => 0,
  "MooseX::Types::Moose" => 0,
  "MooseX::Types::Structured" => "0.20",
  "MooseX::Types::URI" => 0,
  "Pod::Weaver::PluginBundle::FLORA" => "0.03",
  "Test::More" => 0,
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

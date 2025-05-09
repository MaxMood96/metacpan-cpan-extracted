# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Sync a cpanfile with the prereqs listed in dist.ini",
  "AUTHOR" => "Renee Baecker <reneeb\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-Plugin-SyncCPANfile",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Dist::Zilla::Plugin::SyncCPANfile",
  "PREREQ_PM" => {
    "CPAN::Audit" => 20230601,
    "Dist::Zilla" => 6,
    "Moose" => 2,
    "Path::Tiny" => 0,
    "namespace::clean" => "0.27"
  },
  "TEST_REQUIRES" => {
    "Clone" => 0,
    "Exporter" => 0,
    "Module::CPANfile" => 0,
    "Pod::Coverage::TrustPod" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.04",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "CPAN::Audit" => 20230601,
  "Clone" => 0,
  "Dist::Zilla" => 6,
  "Exporter" => 0,
  "Module::CPANfile" => 0,
  "Moose" => 2,
  "Path::Tiny" => 0,
  "Pod::Coverage::TrustPod" => 0,
  "Test::More" => 0,
  "namespace::clean" => "0.27"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

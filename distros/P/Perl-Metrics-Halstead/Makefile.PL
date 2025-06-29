# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Compute Halstead complexity metrics",
  "AUTHOR" => "Gene Boggs <gene.boggs\@gmail.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Perl-Metrics-Halstead",
  "EXE_FILES" => [
    "bin/halstead.pl"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Perl::Metrics::Halstead",
  "PREREQ_PM" => {
    "Getopt::Long" => 0,
    "Moo" => 2,
    "PPI::Document" => 0,
    "PPI::Dumper" => 0,
    "Pod::Usage" => 0,
    "namespace::clean" => 0,
    "strict" => 0,
    "strictures" => 2,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Capture::Tiny" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.0620",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Capture::Tiny" => 0,
  "File::Spec" => 0,
  "Getopt::Long" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Moo" => 2,
  "PPI::Document" => 0,
  "PPI::Dumper" => 0,
  "Pod::Usage" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0,
  "namespace::clean" => 0,
  "strict" => 0,
  "strictures" => 2,
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

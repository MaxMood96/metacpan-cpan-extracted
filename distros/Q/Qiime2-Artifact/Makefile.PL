# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

# inserted by Dist::Zilla::Plugin::CheckBin 0.008
use Devel::CheckBin;
check_bin('unzip');
check_bin('which');

use 5.014;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A parser for Qiime2 artifact files",
  "AUTHOR" => "Andrea Telatin <andrea\@telatin.com>",
  "CONFIGURE_REQUIRES" => {
    "Devel::CheckBin" => 0,
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Qiime2-Artifact",
  "EXE_FILES" => [
    "bin/qzoom"
  ],
  "LICENSE" => "mit",
  "MIN_PERL_VERSION" => "5.014",
  "NAME" => "Qiime2::Artifact",
  "PREREQ_PM" => {
    "Capture::Tiny" => "0.48",
    "Carp" => "1.2",
    "Cwd" => "3.31",
    "Data::Dumper" => "2.1",
    "File::Basename" => "2.82",
    "FindBin" => "1.3",
    "Term::ANSIColor" => "3.00",
    "YAML::PP" => "0.38",
    "autodie" => "2.10"
  },
  "VERSION" => "0.13.0",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Capture::Tiny" => "0.48",
  "Carp" => "1.2",
  "Cwd" => "3.31",
  "Data::Dumper" => "2.1",
  "File::Basename" => "2.82",
  "FindBin" => "1.3",
  "Term::ANSIColor" => "3.00",
  "YAML::PP" => "0.38",
  "autodie" => "2.10"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

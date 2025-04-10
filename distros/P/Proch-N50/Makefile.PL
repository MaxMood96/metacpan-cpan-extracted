# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.012;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Calculate N50 and related statistics for FASTA/FASTQ files with minimal dependencies",
  "AUTHOR" => "Andrea Telatin <andrea\@telatin.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Proch-N50",
  "EXE_FILES" => [
    "bin/fu-cat",
    "bin/fu-compare",
    "bin/fu-count",
    "bin/fu-extract",
    "bin/fu-grep",
    "bin/fu-hash",
    "bin/fu-len",
    "bin/fu-rename",
    "bin/fu-say",
    "bin/fu-sort",
    "bin/fu-uniq",
    "bin/n50"
  ],
  "LICENSE" => "mit",
  "MIN_PERL_VERSION" => "5.012",
  "NAME" => "Proch::N50",
  "PREREQ_PM" => {
    "FASTX::Reader" => "1.8.0",
    "Getopt::Long" => "2.39",
    "JSON::PP" => "2.27",
    "PerlIO::encoding" => 0,
    "Pod::Usage" => "1.61",
    "Text::ASCIITable" => 0
  },
  "VERSION" => "1.7.0",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "FASTX::Reader" => "1.8.0",
  "Getopt::Long" => "2.39",
  "JSON::PP" => "2.27",
  "PerlIO::encoding" => 0,
  "Pod::Usage" => "1.61",
  "Text::ASCIITable" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

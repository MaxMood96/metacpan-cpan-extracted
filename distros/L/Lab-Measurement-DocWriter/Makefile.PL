# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.009.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Documentation formatting for Lab::Measurement",
  "AUTHOR" => "Andreas K. Huettel <dilfridge\@gentoo.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Lab-Measurement-DocWriter",
  "EXE_FILES" => [
    "bin/make-lm-doku"
  ],
  "LICENSE" => "perl",
  "NAME" => "Lab::Measurement::DocWriter",
  "PREREQ_PM" => {
    "Cwd" => 0,
    "Data::Dumper" => 0,
    "File::Basename" => 0,
    "File::Path" => 0,
    "Getopt::Long" => 0,
    "Pod::LaTeX" => 0,
    "Pod::Simple::XHTML" => 0,
    "Pod::Usage" => 0,
    "Syntax::Highlight::Engine::Simple::Perl" => 0,
    "YAML" => 0,
    "parent" => 0,
    "strict" => 0
  },
  "VERSION" => "1.000",
  "test" => {
    "TESTS" => ""
  }
);


my %FallbackPrereqs = (
  "Cwd" => 0,
  "Data::Dumper" => 0,
  "File::Basename" => 0,
  "File::Path" => 0,
  "Getopt::Long" => 0,
  "Pod::LaTeX" => 0,
  "Pod::Simple::XHTML" => 0,
  "Pod::Usage" => 0,
  "Syntax::Highlight::Engine::Simple::Perl" => 0,
  "YAML" => 0,
  "parent" => 0,
  "strict" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

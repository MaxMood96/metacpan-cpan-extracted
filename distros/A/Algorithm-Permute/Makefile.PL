# This Makefile.PL for Algorithm-Permute was generated by
# Dist::Zilla::Plugin::MakeMaker::Awesome 0.49.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Handy and fast permutation with object oriented interface",
  "AUTHOR" => "Edwin Pratomo <edpratomo\@cpan.org>, Stephan Loyd <sloyd\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Test::More" => "0.88"
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Algorithm-Permute",
  "LICENSE" => "perl",
  "NAME" => "Algorithm::Permute",
  "PREREQ_PM" => {
    "Exporter" => 0,
    "XSLoader" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Test::LeakTrace" => 0,
    "Test::More" => "0.88"
  },
  "VERSION" => "0.17",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

%WriteMakefileArgs = (
    %WriteMakefileArgs,
    DEFINE => '-DPERL_EXT',
    OBJECT => 'coollex.o Permute.o',
);

my %FallbackPrereqs = (
  "Exporter" => 0,
  "Test::LeakTrace" => 0,
  "Test::More" => "0.88",
  "XSLoader" => 0,
  "strict" => 0,
  "warnings" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

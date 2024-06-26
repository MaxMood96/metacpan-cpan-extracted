# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.025.
use strict;
use warnings;

use 5.014;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Parse CIGAR strings and translate coordinates to/from reference/query",
  "AUTHOR" => "Thomas Sibley <trsibley\@uw.edu>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Bio-Cigar",
  "LICENSE" => "gpl",
  "MIN_PERL_VERSION" => "5.014",
  "NAME" => "Bio::Cigar",
  "PREREQ_PM" => {
    "Carp" => 0,
    "List::Util" => 0,
    "Moo" => 0,
    "Types::Standard" => "1.000005",
    "namespace::clean" => 0
  },
  "TEST_REQUIRES" => {
    "Test::More" => "0.96"
  },
  "VERSION" => "1.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "List::Util" => 0,
  "Moo" => 0,
  "Test::More" => "0.96",
  "Types::Standard" => "1.000005",
  "namespace::clean" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

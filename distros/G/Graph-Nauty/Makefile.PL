# This Makefile.PL for Graph-Nauty was generated by
# Dist::Zilla::Plugin::MakeMaker::Awesome 0.48.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Perl bindings for Nauty",
  "AUTHOR" => "Andrius Merkys <merkys\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Graph-Nauty",
  "LICENSE" => "bsd",
  "NAME" => "Graph::Nauty",
  "PREREQ_PM" => {
    "Data::Dumper" => 0,
    "Graph::Undirected" => 0,
    "Scalar::Util" => 0
  },
  "TEST_REQUIRES" => {
    "Graph::Undirected" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.5.3",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

%WriteMakefileArgs = (
    %WriteMakefileArgs,
    LIBS => [ '-lnauty' ],
);

my %FallbackPrereqs = (
  "Data::Dumper" => 0,
  "Graph::Undirected" => 0,
  "Scalar::Util" => 0,
  "Test::More" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

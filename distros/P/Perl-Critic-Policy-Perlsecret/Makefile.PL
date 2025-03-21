# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.043.
use strict;
use warnings;

use 5.006001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Prevent perlsecrets entering your codebase",
  "AUTHOR" => "Lance Wicks <lancew\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Perl-Critic-Policy-Perlsecret",
  "LICENSE" => "gpl",
  "MIN_PERL_VERSION" => "5.006001",
  "NAME" => "Perl::Critic::Policy::Perlsecret",
  "PREREQ_PM" => {
    "Carp" => 0,
    "List::Util" => 0,
    "Perl::Critic::Policy" => 0,
    "Perl::Critic::Utils" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Perl::Critic::TestUtils" => 0,
    "Test::FailWarnings" => 0,
    "Test::Fatal" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.0.11",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "List::Util" => 0,
  "Perl::Critic::Policy" => 0,
  "Perl::Critic::TestUtils" => 0,
  "Perl::Critic::Utils" => 0,
  "Test::FailWarnings" => 0,
  "Test::Fatal" => 0,
  "Test::More" => 0,
  "parent" => 0,
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

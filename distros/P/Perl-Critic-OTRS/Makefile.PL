# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.010.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A collection of handy Perl::Critic policies",
  "AUTHOR" => "Renee Baecker <info\@perl-services.de>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Perl-Critic-OTRS",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Perl::Critic::OTRS",
  "PREREQ_PM" => {
    "Perl::Critic" => "1.105",
    "Readonly" => "1.03"
  },
  "TEST_REQUIRES" => {
    "Test::Warnings" => 0
  },
  "VERSION" => "0.09",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Perl::Critic" => "1.105",
  "Readonly" => "1.03",
  "Test::Warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.009.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker 6.17;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Generate README from Pod, as simply as possible",
  "AUTHOR" => "David Golden <dagolden\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.17"
  },
  "DISTNAME" => "Dist-Zilla-Plugin-Pod2Readme",
  "LICENSE" => "apache",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Dist::Zilla::Plugin::Pod2Readme",
  "PREREQ_PM" => {
    "Dist::Zilla" => 5,
    "Dist::Zilla::File::FromCode" => 0,
    "Dist::Zilla::Role::FileGatherer" => 0,
    "List::Util" => 0,
    "Moose" => 0,
    "Pod::Text" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::DZil" => 0,
    "Test::More" => "0.96"
  },
  "VERSION" => "0.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Dist::Zilla" => 5,
  "Dist::Zilla::File::FromCode" => 0,
  "Dist::Zilla::Role::FileGatherer" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "List::Util" => 0,
  "Moose" => 0,
  "Pod::Text" => 0,
  "Test::DZil" => 0,
  "Test::More" => "0.96",
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

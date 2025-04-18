# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.009.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Vivify a Git::Wrapper instance for Dist::Zilla",
  "AUTHOR" => "Kent Fredric <kentnl\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-Util-Git-Wrapper",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Dist::Zilla::Util::Git::Wrapper",
  "PREREQ_PM" => {
    "Dist::Zilla::UtilRole::MaybeZilla" => 0,
    "Git::Wrapper" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Log::Contextual::LogDispatchouli" => 0,
    "Log::Dispatchouli" => 0,
    "Path::Tiny" => 0,
    "Sort::Versions" => 0,
    "Test::Fatal" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.004002",
  "test" => {
    "TESTS" => "t/*.t t/00-compile/*.t"
  }
);


my %FallbackPrereqs = (
  "Dist::Zilla::UtilRole::MaybeZilla" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Git::Wrapper" => 0,
  "Log::Contextual::LogDispatchouli" => 0,
  "Log::Dispatchouli" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "Path::Tiny" => 0,
  "Sort::Versions" => 0,
  "Test::Fatal" => 0,
  "Test::More" => 0,
  "strict" => 0,
  "utf8" => 0,
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

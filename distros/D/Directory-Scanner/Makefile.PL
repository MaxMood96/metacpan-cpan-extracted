# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.010.
use strict;
use warnings;

use 5.010000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Streaming directory scanner",
  "AUTHOR" => "Stevan Little <stevan\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Directory-Scanner",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010000",
  "NAME" => "Directory::Scanner",
  "PREREQ_PM" => {
    "Carp" => 0,
    "FindBin" => 0,
    "Path::Tiny" => 0,
    "Scalar::Util" => 0,
    "UNIVERSAL::Object" => "0.14",
    "roles" => "0.03",
    "slots" => "0.03"
  },
  "TEST_REQUIRES" => {
    "Test::Fatal" => 0,
    "Test::More" => "0.88"
  },
  "VERSION" => "0.04",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "FindBin" => 0,
  "Path::Tiny" => 0,
  "Scalar::Util" => 0,
  "Test::Fatal" => 0,
  "Test::More" => "0.88",
  "UNIVERSAL::Object" => "0.14",
  "roles" => "0.03",
  "slots" => "0.03"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

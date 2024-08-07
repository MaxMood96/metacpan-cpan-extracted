# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.029.
use strict;
use warnings;

use 5.012;

use ExtUtils::MakeMaker 6.78;

my %WriteMakefileArgs = (
  "ABSTRACT" => "read multiple hunks of data out of your DATA section",
  "AUTHOR" => "Ricardo SIGNES <cpan\@semiotic.systems>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.78"
  },
  "DISTNAME" => "Data-Section",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.012",
  "NAME" => "Data::Section",
  "PREREQ_PM" => {
    "Encode" => 0,
    "MRO::Compat" => "0.09",
    "Sub::Exporter" => "0.979",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::FailWarnings" => 0,
    "Test::More" => "0.96",
    "base" => 0,
    "lib" => 0,
    "utf8" => 0
  },
  "VERSION" => "0.200008",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Encode" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "MRO::Compat" => "0.09",
  "Sub::Exporter" => "0.979",
  "Test::FailWarnings" => 0,
  "Test::More" => "0.96",
  "base" => 0,
  "lib" => 0,
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

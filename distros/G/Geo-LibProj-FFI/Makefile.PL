# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.014000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Foreign function interface to PROJ coordinate transformation software",
  "AUTHOR" => "Arne Johannessen <ajnn\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Geo-LibProj-FFI",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.014000",
  "NAME" => "Geo::LibProj::FFI",
  "PREREQ_PM" => {
    "Alien::proj" => "1.07",
    "Convert::Binary::C" => "0.04",
    "Exporter::Easy" => 0,
    "FFI::C" => "0.08",
    "FFI::Platypus" => "1.50"
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "Test::Warnings" => "0.010"
  },
  "VERSION" => "1.01",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Alien::proj" => "1.07",
  "Convert::Binary::C" => "0.04",
  "Exporter::Easy" => 0,
  "ExtUtils::MakeMaker" => 0,
  "FFI::C" => "0.08",
  "FFI::Platypus" => "1.50",
  "File::Spec" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0,
  "Test::Warnings" => "0.010"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

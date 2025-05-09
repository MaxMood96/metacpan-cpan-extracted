# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Various Sah schemas for Unix",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Sah-SchemaBundle-Unix",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Sah::SchemaBundle::Unix",
  "PREREQ_PM" => {
    "Complete::Unix" => "0.07",
    "Complete::Util" => "0.620",
    "Data::Sah::Compiler::perl::TH::int" => "0.914",
    "Data::Sah::Compiler::perl::TH::str" => "0.914",
    "Data::Sah::Filter::perl::Path::expand_tilde" => 0,
    "Data::Sah::Filter::perl::Path::strip_slashes" => 0,
    "Sah::Schema::dirname::unix" => 0,
    "Sah::Schema::filename::unix" => 0,
    "Sah::Schema::pathname::unix" => 0,
    "Sah::Schema::posint" => 0,
    "Sah::Schema::uint" => 0,
    "Scalar::Util::Numeric" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.022",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Complete::Unix" => "0.07",
  "Complete::Util" => "0.620",
  "Data::Sah::Compiler::perl::TH::int" => "0.914",
  "Data::Sah::Compiler::perl::TH::str" => "0.914",
  "Data::Sah::Filter::perl::Path::expand_tilde" => 0,
  "Data::Sah::Filter::perl::Path::strip_slashes" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Sah::Schema::dirname::unix" => 0,
  "Sah::Schema::filename::unix" => 0,
  "Sah::Schema::pathname::unix" => 0,
  "Sah::Schema::posint" => 0,
  "Sah::Schema::uint" => 0,
  "Scalar::Util::Numeric" => 0,
  "Test::More" => 0,
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

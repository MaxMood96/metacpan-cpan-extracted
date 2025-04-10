# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.023.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "List Perl releases",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-ListPerlReleases",
  "EXE_FILES" => [
    "script/list-perl-releases"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::ListPerlReleases",
  "PREREQ_PM" => {
    "CPAN::Perl::Releases" => 0,
    "Data::Sah::Compiler::perl::TH::array" => 0,
    "Data::Sah::Compiler::perl::TH::bool" => 0,
    "Data::Sah::Compiler::perl::TH::int" => 0,
    "Data::Sah::Compiler::perl::TH::str" => 0,
    "Exporter" => "5.57",
    "Perinci::CmdLine::Any" => "0.152",
    "Perinci::CmdLine::Lite" => "1.905",
    "Perinci::Sub::Gen::AccessTable" => "0.586",
    "Perinci::Sub::Property::result::table" => 0,
    "Sah::Schema::filename" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "CPAN::Perl::Releases" => 0,
  "Data::Sah::Compiler::perl::TH::array" => 0,
  "Data::Sah::Compiler::perl::TH::bool" => 0,
  "Data::Sah::Compiler::perl::TH::int" => 0,
  "Data::Sah::Compiler::perl::TH::str" => 0,
  "Exporter" => "5.57",
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Perinci::CmdLine::Any" => "0.152",
  "Perinci::CmdLine::Lite" => "1.905",
  "Perinci::Sub::Gen::AccessTable" => "0.586",
  "Perinci::Sub::Property::result::table" => 0,
  "Sah::Schema::filename" => 0,
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

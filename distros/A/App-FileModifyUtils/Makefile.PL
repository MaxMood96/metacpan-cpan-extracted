# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.023.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Utilities related to modifying files",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-FileModifyUtils",
  "EXE_FILES" => [
    "script/add-line-to-file",
    "script/remove-line-from-file"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::FileModifyUtils",
  "PREREQ_PM" => {
    "Data::Sah::Compiler::perl::TH::bool" => "0.910",
    "Data::Sah::Compiler::perl::TH::str" => "0.910",
    "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
    "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
    "Exporter" => "5.57",
    "Log::ger" => "0.038",
    "Perinci::CmdLine::Any" => "0.152",
    "Perinci::CmdLine::Lite" => "1.905",
    "Sah::Schema::filename" => 0,
    "Setup::File::Line" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.002",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Data::Sah::Compiler::perl::TH::bool" => "0.910",
  "Data::Sah::Compiler::perl::TH::str" => "0.910",
  "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
  "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
  "Exporter" => "5.57",
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.038",
  "Perinci::CmdLine::Any" => "0.152",
  "Perinci::CmdLine::Lite" => "1.905",
  "Sah::Schema::filename" => 0,
  "Setup::File::Line" => 0,
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

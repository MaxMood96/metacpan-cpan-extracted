# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Utilities to diff stuffs from two different versions of a module",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-ModuleVersionDiffUtils",
  "EXE_FILES" => [
    "script/diff-two-module-version-hash"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::ModuleVersionDiffUtils",
  "PREREQ_PM" => {
    "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_modname" => 0,
    "Data::Sah::Compiler::perl::TH::array" => 0,
    "Data::Sah::Compiler::perl::TH::str" => 0,
    "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
    "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
    "Log::ger" => "0.038",
    "Module::Path::More" => "0.32",
    "Perinci::CmdLine::Any" => 0,
    "Perinci::CmdLine::Lite" => "1.827",
    "Perinci::Sub::Property::cmdline" => 0,
    "Sah::Schema::dirname" => 0,
    "Sah::Schema::perl::modname" => "0.035",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_modname" => 0,
  "Data::Sah::Compiler::perl::TH::array" => 0,
  "Data::Sah::Compiler::perl::TH::str" => 0,
  "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
  "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.038",
  "Module::Path::More" => "0.32",
  "Perinci::CmdLine::Any" => 0,
  "Perinci::CmdLine::Lite" => "1.827",
  "Perinci::Sub::Property::cmdline" => 0,
  "Sah::Schema::dirname" => 0,
  "Sah::Schema::perl::modname" => "0.035",
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

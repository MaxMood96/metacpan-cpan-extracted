# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "An opinionated Org addressbook toolset",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-orgadb",
  "EXE_FILES" => [
    "script/orgadb-sel"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::orgadb",
  "PREREQ_PM" => {
    "Carp" => "1.12",
    "Clipboard::Any" => "0.011",
    "ColorThemeUtil::ANSI" => 0,
    "Complete::Bash" => "0.333",
    "Complete::Util" => "0.620",
    "Config::IOD::Reader" => "0.344",
    "Data::CSel" => "0.128",
    "Data::Dmp" => "0.242",
    "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_modname" => 0,
    "Data::Sah::Compiler::perl::TH::any" => "0.914",
    "Data::Sah::Compiler::perl::TH::array" => "0.914",
    "Data::Sah::Compiler::perl::TH::bool" => "0.914",
    "Data::Sah::Compiler::perl::TH::hash" => "0.914",
    "Data::Sah::Compiler::perl::TH::int" => "0.914",
    "Data::Sah::Compiler::perl::TH::re" => "0.914",
    "Data::Sah::Compiler::perl::TH::str" => "0.914",
    "Data::Sah::Filter" => "0.024",
    "Data::Sah::Filter::perl::JSON::decode_str" => 0,
    "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
    "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
    "Data::Sah::Filter::perl::Perl::normalize_perl_modname" => 0,
    "Data::Sah::Filter::perl::Str::maybe_convert_to_re" => 0,
    "Data::Sah::Normalize" => "0.051",
    "IO::Stty" => 0,
    "IPC::System::Options" => "0.339",
    "JSON::PP" => 0,
    "Log::ger" => "0.038",
    "Module::Load::Util" => "0.011",
    "Org::Parser" => "0.558",
    "Perinci::CmdLine::Any" => 0,
    "Perinci::CmdLine::Help" => "0.175",
    "Perinci::Result::Format::Lite" => "0.286",
    "Perinci::Sub::Complete" => "0.944",
    "Perinci::Sub::GetArgs::Argv" => "0.846",
    "Perinci::Sub::ValidateArgs" => "0.012",
    "Perinci::Sub::XCompletion::filename" => 0,
    "Regexp::From::String" => "0.005",
    "Sah::Schema::array_from_json" => 0,
    "Sah::Schema::filename" => 0,
    "Sah::Schema::perl::colortheme::modname_with_optional_args" => 0,
    "Sah::Schema::str_or_re" => 0,
    "Sah::Schema::true" => 0,
    "Sah::Schema::uint" => 0,
    "Signal::Safety" => 0,
    "Term::Shell" => 0,
    "Time::HiRes" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.020",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => "1.12",
  "Clipboard::Any" => "0.011",
  "ColorThemeUtil::ANSI" => 0,
  "Complete::Bash" => "0.333",
  "Complete::Util" => "0.620",
  "Config::IOD::Reader" => "0.344",
  "Data::CSel" => "0.128",
  "Data::Dmp" => "0.242",
  "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_modname" => 0,
  "Data::Sah::Compiler::perl::TH::any" => "0.914",
  "Data::Sah::Compiler::perl::TH::array" => "0.914",
  "Data::Sah::Compiler::perl::TH::bool" => "0.914",
  "Data::Sah::Compiler::perl::TH::hash" => "0.914",
  "Data::Sah::Compiler::perl::TH::int" => "0.914",
  "Data::Sah::Compiler::perl::TH::re" => "0.914",
  "Data::Sah::Compiler::perl::TH::str" => "0.914",
  "Data::Sah::Filter" => "0.024",
  "Data::Sah::Filter::perl::JSON::decode_str" => 0,
  "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
  "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
  "Data::Sah::Filter::perl::Perl::normalize_perl_modname" => 0,
  "Data::Sah::Filter::perl::Str::maybe_convert_to_re" => 0,
  "Data::Sah::Normalize" => "0.051",
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IO::Stty" => 0,
  "IPC::Open3" => 0,
  "IPC::System::Options" => "0.339",
  "JSON::PP" => 0,
  "Log::ger" => "0.038",
  "Module::Load::Util" => "0.011",
  "Org::Parser" => "0.558",
  "Perinci::CmdLine::Any" => 0,
  "Perinci::CmdLine::Help" => "0.175",
  "Perinci::Result::Format::Lite" => "0.286",
  "Perinci::Sub::Complete" => "0.944",
  "Perinci::Sub::GetArgs::Argv" => "0.846",
  "Perinci::Sub::ValidateArgs" => "0.012",
  "Perinci::Sub::XCompletion::filename" => 0,
  "Regexp::From::String" => "0.005",
  "Sah::Schema::array_from_json" => 0,
  "Sah::Schema::filename" => 0,
  "Sah::Schema::perl::colortheme::modname_with_optional_args" => 0,
  "Sah::Schema::str_or_re" => 0,
  "Sah::Schema::true" => 0,
  "Sah::Schema::uint" => 0,
  "Signal::Safety" => 0,
  "Term::Shell" => 0,
  "Test::More" => 0,
  "Time::HiRes" => 0,
  "parent" => 0,
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

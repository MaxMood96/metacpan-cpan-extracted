# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Manage a Rinci metadata database",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-rimetadb",
  "EXE_FILES" => [
    "script/rimetadb"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::rimetadb",
  "PREREQ_PM" => {
    "Complete::Util" => "0.616",
    "DBD::SQLite" => 0,
    "DBI" => 0,
    "Data::Clean::ForJSON" => 0,
    "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_modname_or_prefix" => 0,
    "Data::Sah::Compiler::perl::TH::array" => "0.914",
    "Data::Sah::Compiler::perl::TH::bool" => "0.914",
    "Data::Sah::Compiler::perl::TH::hash" => "0.914",
    "Data::Sah::Compiler::perl::TH::str" => "0.914",
    "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
    "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
    "Data::Sah::Filter::perl::Perl::normalize_perl_modname" => 0,
    "Data::Sah::Util::Type" => "0.45",
    "JSON::MaybeXS" => 0,
    "Log::ger" => "0.038",
    "Module::List" => 0,
    "Module::Load" => 0,
    "Module::Path::More" => "0.32",
    "Package::Util::Lite" => 0,
    "Perinci::Access::Perl" => "0.895",
    "Perinci::CmdLine::Any" => 0,
    "Perinci::Sub::Normalize" => "0.205",
    "SQL::Schema::Versioned" => "0.234",
    "Sah::Schema::dirname" => 0,
    "Sah::Schema::perl::modname" => "0.035",
    "Sah::Schema::perl::modname_or_prefix" => 0,
    "lib" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.98",
    "Test::SQL::Schema::Versioned" => 0,
    "Test::WithDB::SQLite" => "0.08"
  },
  "VERSION" => "0.226",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Complete::Util" => "0.616",
  "DBD::SQLite" => 0,
  "DBI" => 0,
  "Data::Clean::ForJSON" => 0,
  "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_modname_or_prefix" => 0,
  "Data::Sah::Compiler::perl::TH::array" => "0.914",
  "Data::Sah::Compiler::perl::TH::bool" => "0.914",
  "Data::Sah::Compiler::perl::TH::hash" => "0.914",
  "Data::Sah::Compiler::perl::TH::str" => "0.914",
  "Data::Sah::Filter::perl::Path::expand_tilde_when_on_unix" => 0,
  "Data::Sah::Filter::perl::Path::strip_slashes_when_on_unix" => 0,
  "Data::Sah::Filter::perl::Perl::normalize_perl_modname" => 0,
  "Data::Sah::Util::Type" => "0.45",
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON::MaybeXS" => 0,
  "Log::ger" => "0.038",
  "Module::List" => 0,
  "Module::Load" => 0,
  "Module::Path::More" => "0.32",
  "Package::Util::Lite" => 0,
  "Perinci::Access::Perl" => "0.895",
  "Perinci::CmdLine::Any" => 0,
  "Perinci::Sub::Normalize" => "0.205",
  "SQL::Schema::Versioned" => "0.234",
  "Sah::Schema::dirname" => 0,
  "Sah::Schema::perl::modname" => "0.035",
  "Sah::Schema::perl::modname_or_prefix" => 0,
  "Test::More" => "0.98",
  "Test::SQL::Schema::Versioned" => 0,
  "Test::WithDB::SQLite" => "0.08",
  "lib" => 0,
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

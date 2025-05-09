# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Utilities related to BPOM",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-BPOMUtils",
  "EXE_FILES" => [
    "script/bpom-daftar-bahan-baku-pangan",
    "script/bpom-daftar-bahan-tambahan-pangan",
    "script/bpom-daftar-cemaran-logam-pangan",
    "script/bpom-daftar-cemaran-mikroba-pangan",
    "script/bpom-daftar-jenis-pangan",
    "script/bpom-daftar-kategori-pangan",
    "script/bpom-daftar-kode-prefiks-reg",
    "script/bpom-list-food-additives",
    "script/bpom-list-food-categories",
    "script/bpom-list-food-ingredients",
    "script/bpom-list-food-inputs",
    "script/bpom-list-food-microbe-inputs",
    "script/bpom-list-food-types",
    "script/bpom-list-reg-code-prefixes",
    "script/bpom-show-nutrition-facts",
    "script/bpom-tampilkan-ing"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::BPOMUtils",
  "PREREQ_PM" => {
    "Browser::Open" => 0,
    "Data::Sah::Coerce::perl::To_float::From_str::percent" => 0,
    "Data::Sah::Compiler::perl::TH::array" => "0.914",
    "Data::Sah::Compiler::perl::TH::bool" => "0.914",
    "Data::Sah::Compiler::perl::TH::float" => "0.914",
    "Data::Sah::Compiler::perl::TH::int" => "0.914",
    "Data::Sah::Compiler::perl::TH::str" => "0.914",
    "Exporter" => "5.57",
    "File::Slurper" => 0,
    "File::Temp" => "0.2307",
    "Log::ger" => "0.038",
    "Math::Round" => 0,
    "Number::Format" => 0,
    "Org::To::ANSIText" => 0,
    "Org::To::HTML" => "0.18",
    "Org::To::Text" => "0.050",
    "Perinci::CmdLine::Any" => "0.154",
    "Perinci::CmdLine::Lite" => "1.924",
    "Perinci::Sub::Gen::AccessTable" => "0.590",
    "Perinci::Sub::Property::result::table" => 0,
    "Sah::Schema::true" => 0,
    "Sah::Schema::ufloat" => 0,
    "Text::Table::HTML" => "0.008",
    "Text::Table::More" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.014",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Browser::Open" => 0,
  "Data::Sah::Coerce::perl::To_float::From_str::percent" => 0,
  "Data::Sah::Compiler::perl::TH::array" => "0.914",
  "Data::Sah::Compiler::perl::TH::bool" => "0.914",
  "Data::Sah::Compiler::perl::TH::float" => "0.914",
  "Data::Sah::Compiler::perl::TH::int" => "0.914",
  "Data::Sah::Compiler::perl::TH::str" => "0.914",
  "Exporter" => "5.57",
  "File::Slurper" => 0,
  "File::Spec" => 0,
  "File::Temp" => "0.2307",
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.038",
  "Math::Round" => 0,
  "Number::Format" => 0,
  "Org::To::ANSIText" => 0,
  "Org::To::HTML" => "0.18",
  "Org::To::Text" => "0.050",
  "Perinci::CmdLine::Any" => "0.154",
  "Perinci::CmdLine::Lite" => "1.924",
  "Perinci::Sub::Gen::AccessTable" => "0.590",
  "Perinci::Sub::Property::result::table" => 0,
  "Sah::Schema::true" => 0,
  "Sah::Schema::ufloat" => 0,
  "Test::More" => 0,
  "Text::Table::HTML" => "0.008",
  "Text::Table::More" => 0,
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

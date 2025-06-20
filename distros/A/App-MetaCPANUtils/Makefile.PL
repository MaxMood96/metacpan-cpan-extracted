# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.028.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "CLI utilities related to MetaCPAN",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-MetaCPANUtils",
  "EXE_FILES" => [
    "script/diff-metacpan-releases",
    "script/download-metacpan-release",
    "script/list-metacpan-distribution-versions",
    "script/list-metacpan-distributions",
    "script/list-metacpan-releases",
    "script/list-recent-metacpan-releases",
    "script/open-metacpan-dist-page",
    "script/open-metacpan-module-page"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::MetaCPANUtils",
  "PREREQ_PM" => {
    "App::DiffTarballs" => 0,
    "Browser::Open" => 0,
    "Data::Sah::Coerce::perl::To_date::From_float::epoch" => 0,
    "Data::Sah::Coerce::perl::To_date::From_obj::datetime" => 0,
    "Data::Sah::Coerce::perl::To_date::From_obj::time_moment" => 0,
    "Data::Sah::Coerce::perl::To_date::From_str::iso8601" => 0,
    "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_distname" => 0,
    "Data::Sah::Coerce::perl::To_str::From_str::to_upper" => 0,
    "Data::Sah::Compiler::perl::TH::array" => "0.914",
    "Data::Sah::Compiler::perl::TH::bool" => "0.914",
    "Data::Sah::Compiler::perl::TH::date" => "0.914",
    "Data::Sah::Compiler::perl::TH::int" => "0.914",
    "Data::Sah::Compiler::perl::TH::str" => "0.914",
    "Data::Sah::Filter::perl::Perl::check_module_release_expr" => 0,
    "Data::Sah::Filter::perl::Perl::normalize_perl_modname" => 0,
    "File::Temp" => "0.2307",
    "File::chdir" => 0,
    "HTTP::Tiny::Plugin" => "0.004",
    "Log::ger" => "0.038",
    "MetaCPAN::Client" => 0,
    "Module::Release::Select" => 0,
    "Perinci::CmdLine::Any" => "0.154",
    "Perinci::CmdLine::Lite" => "1.924",
    "Sah::Schema::cpan::distname" => 0,
    "Sah::Schema::cpan::pause_id" => "0.003",
    "Sah::Schema::perl::distname" => 0,
    "Sah::Schema::perl::modname" => "0.035",
    "Sah::Schema::perl::module::release::version" => 0,
    "Sah::Schema::posint" => 0,
    "Sah::Schema::true" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.007",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "App::DiffTarballs" => 0,
  "Browser::Open" => 0,
  "Data::Sah::Coerce::perl::To_date::From_float::epoch" => 0,
  "Data::Sah::Coerce::perl::To_date::From_obj::datetime" => 0,
  "Data::Sah::Coerce::perl::To_date::From_obj::time_moment" => 0,
  "Data::Sah::Coerce::perl::To_date::From_str::iso8601" => 0,
  "Data::Sah::Coerce::perl::To_str::From_str::normalize_perl_distname" => 0,
  "Data::Sah::Coerce::perl::To_str::From_str::to_upper" => 0,
  "Data::Sah::Compiler::perl::TH::array" => "0.914",
  "Data::Sah::Compiler::perl::TH::bool" => "0.914",
  "Data::Sah::Compiler::perl::TH::date" => "0.914",
  "Data::Sah::Compiler::perl::TH::int" => "0.914",
  "Data::Sah::Compiler::perl::TH::str" => "0.914",
  "Data::Sah::Filter::perl::Perl::check_module_release_expr" => 0,
  "Data::Sah::Filter::perl::Perl::normalize_perl_modname" => 0,
  "File::Spec" => 0,
  "File::Temp" => "0.2307",
  "File::chdir" => 0,
  "HTTP::Tiny::Plugin" => "0.004",
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.038",
  "MetaCPAN::Client" => 0,
  "Module::Release::Select" => 0,
  "Perinci::CmdLine::Any" => "0.154",
  "Perinci::CmdLine::Lite" => "1.924",
  "Sah::Schema::cpan::distname" => 0,
  "Sah::Schema::cpan::pause_id" => "0.003",
  "Sah::Schema::perl::distname" => 0,
  "Sah::Schema::perl::modname" => "0.035",
  "Sah::Schema::perl::module::release::version" => 0,
  "Sah::Schema::posint" => 0,
  "Sah::Schema::true" => 0,
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

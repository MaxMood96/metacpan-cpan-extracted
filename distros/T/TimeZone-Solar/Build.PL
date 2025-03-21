
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.025.
use strict;
use warnings;

use Module::Build 0.28;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28"
  },
  "configure_requires" => {
    "Module::Build" => "0.28"
  },
  "dist_abstract" => "local solar timezone lookup and utilities including DateTime compatibility",
  "dist_author" => [
    "Ian Kluft <ian.kluft+github\@gmail.com>"
  ],
  "dist_name" => "TimeZone-Solar",
  "dist_version" => "0.2.2",
  "license" => "perl",
  "module_name" => "TimeZone::Solar",
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "DateTime::TimeZone" => "v0.80.0",
    "Modern::Perl" => 0,
    "Readonly" => 0,
    "Try::Tiny" => 0,
    "autodie" => 0,
    "feature" => 0,
    "overload" => 0,
    "perl" => "v5.20.0",
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "script_files" => [
    "bin/gen-ltz.pl"
  ],
  "test_requires" => {
    "DateTime" => 0,
    "IO::File" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "DateTime" => 0,
  "IO::File" => 0,
  "Module::Build" => "0.28",
  "Test::Exception" => 0,
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

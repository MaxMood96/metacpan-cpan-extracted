
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.017.
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
  "dist_abstract" => "run ALL the apps via Bread::Board",
  "dist_author" => [
    "Thomas Klausner <domm\@plix.at>"
  ],
  "dist_name" => "Bread-Runner",
  "dist_version" => "0.905",
  "license" => "perl",
  "module_name" => "Bread::Runner",
  "recursive_test_files" => 1,
  "requires" => {
    "Bread::Board" => 0,
    "Carp" => 0,
    "Getopt::Long" => 0,
    "Log::Any" => 0,
    "Module::Runtime" => 0,
    "Scalar::Util" => 0,
    "Try::Tiny" => 0,
    "perl" => "5.020"
  },
  "test_requires" => {
    "File::Spec" => 0,
    "File::Temp" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Log::Any::Test" => 0,
    "Moose" => 0,
    "Test::More" => 0,
    "Test::Most" => 0,
    "lib" => 0
  }
);


my %fallback_build_requires = (
  "File::Spec" => 0,
  "File::Temp" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::Any::Test" => 0,
  "Module::Build" => "0.28",
  "Moose" => 0,
  "Test::More" => 0,
  "Test::Most" => 0,
  "lib" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

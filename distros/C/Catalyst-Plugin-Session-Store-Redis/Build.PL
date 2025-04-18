
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.032.
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
  "dist_abstract" => "Redis Session store for Catalyst",
  "dist_author" => [
    "Thomas Klausner <domm\@plix.at>"
  ],
  "dist_name" => "Catalyst-Plugin-Session-Store-Redis",
  "dist_version" => "0.901",
  "license" => "perl",
  "module_name" => "Catalyst::Plugin::Session::Store::Redis",
  "recursive_test_files" => 1,
  "requires" => {
    "Catalyst::Plugin::Session::Store" => 0,
    "Class::Data::Inheritable" => 0,
    "MIME::Base64" => 0,
    "MRO::Compat" => 0,
    "Redis" => 0,
    "Storable" => 0,
    "Try::Tiny" => 0,
    "base" => 0
  },
  "test_requires" => {
    "Catalyst" => 0,
    "Catalyst::Plugin::Session::Test::Store" => 0,
    "Catalyst::Test" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "FindBin" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0,
    "lib" => 0,
    "perl" => "5.006"
  }
);


my %fallback_build_requires = (
  "Catalyst" => 0,
  "Catalyst::Plugin::Session::Test::Store" => 0,
  "Catalyst::Test" => 0,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "FindBin" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Test::More" => 0,
  "lib" => 0,
  "perl" => "5.006"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

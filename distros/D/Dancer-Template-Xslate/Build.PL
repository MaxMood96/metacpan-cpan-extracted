
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.031.
use strict;
use warnings;

use Module::Build 0.28;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28"
  },
  "configure_requires" => {
    "Module::Build" => "0.28",
    "perl" => "5.006"
  },
  "dist_abstract" => "Text::Xslate wrapper for Dancer",
  "dist_author" => [
    "franck cuny <franck\@lumberjaph.net>"
  ],
  "dist_name" => "Dancer-Template-Xslate",
  "dist_version" => "0.04",
  "license" => "perl",
  "module_name" => "Dancer::Template::Xslate",
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Dancer::App" => 0,
    "Dancer::Template::Abstract" => 0,
    "File::Spec::Functions" => 0,
    "Text::Xslate" => 0,
    "base" => 0,
    "perl" => "5.006",
    "strict" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "Dancer" => 0,
    "Dancer::Test" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0,
    "lib" => 0,
    "perl" => "5.006"
  }
);


my %fallback_build_requires = (
  "Dancer" => 0,
  "Dancer::Test" => 0,
  "File::Spec" => 0,
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

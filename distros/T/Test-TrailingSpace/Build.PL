
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.017.
use strict;
use warnings;

use Module::Build 0.28;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28"
  },
  "configure_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.28"
  },
  "dist_abstract" => "test for trailing space in source files.",
  "dist_author" => [
    "Shlomi Fish <shlomif\@cpan.org>"
  ],
  "dist_name" => "Test-TrailingSpace",
  "dist_version" => "0.0601",
  "license" => "mit",
  "module_name" => "Test::TrailingSpace",
  "recursive_test_files" => 1,
  "requires" => {
    "File::Find::Object::Rule" => "0.0301",
    "Test::More" => "0.88",
    "autodie" => 0,
    "perl" => "5.014",
    "strict" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "File::Path" => 0,
    "File::Spec" => 0,
    "File::TreeCreate" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::Builder::Tester" => 0,
    "Test::More" => "0.88"
  }
);


my %fallback_build_requires = (
  "File::Path" => 0,
  "File::Spec" => 0,
  "File::TreeCreate" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Test::Builder::Tester" => 0,
  "Test::More" => "0.88"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;


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
  "dist_abstract" => "a fast, middleweight template engine.",
  "dist_author" => [
    "Kathryn Andersen <perlkat\@katspace.org>"
  ],
  "dist_name" => "Text-NeatTemplate",
  "dist_version" => "0.1600",
  "license" => "perl",
  "module_name" => "Text::NeatTemplate",
  "recursive_test_files" => 1,
  "requires" => {
    "File::Basename" => 0,
    "File::Slurper" => 0,
    "Getopt::Long" => "2.34",
    "Pod::Usage" => 0,
    "YAML::Any" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [
    "scripts/neat_template"
  ],
  "test_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0,
    "perl" => "5.006"
  }
);


my %fallback_build_requires = (
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Test::More" => 0,
  "perl" => "5.006"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

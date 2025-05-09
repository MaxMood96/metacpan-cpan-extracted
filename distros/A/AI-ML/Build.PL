
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.010.
use strict;
use warnings;

use Module::Build 0.28;
use lib qw{inc}; use MyBuilder;

my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28"
  },
  "configure_requires" => {
    "Module::Build" => "0.28"
  },
  "dist_abstract" => "Perl interface to ML",
  "dist_author" => [
    "Rui Meira <ruimiguelcm96\@gmail.com>"
  ],
  "dist_name" => "AI-ML",
  "dist_version" => "0.001",
  "license" => "perl",
  "module_name" => "AI::ML",
  "recursive_test_files" => 1,
  "test_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test2::V0" => "0.000060",
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Module::Build" => "0.28",
  "Test2::V0" => "0.000060",
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = MyBuilder->new(%module_build_args);


$build->create_build_script;

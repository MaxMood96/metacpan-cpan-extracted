
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.012.
use strict;
use warnings;

use Module::Build 0.28;
use lib qw{inc}; use My::Build;

my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28"
  },
  "configure_requires" => {
    "Module::Build" => "0.28",
    "Module::Build::WithXSpp" => 0
  },
  "dist_abstract" => "Perl bindings for Japanese Geocoder DAMS",
  "dist_author" => [
    "Tomohiro Hosaka <bokutin\@bokut.in>"
  ],
  "dist_name" => "Geo-Coder-DAMS",
  "dist_version" => "0.01",
  "license" => "perl",
  "module_name" => "Geo::Coder::DAMS",
  "recursive_test_files" => 1,
  "test_requires" => {
    "Test::Exception" => 0,
    "Test::LeakTrace" => 0
  }
);


my %fallback_build_requires = (
  "Module::Build" => "0.28",
  "Test::Exception" => 0,
  "Test::LeakTrace" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = My::Build->new(%module_build_args);


$build->create_build_script;

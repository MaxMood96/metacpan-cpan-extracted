
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.012.
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
  "dist_abstract" => "Set the buffersize of a handle",
  "dist_author" => [
    "Leon Timmermans <leont\@cpan.org>"
  ],
  "dist_name" => "PerlIO-buffersize",
  "dist_version" => "0.002",
  "license" => "perl",
  "module_name" => "PerlIO::buffersize",
  "recursive_test_files" => 1,
  "requires" => {
    "XSLoader" => 0,
    "perl" => "5.008",
    "strict" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "PerlIO::Layers" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "Module::Build" => "0.28",
  "PerlIO::Layers" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

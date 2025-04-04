
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v5.044.
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
  "dist_abstract" => "Provide various of file operation",
  "dist_author" => [
    "Yan Xueqing <yanxueqing621\@163.com>"
  ],
  "dist_name" => "File-Utils",
  "dist_version" => "0.0.5",
  "license" => "perl",
  "module_name" => "File::Utils",
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Exporter" => 0,
    "Modern::Perl" => 0,
    "PerlIO::gzip" => 0
  },
  "test_requires" => {
    "File::Temp" => 0,
    "Test::More" => 0,
    "Test::Pod" => 0,
    "Test::Pod::Coverage" => "1.00"
  }
);


my %fallback_build_requires = (
  "File::Temp" => 0,
  "Module::Build" => "0.28",
  "Test::More" => 0,
  "Test::Pod" => 0,
  "Test::Pod::Coverage" => "1.00"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

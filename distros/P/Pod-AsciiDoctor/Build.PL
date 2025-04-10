
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.031.
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
  "dist_abstract" => "Convert from POD to AsciiDoc",
  "dist_author" => [
    "Shlomi Fish <shlomif\@cpan.org>"
  ],
  "dist_name" => "Pod-AsciiDoctor",
  "dist_version" => "0.102002",
  "license" => "apache",
  "module_name" => "Pod::AsciiDoctor",
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Getopt::Long" => 0,
    "Path::Tiny" => 0,
    "Pod::Parser" => "1.65",
    "autodie" => 0,
    "parent" => 0,
    "perl" => "5.014",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => [
    "bin/pod2asciidoctor"
  ],
  "test_requires" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.88"
  }
);


my %fallback_build_requires = (
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Test::More" => "0.88"
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

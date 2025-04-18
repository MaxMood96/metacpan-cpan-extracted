
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.024.
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
  "dist_abstract" => "compare two XML files for equivalency, in an ordered fashion.",
  "dist_author" => [
    "Shlomi Fish <shlomif\@cpan.org>"
  ],
  "dist_name" => "Test-XML-Ordered",
  "dist_version" => "0.2.2",
  "license" => "mit",
  "module_name" => "Test::XML::Ordered",
  "recursive_test_files" => 1,
  "requires" => {
    "Exporter" => 0,
    "Test::More" => "0.88",
    "XML::LibXML" => "2.0014",
    "XML::LibXML::Reader" => "2.0014",
    "base" => 0,
    "perl" => "5.010",
    "strict" => 0,
    "vars" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::Builder::Tester" => 0,
    "Test::More" => "0.88"
  }
);


my %fallback_build_requires = (
  "File::Spec" => 0,
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

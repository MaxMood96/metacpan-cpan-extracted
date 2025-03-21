
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
  "dist_abstract" => "Provides syndication for a set of XML-Grammar-Fortune files.",
  "dist_author" => [
    "Shlomi Fish <shlomif\@cpan.org>"
  ],
  "dist_name" => "XML-Grammar-Fortune-Synd",
  "dist_version" => "0.0400",
  "license" => "mit",
  "module_name" => "XML::Grammar::Fortune::Synd",
  "recursive_test_files" => 1,
  "requires" => {
    "Class::Accessor" => 0,
    "DateTime::Format::W3CDTF" => 0,
    "Exporter" => 0,
    "File::Spec" => 0,
    "File::Update" => 0,
    "Getopt::Long" => 0,
    "Heap::Binary" => 0,
    "Heap::Elem::Ref" => 0,
    "Path::Tiny" => 0,
    "XML::Feed" => 0,
    "XML::Grammar::Fortune" => 0,
    "YAML::XS" => 0,
    "parent" => 0,
    "perl" => "5.008",
    "strict" => 0,
    "vars" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "File::Spec" => 0,
    "File::Temp" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "List::Util" => 0,
    "Test::More" => "0.88",
    "XML::LibXML" => 0,
    "XML::RSS" => 0,
    "autodie" => 0,
    "base" => 0,
    "lib" => 0
  }
);


my %fallback_build_requires = (
  "File::Spec" => 0,
  "File::Temp" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "List::Util" => 0,
  "Module::Build" => "0.28",
  "Test::More" => "0.88",
  "XML::LibXML" => 0,
  "XML::RSS" => 0,
  "autodie" => 0,
  "base" => 0,
  "lib" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;


# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.030.
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "web application for content management",
  "dist_author" => [
    "Kathryn Andersen <perlkat\@katspace.org>"
  ],
  "dist_name" => "Muster",
  "dist_version" => "0.92",
  "license" => "perl",
  "module_name" => "Muster",
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Const::Fast" => 0,
    "DBI" => 0,
    "DateTime" => 0,
    "Digest::SHA" => 0,
    "Encode" => 0,
    "File::Basename" => 0,
    "File::Find" => 0,
    "File::LibMagic" => 0,
    "File::MimeInfo::Magic" => 0,
    "File::ShareDir" => 0,
    "File::Slurper" => 0,
    "File::Spec" => 0,
    "File::stat" => 0,
    "HTML::LinkList" => 0,
    "Hash::Merge" => 0,
    "Image::ExifTool" => 0,
    "Image::Magick" => 0,
    "Lingua::EN::Inflexion" => 0,
    "Lingua::EN::Titlecase" => 0,
    "Math::Calc::Parser" => 0,
    "Module::Pluggable" => 0,
    "Mojo::Base" => 0,
    "Mojo::URL" => 0,
    "Mojo::Util" => 0,
    "Mojolicious::Commands" => 0,
    "POSIX" => 0,
    "Path::Tiny" => 0,
    "SQLite::Work" => 0,
    "Search::Query" => 0,
    "Sort::Naturally" => 0,
    "Text::Markdown::Discount" => 0,
    "Text::NeatTemplate" => 0,
    "YAML" => 0,
    "YAML::Any" => 0,
    "YAML::XS" => 0,
    "common::sense" => 0
  },
  "script_files" => [
    "scripts/muster"
  ],
  "share_dir" => {
    "dist" => "public"
  },
  "test_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::Mojo" => 0,
    "Test::More" => 0,
    "perl" => "5.006",
    "strict" => 0,
    "warnings" => 0
  }
);


my %fallback_build_requires = (
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.3601",
  "Test::Mojo" => 0,
  "Test::More" => 0,
  "perl" => "5.006",
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

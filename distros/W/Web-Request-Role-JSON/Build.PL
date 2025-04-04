
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.017.
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
  "dist_abstract" => "Make handling JSON easier in Web::Request",
  "dist_author" => [
    "Thomas Klausner <domm\@plix.at>",
    "Klaus Ita <koki\@itascraft.com>"
  ],
  "dist_name" => "Web-Request-Role-JSON",
  "dist_version" => "1.008",
  "license" => "perl",
  "module_name" => "Web::Request::Role::JSON",
  "recursive_test_files" => 1,
  "requires" => {
    "Encode" => 0,
    "JSON::MaybeXS" => 0,
    "MooseX::Role::Parameterized" => 0,
    "perl" => "5.010"
  },
  "test_requires" => {
    "File::Spec" => 0,
    "File::Temp" => 0,
    "HTTP::Request" => 0,
    "HTTP::Request::Common" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Moose" => 0,
    "Plack::Builder" => 0,
    "Plack::Test" => 0,
    "Test::More" => 0,
    "Web::Request" => 0
  }
);


my %fallback_build_requires = (
  "File::Spec" => 0,
  "File::Temp" => 0,
  "HTTP::Request" => 0,
  "HTTP::Request::Common" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Moose" => 0,
  "Plack::Builder" => 0,
  "Plack::Test" => 0,
  "Test::More" => 0,
  "Web::Request" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

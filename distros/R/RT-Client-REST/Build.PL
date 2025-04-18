
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v6.029.
use strict;
use warnings;

use Module::Build 0.28;


my %module_build_args = (
  "build_requires" => {
    "HTTP::Server::Simple" => "0.44",
    "HTTP::Server::Simple::CGI" => 0,
    "HTTP::Server::Simple::CGI::Environment" => 0,
    "Module::Build" => "0.28",
    "Test::Exception" => 0,
    "Test::More" => 0
  },
  "configure_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.28"
  },
  "dist_abstract" => "Client for RT using REST API",
  "dist_author" => [
    "Dean Hamstead <dean\@fragfest.com.au>"
  ],
  "dist_name" => "RT-Client-REST",
  "dist_version" => "0.72",
  "license" => "perl",
  "module_name" => "RT::Client::REST",
  "recursive_test_files" => 1,
  "requires" => {
    "DateTime" => 0,
    "DateTime::Format::DateParse" => 0,
    "Encode" => 0,
    "Exception::Class" => 0,
    "Exporter" => 0,
    "HTTP::Cookies" => 0,
    "HTTP::Request::Common" => 0,
    "LWP" => 0,
    "Params::Validate" => 0,
    "Try::Tiny" => 0,
    "URI" => 0,
    "constant" => 0,
    "parent" => 0,
    "perl" => "5.008",
    "strict" => 0,
    "vars" => 0,
    "warnings" => 0
  },
  "test_requires" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  }
);


my %fallback_build_requires = (
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "HTTP::Server::Simple" => "0.44",
  "HTTP::Server::Simple::CGI" => 0,
  "HTTP::Server::Simple::CGI::Environment" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Test::Exception" => 0,
  "Test::More" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);


$build->create_build_script;

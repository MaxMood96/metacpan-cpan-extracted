# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.026000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Export a subset of installed system files, for initrd or containers",
  "AUTHOR" => "Michael Conrad <mike\@nrdvana.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Sys-Export",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.026000",
  "NAME" => "Sys::Export",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Cwd" => 0,
    "Exporter" => 0,
    "Fcntl" => 0,
    "File::Spec::Functions" => 0,
    "File::Temp" => 0,
    "IPC::Open3" => 0,
    "Module::Runtime" => 0,
    "POSIX" => 0,
    "Scalar::Util" => 0,
    "Storable" => 0,
    "Symbol" => 0,
    "User::pwent" => 0,
    "experimental" => 0,
    "integer" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::stat" => 0,
    "IO::Handle" => 0,
    "Test2::Suite" => "0.000139",
    "Test2::Tools::Subtest" => 0,
    "Test2::V0" => 0,
    "autodie" => 0,
    "lib" => 0
  },
  "VERSION" => "0.001",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Cwd" => 0,
  "Exporter" => 0,
  "Fcntl" => 0,
  "File::Spec::Functions" => 0,
  "File::Temp" => 0,
  "File::stat" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Runtime" => 0,
  "POSIX" => 0,
  "Scalar::Util" => 0,
  "Storable" => 0,
  "Symbol" => 0,
  "Test2::Suite" => "0.000139",
  "Test2::Tools::Subtest" => 0,
  "Test2::V0" => 0,
  "User::pwent" => 0,
  "autodie" => 0,
  "experimental" => 0,
  "integer" => 0,
  "lib" => 0,
  "parent" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

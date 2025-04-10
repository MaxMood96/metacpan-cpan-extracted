# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Read and write IOD/INI configuration files",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Config-IOD",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Config::IOD",
  "PREREQ_PM" => {
    "Config::IOD::Base" => "0.344",
    "Exporter" => "5.57",
    "Test::Differences" => 0,
    "Test::Exception" => 0,
    "Test::More" => "0.98",
    "constant" => 0,
    "overload" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::ShareDir::Tarball" => 0,
    "File::Slurper" => 0,
    "File::Spec" => 0,
    "File::Temp" => "0.2307",
    "IO::Handle" => 0,
    "IOD::Examples" => "0.201",
    "IPC::Open3" => 0,
    "Test::Config::IOD::Common" => 0,
    "Test::More" => "0.98"
  },
  "VERSION" => "0.353",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Config::IOD::Base" => "0.344",
  "Exporter" => "5.57",
  "File::ShareDir::Tarball" => 0,
  "File::Slurper" => 0,
  "File::Spec" => 0,
  "File::Temp" => "0.2307",
  "IO::Handle" => 0,
  "IOD::Examples" => "0.201",
  "IPC::Open3" => 0,
  "Test::Config::IOD::Common" => 0,
  "Test::Differences" => 0,
  "Test::Exception" => 0,
  "Test::More" => "0.98",
  "constant" => 0,
  "overload" => 0,
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

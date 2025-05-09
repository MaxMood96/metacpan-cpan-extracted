# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.029.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "An OOP interface to Monit.",
  "AUTHOR" => "Angelo Failla <pallotron\@gmail.com>, Dean Hamstead <dean\@fragfest.com.au>",
  "BUILD_REQUIRES" => {
    "Module::Build" => "0.28",
    "Test::MockModule" => 0,
    "Test::More" => 0,
    "Test::Trap" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.28"
  },
  "DISTNAME" => "Monit-HTTP",
  "LICENSE" => "mit",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Monit::HTTP",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Exporter" => 0,
    "HTTP::Tiny" => 0,
    "XML::Fast" => 0,
    "constant" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.06",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "HTTP::Tiny" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.28",
  "Test::MockModule" => 0,
  "Test::More" => 0,
  "Test::Trap" => 0,
  "XML::Fast" => 0,
  "constant" => 0,
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

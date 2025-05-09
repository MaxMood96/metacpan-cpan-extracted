# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.020;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Install OTRS add ons",
  "AUTHOR" => "Renee Baecker <reneeb\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "OTRS-OPM-Installer",
  "EXE_FILES" => [
    "bin/ooi"
  ],
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.020",
  "NAME" => "OTRS::OPM::Installer",
  "PREREQ_PM" => {
    "App::cpanminus" => 0,
    "Capture::Tiny" => 0,
    "File::Basename" => 0,
    "File::HomeDir" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "HTTP::Tiny" => 0,
    "HTTP::Tiny::FileProtocol" => "0.02",
    "IO::All" => 0,
    "Module::Path" => 0,
    "Moo" => 0,
    "OTRS::OPM::Parser" => "1.05",
    "OTRS::Repository" => "0.08",
    "Regexp::Common" => 0,
    "Test::More" => 0,
    "Type::Tiny" => 0,
    "Types::Standard" => 0
  },
  "VERSION" => "0.05",
  "test" => {
    "TESTS" => "t/config/*.t t/file/*.t t/functions/*.t t/installer/*.t t/logger/*.t t/otrs/*.t"
  }
);


my %FallbackPrereqs = (
  "App::cpanminus" => 0,
  "Capture::Tiny" => 0,
  "File::Basename" => 0,
  "File::HomeDir" => 0,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "HTTP::Tiny" => 0,
  "HTTP::Tiny::FileProtocol" => "0.02",
  "IO::All" => 0,
  "Module::Path" => 0,
  "Moo" => 0,
  "OTRS::OPM::Parser" => "1.05",
  "OTRS::Repository" => "0.08",
  "Regexp::Common" => 0,
  "Test::More" => 0,
  "Type::Tiny" => 0,
  "Types::Standard" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

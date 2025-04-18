# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.028.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Display a calendar, with highlighted dates",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "App-calx",
  "EXE_FILES" => [
    "script/calx"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "App::calx",
  "PREREQ_PM" => {
    "Color::ANSI::Util" => "0.164",
    "Color::RGB::Util" => "0.600",
    "DateTime" => 0,
    "Getopt::Long" => "2.50",
    "List::Util" => "1.54",
    "Module::List::Tiny" => 0,
    "Text::ANSI::Util" => "0.22",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.009",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Color::ANSI::Util" => "0.164",
  "Color::RGB::Util" => "0.600",
  "DateTime" => 0,
  "File::Spec" => 0,
  "Getopt::Long" => "2.50",
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "List::Util" => "1.54",
  "Module::List::Tiny" => 0,
  "Test::More" => 0,
  "Text::ANSI::Util" => "0.22",
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

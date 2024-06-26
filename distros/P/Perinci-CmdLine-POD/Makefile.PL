# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Generate POD for Perinci::CmdLine-based CLI script",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Perinci-CmdLine-POD",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Perinci::CmdLine::POD",
  "PREREQ_PM" => {
    "Data::Dmp" => "0.242",
    "Data::Sah::Terse" => 0,
    "Exporter" => "5.57",
    "IPC::System::Options" => "0.339",
    "Lingua::EN::Numbers::Ordinate" => 0,
    "Log::ger" => "0.038",
    "Markdown::To::POD" => 0,
    "Perinci::Access::Perl" => "0.895",
    "Perinci::CmdLine::Dump" => "0.120",
    "Perinci::CmdLine::Lite" => "1.924",
    "Perinci::Result::Format::Lite" => "0.286",
    "Perinci::Sub::To::CLIDocData" => "0.304",
    "Proc::ChildError" => 0,
    "String::PodQuote" => 0,
    "String::ShellQuote" => 0,
    "Text::Wrap" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.039",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Data::Dmp" => "0.242",
  "Data::Sah::Terse" => 0,
  "Exporter" => "5.57",
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "IPC::System::Options" => "0.339",
  "Lingua::EN::Numbers::Ordinate" => 0,
  "Log::ger" => "0.038",
  "Markdown::To::POD" => 0,
  "Perinci::Access::Perl" => "0.895",
  "Perinci::CmdLine::Dump" => "0.120",
  "Perinci::CmdLine::Lite" => "1.924",
  "Perinci::Result::Format::Lite" => "0.286",
  "Perinci::Sub::To::CLIDocData" => "0.304",
  "Proc::ChildError" => 0,
  "String::PodQuote" => 0,
  "String::ShellQuote" => 0,
  "Test::More" => 0,
  "Text::Wrap" => 0,
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

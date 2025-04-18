# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "simple email creation with auto text and html multipart body",
  "AUTHOR" => "Yanick Champoux <yanick\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Email-Simple-Markdown",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Email::Simple::Markdown",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Email::Abstract" => 0,
    "Email::MIME" => 0,
    "Email::Simple" => 0,
    "Exporter" => 0,
    "List::Util" => "1.29",
    "Module::Runtime" => 0,
    "Moo" => 0,
    "Moo::Role" => 0,
    "Role::Tiny" => 0,
    "Text::MultiMarkdown" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test2::V0" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.7.3",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Email::Abstract" => 0,
  "Email::MIME" => 0,
  "Email::Simple" => 0,
  "Exporter" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "List::Util" => "1.29",
  "Module::Runtime" => 0,
  "Moo" => 0,
  "Moo::Role" => 0,
  "Role::Tiny" => 0,
  "Test2::V0" => 0,
  "Test::More" => 0,
  "Text::MultiMarkdown" => 0,
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

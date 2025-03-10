# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.029.
use strict;
use warnings;

use 5.012;

use ExtUtils::MakeMaker 6.78;

my %WriteMakefileArgs = (
  "ABSTRACT" => "render parts of your mail with Text::Template",
  "AUTHOR" => "Ricardo Signes <cpan\@semiotic.systems>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.78"
  },
  "DISTNAME" => "Email-MIME-Kit-Renderer-Text-Template",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.012",
  "NAME" => "Email::MIME::Kit::Renderer::Text::Template",
  "PREREQ_PM" => {
    "Email::MIME::Kit" => 2,
    "Email::MIME::Kit::Role::Renderer" => 0,
    "Module::Runtime" => 0,
    "Moose" => 0,
    "Text::Template" => 0
  },
  "TEST_REQUIRES" => {
    "Email::MIME::Kit" => 2,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => "0.96",
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "1.101304",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Email::MIME::Kit" => 2,
  "Email::MIME::Kit::Role::Renderer" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Module::Runtime" => 0,
  "Moose" => 0,
  "Test::More" => "0.96",
  "Text::Template" => 0,
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

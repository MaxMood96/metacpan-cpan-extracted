# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.028.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Encode to colored JSON",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "JSON-Color",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "JSON::Color",
  "PREREQ_PM" => {
    "Color::ANSI::Util" => "0.164",
    "ColorTheme::NoColor" => 0,
    "ColorThemeBase::Static::FromStructColors" => "0.006",
    "ColorThemeRole::ANSI" => 0,
    "Exporter" => "5.57",
    "Graphics::ColorNamesLite::WWW" => 0,
    "Module::Load::Util" => "0.009",
    "Role::Tiny" => 0,
    "Term::ANSIColor" => "3.00",
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.98"
  },
  "VERSION" => "0.134",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Color::ANSI::Util" => "0.164",
  "ColorTheme::NoColor" => 0,
  "ColorThemeBase::Static::FromStructColors" => "0.006",
  "ColorThemeRole::ANSI" => 0,
  "Exporter" => "5.57",
  "File::Spec" => 0,
  "Graphics::ColorNamesLite::WWW" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Load::Util" => "0.009",
  "Role::Tiny" => 0,
  "Term::ANSIColor" => "3.00",
  "Test::More" => "0.98",
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

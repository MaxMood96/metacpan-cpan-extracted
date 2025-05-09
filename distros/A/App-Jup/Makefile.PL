# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.008.
use strict;
use warnings;



use ExtUtils::MakeMaker;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "Global Jup options",
  "AUTHOR" => "Adam Stokes <adamjs\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30",
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "App-Jup",
  "EXE_FILES" => [
    "bin/jup"
  ],
  "LICENSE" => "perl",
  "NAME" => "App::Jup",
  "PREREQ_PM" => {
    "App::CharmKit" => 0,
    "App::Cmd::Setup" => 0,
    "Carp" => 0,
    "DDP" => 0,
    "Import::Into" => 0,
    "Modern::Perl" => 0,
    "Moo" => 0,
    "Moo::Role" => 0,
    "Pod::Markdown" => 0,
    "Pod::Weaver::Plugin::Exec" => 0,
    "bareword::filehandles" => 0,
    "indirect" => "0.16"
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "1.01",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "App::CharmKit" => 0,
  "App::Cmd::Setup" => 0,
  "Carp" => 0,
  "DDP" => 0,
  "Import::Into" => 0,
  "Modern::Perl" => 0,
  "Moo" => 0,
  "Moo::Role" => 0,
  "Pod::Markdown" => 0,
  "Pod::Weaver::Plugin::Exec" => 0,
  "Test::More" => 0,
  "bareword::filehandles" => 0,
  "indirect" => "0.16"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

{
package
MY;
use File::ShareDir::Install qw(postamble);
}

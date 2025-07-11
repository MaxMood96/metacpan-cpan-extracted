# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "Interface to the Delhi Metro Map.",
  "AUTHOR" => "Mohammad Sajid Anwar <mohammad.anwar\@yahoo.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::ShareDir::Install" => "0.13"
  },
  "DISTNAME" => "Map-Tube-Delhi",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Map::Tube::Delhi",
  "PREREQ_PM" => {
    "Data::Dumper" => 0,
    "File::ShareDir" => "1.114",
    "Map::Tube" => "4.07",
    "Moo" => "2.000000",
    "namespace::autoclean" => "0.28",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Test::Map::Tube" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.99",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Data::Dumper" => 0,
  "File::ShareDir" => "1.114",
  "Map::Tube" => "4.07",
  "Moo" => "2.000000",
  "Test::Map::Tube" => 0,
  "Test::More" => 0,
  "namespace::autoclean" => "0.28",
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

{
package
MY;
use File::ShareDir::Install qw(postamble);
}

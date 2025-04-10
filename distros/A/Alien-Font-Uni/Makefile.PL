# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.025.
use strict;
use warnings;

use 5.008000;

use ExtUtils::MakeMaker;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "access to Unifont truetype file",
  "AUTHOR" => "Herbert Breunung <lichtkind\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "Alien-Font-Uni",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008000",
  "NAME" => "Alien::Font::Uni",
  "PREREQ_PM" => {
    "File::ShareDir" => 1,
    "File::Spec" => 3
  },
  "TEST_REQUIRES" => {
    "Test::More" => "1.3"
  },
  "VERSION" => "0.3",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "File::ShareDir" => 1,
  "File::Spec" => 3,
  "Test::More" => "1.3"
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

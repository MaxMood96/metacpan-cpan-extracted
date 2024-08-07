# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.012;

use ExtUtils::MakeMaker 6.78;

use File::ShareDir::Install;
$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS = 1;
install_share dist => "share";


my %WriteMakefileArgs = (
  "ABSTRACT" => "data for mapping Slack :emoji_strings: into Unicode text",
  "AUTHOR" => "Ricardo Signes <cpan\@semiotic.systems>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.78",
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME" => "Text-SlackEmoji",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.012",
  "NAME" => "Text::SlackEmoji",
  "PREREQ_PM" => {
    "File::ShareDir" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::File::ShareDir" => 0,
    "Test::More" => "0.96",
    "utf8" => 0
  },
  "VERSION" => "0.010",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "ExtUtils::MakeMaker" => 0,
  "File::ShareDir" => 0,
  "File::Spec" => 0,
  "Test::File::ShareDir" => 0,
  "Test::More" => "0.96",
  "strict" => 0,
  "utf8" => 0,
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

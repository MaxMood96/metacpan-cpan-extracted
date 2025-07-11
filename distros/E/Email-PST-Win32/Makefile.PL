
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.031.
use strict;
use warnings;



use ExtUtils::MakeMaker;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Writing and updating PST files using Outlook Redemption on Windows ",
  "AUTHOR" => "John Wang <johncwang\@gmail.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Email-PST-Win32",
  "EXE_FILES" => [],
  "LICENSE" => "mit",
  "NAME" => "Email::PST::Win32",
  "PREREQ_PM" => {
    "Moose" => 0,
    "Try::Tiny" => 0,
    "Win32::OLE" => 0,
    "namespace::autoclean" => 0
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0,
    "strict" => 0
  },
  "VERSION" => "0.04",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "ExtUtils::MakeMaker" => 0,
  "Moose" => 0,
  "Test::More" => 0,
  "Try::Tiny" => 0,
  "Win32::OLE" => 0,
  "namespace::autoclean" => 0,
  "strict" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);




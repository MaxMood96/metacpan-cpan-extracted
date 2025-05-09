# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.024.
use strict;
use warnings;

use 5.010000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Create, modify, and examine PDF files",
  "AUTHOR" => "Steve Simms <steve\@deefs.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "PDF-API2",
  "LICENSE" => "lgpl",
  "MIN_PERL_VERSION" => "5.010000",
  "NAME" => "PDF::API2",
  "PREREQ_PM" => {
    "Compress::Zlib" => "1.0",
    "Font::TTF" => 0
  },
  "TEST_REQUIRES" => {
    "Test::Exception" => 0,
    "Test::Memory::Cycle" => 0
  },
  "VERSION" => "2.047",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Compress::Zlib" => "1.0",
  "Font::TTF" => 0,
  "Test::Exception" => 0,
  "Test::Memory::Cycle" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

if ( $^O eq 'MSWin32' ) {
	$WriteMakefileArgs{PREREQ_PM}{'Win32::TieRegistry'} = $FallbackPrereqs{'Win32::TieRegistry'} = '0';
}

WriteMakefile(%WriteMakefileArgs);

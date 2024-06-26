BEGIN {
  use strict; use warnings;
  unless(eval q{ use 5.008001; 1}) {
    print "Perl 5.008001 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.66.
use strict;
use warnings;
use 5.008001;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Fills in string templates from hash of fields",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>, Brian Duggan <bduggan\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "String-Template",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME"             => "String::Template",
  "PM"               => {
    "lib/String/Template.pm" => "\$(INST_LIB)/String/Template.pm"
  },
  "PREREQ_PM" => {
    "Date::Parse" => 0,
    "POSIX"       => 0
  },
  "TEST_REQUIRES" => {
    "Test2::V0"   => "0.000121",
    "Time::Piece" => "1.17"
  },
  "VERSION" => "0.23",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Date::Parse" => 0,
  "POSIX"       => 0,
  "Test2::V0"   => "0.000121",
  "Time::Piece" => "1.17"
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
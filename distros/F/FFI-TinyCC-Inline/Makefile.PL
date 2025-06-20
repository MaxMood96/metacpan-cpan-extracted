use strict; use warnings;
BEGIN {
  unless(eval q{ use 5.010; 1}) {
    print "Perl 5.010 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.26.
use strict;
use warnings;
use 5.010;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Embed Tiny C code in your Perl program",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "FFI-TinyCC-Inline",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME"             => "FFI::TinyCC::Inline",
  "PM"               => {
    "lib/FFI/TinyCC/Inline.pm" => "\$(INST_LIB)/FFI/TinyCC/Inline.pm"
  },
  "PREREQ_PM" => {
    "FFI::Platypus"                    => "0.15",
    "FFI::Platypus::Type::StringArray" => "0.01",
    "FFI::TinyCC"                      => "0.27",
    "base"                             => 0
  },
  "TEST_REQUIRES" => {
    "Test2::V0" => "0.000060"
  },
  "VERSION" => "0.28",
  "test"    => {
    "TESTS" => "t/*.t"
    }
);

my %FallbackPrereqs = (
  "FFI::Platypus"                    => "0.15",
  "FFI::Platypus::Type::StringArray" => "0.01",
  "FFI::TinyCC"                      => "0.27",
  "Test2::V0"                        => "0.000060",
  "base"                             => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
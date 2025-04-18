BEGIN {
  use strict; use warnings;
  unless(eval q{ use 5.008001; 1}) {
    print "Perl 5.008001 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.71.
use strict;
use warnings;
use 5.008001;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Alien::Build plugin to rewrite network requests to local resources",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "Alien-Build-Plugin-Fetch-Rewrite",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME"             => "Alien::Build::Plugin::Fetch::Rewrite",
  "PM"               => {
    "lib/Alien/Build/Plugin/Fetch/Rewrite.pm" => "\$(INST_LIB)/Alien/Build/Plugin/Fetch/Rewrite.pm"
  },
  "PREREQ_PM" => {
    "Alien::Build"                       => "0.62",
    "Alien::Build::Plugin::Decode::HTML" => 0,
    "Alien::Build::Plugin::Fetch::LWP"   => 0,
    "HTML::LinkExtor"                    => 0,
    "LWP::Protocol::https"               => 0,
    "LWP::UserAgent"                     => 0,
    "URI"                                => 0,
    "URI::Escape"                        => 0
  },
  "TEST_REQUIRES" => {
    "Capture::Tiny"      => 0,
    "Path::Tiny"         => 0,
    "Test2::Mock"        => "0.000121",
    "Test2::V0"          => "0.000121",
    "Test::Alien::Build" => 0
  },
  "VERSION" => "0.03",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Alien::Build"                       => "0.62",
  "Alien::Build::Plugin::Decode::HTML" => 0,
  "Alien::Build::Plugin::Fetch::LWP"   => 0,
  "Capture::Tiny"                      => 0,
  "HTML::LinkExtor"                    => 0,
  "LWP::Protocol::https"               => 0,
  "LWP::UserAgent"                     => 0,
  "Path::Tiny"                         => 0,
  "Test2::Mock"                        => "0.000121",
  "Test2::V0"                          => "0.000121",
  "Test::Alien::Build"                 => 0,
  "URI"                                => 0,
  "URI::Escape"                        => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
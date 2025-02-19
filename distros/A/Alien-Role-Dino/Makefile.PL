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
  "ABSTRACT"           => "Experimental support for dynamic share Alien install",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "Alien-Role-Dino",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME"             => "Alien::Role::Dino",
  "PM"               => {
    "lib/Alien/Build/Plugin/Gather/Dino.pm" => "\$(INST_LIB)/Alien/Build/Plugin/Gather/Dino.pm",
    "lib/Alien/Role/Dino.pm"                => "\$(INST_LIB)/Alien/Role/Dino.pm",
    "lib/Alien/Role/Dino/MSWin32.pm"        => "\$(INST_LIB)/Alien/Role/Dino/MSWin32.pm",
    "lib/Alien/Role/Dino/cygwin.pm"         => "\$(INST_LIB)/Alien/Role/Dino/cygwin.pm",
    "lib/Alien/Role/Dino/darwin.pm"         => "\$(INST_LIB)/Alien/Role/Dino/darwin.pm",
    "lib/Alien/Role/Dino/freebsd.pm"        => "\$(INST_LIB)/Alien/Role/Dino/freebsd.pm",
    "lib/Alien/Role/Dino/gnukfreebsd.pm"    => "\$(INST_LIB)/Alien/Role/Dino/gnukfreebsd.pm",
    "lib/Alien/Role/Dino/linux.pm"          => "\$(INST_LIB)/Alien/Role/Dino/linux.pm",
    "lib/Alien/Role/Dino/netbsd.pm"         => "\$(INST_LIB)/Alien/Role/Dino/netbsd.pm",
    "lib/Alien/Role/Dino/openbsd.pm"        => "\$(INST_LIB)/Alien/Role/Dino/openbsd.pm",
    "lib/Alien/Role/Dino/solaris.pm"        => "\$(INST_LIB)/Alien/Role/Dino/solaris.pm"
  },
  "PREREQ_PM" => {
    "Alien::Base"              => "0.99",
    "Alien::Build"             => "0.99",
    "Alien::Build::Plugin"     => 0,
    "Class::Method::Modifiers" => 0,
    "FFI::CheckLib"            => 0,
    "Path::Tiny"               => 0,
    "Role::Tiny"               => "1.003001"
  },
  "TEST_REQUIRES" => {
    "Alien::Base"        => "0.99",
    "Test2::Mock"        => "0.000121",
    "Test2::V0"          => "0.000121",
    "Test::Alien"        => "0.99",
    "Test::Alien::Build" => 0
  },
  "VERSION" => "0.08",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Alien::Base"              => "0.99",
  "Alien::Build"             => "0.99",
  "Alien::Build::Plugin"     => 0,
  "Class::Method::Modifiers" => 0,
  "FFI::CheckLib"            => 0,
  "Path::Tiny"               => 0,
  "Role::Tiny"               => "1.003001",
  "Test2::Mock"              => "0.000121",
  "Test2::V0"                => "0.000121",
  "Test::Alien"              => "0.99",
  "Test::Alien::Build"       => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
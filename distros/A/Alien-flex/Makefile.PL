BEGIN {
  use strict; use warnings;
  unless(eval q{ use 5.006; 1}) {
    print "Perl 5.006 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.69.
use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"       => "Find or build flex",
  "AUTHOR"         => "Graham Ollis <plicease\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Alien::Build"        => "0.32",
    "Alien::Build::MM"    => "0.32",
    "ExtUtils::MakeMaker" => "6.52"
  },
  "CONFIGURE_REQUIRES" => {
    "Alien::Build"                          => "0.32",
    "Alien::Build::MM"                      => "0.32",
    "Alien::Build::Plugin::Probe::GnuWin32" => 0,
    "ExtUtils::MakeMaker"                   => "6.52"
  },
  "DISTNAME"         => "Alien-flex",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME"             => "Alien::flex",
  "PM"               => {
    "lib/Alien/flex.pm" => "\$(INST_LIB)/Alien/flex.pm"
  },
  "PREREQ_PM" => {
    "Alien::Base" => "0.038"
  },
  "TEST_REQUIRES" => {
    "Test2::V0"         => "0.000121",
    "Test::Alien"       => 0,
    "Test::Alien::Diag" => 0,
    "Test::More"        => "0.98"
  },
  "VERSION" => "0.15",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Alien::Base"         => "0.038",
  "Alien::Build"        => "0.32",
  "Alien::Build::MM"    => "0.32",
  "ExtUtils::MakeMaker" => "6.52",
  "Test2::V0"           => "0.000121",
  "Test::Alien"         => 0,
  "Test::Alien::Diag"   => 0,
  "Test::More"          => "0.98"
);

# BEGIN code inserted by Dist::Zilla::Plugin::AlienBuild
use Alien::Build::MM;
my $abmm = Alien::Build::MM->new;
%WriteMakefileArgs = $abmm->mm_args(%WriteMakefileArgs);

# END code inserted by Dist::Zilla::Plugin::AlienBuild

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# BEGIN code inserted by Dist::Zilla::Plugin::AlienBuild
{ package
    MY;

  sub postamble {
    $abmm->mm_postamble(@_);
  }

  sub install {
    $abmm->can('mm_install')
      ? $abmm->mm_install(@_)
      : shift->SUPER::install(@_);
  }
}

# END code inserted by Dist::Zilla::Plugin::AlienBuild
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    "ABSTRACT"       => "Alien distribution for raylib",
    "AUTHOR"         => "Chris Prather <chris at prather.org>",
    "BUILD_REQUIRES" => {
        "Alien::Build"        => "0.32",
        "Alien::Build::MM"    => "0.32",
        "ExtUtils::MakeMaker" => "6.52"
    },
    "CONFIGURE_REQUIRES" => {
        "Alien::Build"                       => "0.32",
        "Alien::Build::MM"                   => "0.32",
        "Alien::Build::Plugin::Build::CMake" => "0.99",
        "ExtUtils::MakeMaker"                => "6.52"
    },
    "DISTNAME"         => "Alien-raylib5",
    "LICENSE"          => "perl",
    "MIN_PERL_VERSION" => "5.036",
    "NAME"             => "Alien::raylib5",
    "PREREQ_PM"        => {},
    "TEST_REQUIRES"    => {
        "Test::Simple"        => "1.302209",
        "ExtUtils::MakeMaker" => "6.52",
        "File::Spec"          => 0,
        "IO::Handle"          => 0,
        "IPC::Open3"          => 0,
        "Test::More"          => 0
    },
    "VERSION" => "0.03",
    "test"    => {
        "TESTS" => "t/*.t"
    }
);

my %FallbackPrereqs = (
    "Alien::Build"        => "0.32",
    "Alien::Build::MM"    => "0.32",
    "ExtUtils::MakeMaker" => "6.52",
    "File::Spec"          => 0,
    "IO::Handle"          => 0,
    "IPC::Open3"          => 0,
    "Test::More"          => 0
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
{
    package MY;

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

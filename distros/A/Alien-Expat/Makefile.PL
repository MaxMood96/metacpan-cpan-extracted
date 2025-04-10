BEGIN {
  use strict; use warnings;
  my %missing = map {
    eval qq{ require $_ };
    $@ ? ($_=>1) : ()
  } qw( base strict warnings );
  if(%missing)
  {
    print "Your Perl is missing core modules: @{[ sort keys %missing ]}\n";
    print "Ideally if you are using the system Perl you can install the appropriate\n";
    print "package which includes the core Perl modules.  On at least some versions\n";
    print "of Fedora, CentOS and RHEL, this is the `perl-core` package.\n";
    print "\n";
    print " % dnf install perl-core\n";
    print "   ~ or ~\n";
    print " % yum install perl-core\n";
    print "\n";
    print "If you really want to install dual-life modules from CPAN, then you can\n";
    print "use cpanm:\n";
    print "\n";
    print " % cpanm @{[ sort keys %missing ]}\n";
    print "\n";
    print "Note that some core modules are not available from CPAN.\n";
    exit;
  }
}
BEGIN {
  use strict; use warnings;
  unless(eval q{ use 5.008001; 1}) {
    print "Perl 5.008001 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.72.
use strict;
use warnings;
use 5.008001;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"       => "Find or install the Expat stream-oriented XML parser",
  "AUTHOR"         => "Graham Ollis <plicease\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Alien::Build"                           => "0.32",
    "Alien::Build::MM"                       => "0.32",
    "Alien::Build::Plugin::Download::GitHub" => "0.09",
    "ExtUtils::MakeMaker"                    => "6.52"
  },
  "CONFIGURE_REQUIRES" => {
    "Alien::Build"                           => "0.32",
    "Alien::Build::MM"                       => "0.32",
    "Alien::Build::Plugin::Build::Autoconf"  => "0.41",
    "Alien::Build::Plugin::Download::GitHub" => "0.09",
    "ExtUtils::MakeMaker"                    => "6.52"
  },
  "DISTNAME"         => "Alien-Expat",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME"             => "Alien::Expat",
  "PM"               => {
    "lib/Alien/Expat.pm" => "\$(INST_LIB)/Alien/Expat.pm"
  },
  "PREREQ_PM" => {
    "Alien::Base" => "0.038"
  },
  "TEST_REQUIRES" => {
    "FFI::Platypus::Record" => 0,
    "Test2::V0"             => "0.000121",
    "Test::Alien"           => "1.90",
    "Test::Alien::Diag"     => "1.90"
  },
  "VERSION" => "0.04",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Alien::Base"                            => "0.038",
  "Alien::Build"                           => "0.32",
  "Alien::Build::MM"                       => "0.32",
  "Alien::Build::Plugin::Download::GitHub" => "0.09",
  "ExtUtils::MakeMaker"                    => "6.52",
  "FFI::Platypus::Record"                  => 0,
  "Test2::V0"                              => "0.000121",
  "Test::Alien"                            => "1.90",
  "Test::Alien::Diag"                      => "1.90"
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
BEGIN {
  use strict; use warnings;
  my %missing = map {
    eval qq{ require $_ };
    $@ ? ($_=>1) : ()
  } qw( HTTP::Tiny strict warnings );
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
  unless(eval q{ use 5.022; 1}) {
    print "Perl 5.022 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.68.
use strict;
use warnings;
use 5.022;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Task bundle for Alien development",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "Task-AlienDev",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.022",
  "NAME"             => "Task::AlienDev",
  "PM"               => {
    "lib/Task/AlienDev.pm" => "\$(INST_LIB)/Task/AlienDev.pm"
  },
  "PREREQ_PM" => {
    "Alien::Build"                            => "2.41",
    "Alien::MSYS"                             => "0.14",
    "App::af"                                 => "0.17",
    "Dist::Zilla::MintingProfile::AlienBuild" => "0.01",
    "Dist::Zilla::Plugin::AlienBuild"         => "0.32",
    "Env::ShellWords"                         => 0,
    "File::Listing"                           => 0,
    "Mojo::DOM58"                             => 0,
    "Sort::Versions"                          => 0,
    "URI"                                     => 0
  },
  "TEST_REQUIRES" => {
    "Test2::V0" => "0.000121"
  },
  "VERSION" => "0.02",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Alien::Build"                            => "2.41",
  "Alien::MSYS"                             => "0.14",
  "App::af"                                 => "0.17",
  "Dist::Zilla::MintingProfile::AlienBuild" => "0.01",
  "Dist::Zilla::Plugin::AlienBuild"         => "0.32",
  "Env::ShellWords"                         => 0,
  "File::Listing"                           => 0,
  "Mojo::DOM58"                             => 0,
  "Sort::Versions"                          => 0,
  "Test2::V0"                               => "0.000121",
  "URI"                                     => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
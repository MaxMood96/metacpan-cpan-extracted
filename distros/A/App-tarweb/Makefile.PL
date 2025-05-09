BEGIN {
  use strict; use warnings;
  my %missing = map {
    eval qq{ require $_ };
    $@ ? ($_=>1) : ()
  } qw( Encode IO::Socket::INET experimental strict warnings );
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
  unless(eval q{ use 5.034; 1}) {
    print "Perl 5.034 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.71.
use strict;
use warnings;
use 5.034;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

$File::ShareDir::Install::INCLUDE_DOTFILES = 1;
$File::ShareDir::Install::INCLUDE_DOTDIRS  = 1;
install_share dist => "share";

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Open an archive file in your web browser!",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker"     => 0,
    "File::ShareDir::Install" => "0.06"
  },
  "DISTNAME"  => "App-tarweb",
  "EXE_FILES" => [
    "bin/tarweb"
  ],
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.034",
  "NAME"             => "App::tarweb",
  "PM"               => {
    "lib/App/tarweb.pm" => "\$(INST_LIB)/App/tarweb.pm"
  },
  "PREREQ_PM" => {
    "Browser::Start"         => 0,
    "File::ShareDir::Dist"   => 0,
    "Path::Tiny"             => 0,
    "Plack::App::File"       => 0,
    "Plack::App::Libarchive" => "0.02",
    "Plack::Builder"         => 0,
    "Plack::Runner"          => 0,
    "URI"                    => 0
  },
  "TEST_REQUIRES" => {
    "Capture::Tiny"         => 0,
    "HTTP::Request::Common" => 0,
    "Mojo::DOM58"           => 0,
    "Test2::Tools::DOM"     => 0,
    "Test2::Tools::HTTP"    => 0,
    "Test2::V0"             => "0.000121",
    "Test::Script"          => 0
  },
  "VERSION" => "0.01",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Browser::Start"         => 0,
  "Capture::Tiny"          => 0,
  "File::ShareDir::Dist"   => 0,
  "HTTP::Request::Common"  => 0,
  "Mojo::DOM58"            => 0,
  "Path::Tiny"             => 0,
  "Plack::App::File"       => 0,
  "Plack::App::Libarchive" => "0.02",
  "Plack::Builder"         => 0,
  "Plack::Runner"          => 0,
  "Test2::Tools::DOM"      => 0,
  "Test2::Tools::HTTP"     => 0,
  "Test2::V0"              => "0.000121",
  "Test::Script"           => 0,
  "URI"                    => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

{
  package
    MY;
  use File::ShareDir::Install qw(postamble);
}
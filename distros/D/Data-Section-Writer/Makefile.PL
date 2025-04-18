BEGIN {
  use strict; use warnings;
  my %missing = map {
    eval qq{ require $_ };
    $@ ? ($_=>1) : ()
  } qw( Carp Exporter MIME::Base64 Test::Builder experimental lib strict warnings );
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
  unless(eval q{ use v5.20.0; 1}) {
    print "Perl v5.20.0 or better required\n";
    exit;
  }
}
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.77.
use strict;
use warnings;
use 5.020000;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Write __DATA__ section files for Data::Section, Data::Section::Simple or Mojo::Loader::data_section",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "Data-Section-Writer",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.020000",
  "NAME"             => "Data::Section::Writer",
  "PM"               => {
    "lib/Data/Section/Pluggable/Role/FormatContentPlugin.pm" => "\$(INST_LIB)/Data/Section/Pluggable/Role/FormatContentPlugin.pm",
    "lib/Data/Section/Writer.pm"                             => "\$(INST_LIB)/Data/Section/Writer.pm"
  },
  "PREREQ_PM" => {
    "Class::Tiny" => 0,
    "Path::Tiny"  => 0,
    "Ref::Util"   => 0,
    "Role::Tiny"  => "1.003001",
    "stable"      => 0,
    "true"        => 0
  },
  "TEST_REQUIRES" => {
    "Capture::Tiny"          => 0,
    "Role::Tiny::With"       => 0,
    "Test2::API"             => "1.302015",
    "Test2::Require::Module" => "0.000121",
    "Test2::V0"              => "0.000121",
    "Test::Differences"      => 0
  },
  "VERSION" => "0.04",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Capture::Tiny"          => 0,
  "Class::Tiny"            => 0,
  "Path::Tiny"             => 0,
  "Ref::Util"              => 0,
  "Role::Tiny"             => "1.003001",
  "Role::Tiny::With"       => 0,
  "Test2::API"             => "1.302015",
  "Test2::Require::Module" => "0.000121",
  "Test2::V0"              => "0.000121",
  "Test::Differences"      => 0,
  "stable"                 => 0,
  "true"                   => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
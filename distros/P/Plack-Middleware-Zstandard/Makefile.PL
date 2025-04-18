BEGIN {
  use strict; use warnings;
  my %missing = map {
    eval qq{ require $_ };
    $@ ? ($_=>1) : ()
  } qw( experimental parent warnings );
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
# This file was automatically generated by Dist::Zilla::Plugin::Author::Plicease::MakeMaker v2.75.
use strict;
use warnings;
use 5.020000;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT"           => "Compress response body with Zstandard",
  "AUTHOR"             => "Graham Ollis <plicease\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME"         => "Plack-Middleware-Zstandard",
  "LICENSE"          => "perl",
  "MIN_PERL_VERSION" => "5.020000",
  "NAME"             => "Plack::Middleware::Zstandard",
  "PM"               => {
    "lib/Plack/Middleware/Zstandard.pm" => "\$(INST_LIB)/Plack/Middleware/Zstandard.pm"
  },
  "PREREQ_PM" => {
    "Compress::Stream::Zstd::Compressor" => 0,
    "Plack::Middleware"                  => 0,
    "Plack::Util"                        => 0,
    "Plack::Util::Accessor"              => 0,
    "Ref::Util"                          => 0
  },
  "TEST_REQUIRES" => {
    "Compress::Stream::Zstd::Decompressor" => 0,
    "HTTP::Request::Common"                => 0,
    "Plack::Builder"                       => 0,
    "Test2::Tools::HTTP"                   => 0,
    "Test2::V0"                            => "0.000121"
  },
  "VERSION" => "0.02",
  "test"    => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Compress::Stream::Zstd::Compressor"   => 0,
  "Compress::Stream::Zstd::Decompressor" => 0,
  "HTTP::Request::Common"                => 0,
  "Plack::Builder"                       => 0,
  "Plack::Middleware"                    => 0,
  "Plack::Util"                          => 0,
  "Plack::Util::Accessor"                => 0,
  "Ref::Util"                            => 0,
  "Test2::Tools::HTTP"                   => 0,
  "Test2::V0"                            => "0.000121"
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
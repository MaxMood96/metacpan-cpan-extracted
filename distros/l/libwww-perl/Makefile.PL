# This Makefile.PL for libwww-perl was generated by
# Dist::Zilla::Plugin::MakeMaker::Awesome 0.49.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use 5.008001;
use ExtUtils::MakeMaker;

use Getopt::Long qw(GetOptions);
GetOptions(\my %opt,
   'aliases',
   'no-programs|n',
) or do {
    die "Usage: $0 [--aliases] [--no-programs]\n";
};
my @prog;
push(@prog, qw(lwp-request lwp-mirror lwp-download lwp-dump))
    unless $opt{'no-programs'} || grep /^LIB=/, @ARGV;
if ($opt{'aliases'} && grep(/lwp-request/, @prog)) {
    require File::Copy;
    for (qw(GET HEAD POST)) {
        File::Copy::copy("bin/lwp-request", "bin/$_") || die "Can't copy bin/$_";
        chmod(0755, "bin/$_");
        push(@prog, $_);
    }
}

my %WriteMakefileArgs = (
  "ABSTRACT" => "The World-Wide Web library for Perl",
  "AUTHOR" => "Gisle Aas <gisle\@activestate.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Copy" => 0,
    "Getopt::Long" => 0
  },
  "DISTNAME" => "libwww-perl",
  "EXE_FILES" => [
    "bin/lwp-download",
    "bin/lwp-dump",
    "bin/lwp-mirror",
    "bin/lwp-request"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008001",
  "NAME" => "libwww::perl",
  "PREREQ_PM" => {
    "Digest::MD5" => 0,
    "Encode" => "2.12",
    "Encode::Locale" => 0,
    "File::Copy" => 0,
    "File::Listing" => 6,
    "File::Temp" => 0,
    "Getopt::Long" => 0,
    "HTML::Entities" => 0,
    "HTML::HeadParser" => "3.71",
    "HTTP::Cookies" => 6,
    "HTTP::Date" => 6,
    "HTTP::Negotiate" => 6,
    "HTTP::Request" => "6.18",
    "HTTP::Request::Common" => "6.18",
    "HTTP::Response" => "6.18",
    "HTTP::Status" => "6.18",
    "IO::Select" => 0,
    "IO::Socket" => 0,
    "LWP::MediaTypes" => 6,
    "MIME::Base64" => "2.1",
    "Module::Load" => 0,
    "Net::FTP" => "2.58",
    "Net::HTTP" => "6.18",
    "Scalar::Util" => 0,
    "Try::Tiny" => 0,
    "URI" => "1.10",
    "URI::Escape" => 0,
    "WWW::RobotRules" => 6,
    "parent" => "0.217",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "FindBin" => 0,
    "HTTP::CookieJar::LWP" => 0,
    "HTTP::Daemon" => "6.12",
    "Test::Fatal" => 0,
    "Test::More" => "0.96",
    "Test::Needs" => 0,
    "Test::RequiresInternet" => 0
  },
  "VERSION" => "6.79",
  "test" => {
    "TESTS" => "t/*.t t/base/*.t t/base/protocols/*.t t/leak/*.t t/local/*.t t/robot/*.t"
  }
);

%WriteMakefileArgs = (
    %WriteMakefileArgs,
    EXE_FILES => [ map "bin/$_", @prog ],
    NAME => 'LWP',
);

my %FallbackPrereqs = (
  "Digest::MD5" => 0,
  "Encode" => "2.12",
  "Encode::Locale" => 0,
  "ExtUtils::MakeMaker" => 0,
  "File::Copy" => 0,
  "File::Listing" => 6,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "FindBin" => 0,
  "Getopt::Long" => 0,
  "HTML::Entities" => 0,
  "HTML::HeadParser" => "3.71",
  "HTTP::CookieJar::LWP" => 0,
  "HTTP::Cookies" => 6,
  "HTTP::Daemon" => "6.12",
  "HTTP::Date" => 6,
  "HTTP::Negotiate" => 6,
  "HTTP::Request" => "6.18",
  "HTTP::Request::Common" => "6.18",
  "HTTP::Response" => "6.18",
  "HTTP::Status" => "6.18",
  "IO::Select" => 0,
  "IO::Socket" => 0,
  "LWP::MediaTypes" => 6,
  "MIME::Base64" => "2.1",
  "Module::Load" => 0,
  "Net::FTP" => "2.58",
  "Net::HTTP" => "6.18",
  "Scalar::Util" => 0,
  "Test::Fatal" => 0,
  "Test::More" => "0.96",
  "Test::Needs" => 0,
  "Test::RequiresInternet" => 0,
  "Try::Tiny" => 0,
  "URI" => "1.10",
  "URI::Escape" => 0,
  "WWW::RobotRules" => 6,
  "parent" => "0.217",
  "strict" => 0,
  "warnings" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.009.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Utilities related to Perl distribution and Debian",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Util-Debian",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Dist::Util::Debian",
  "PREREQ_PM" => {
    "Exporter" => "5.57",
    "File::Slurper::Temp" => 0,
    "File::Util::Tempdir" => "0.032",
    "HTTP::Tiny" => "0.057",
    "IO::Uncompress::Gunzip" => 0,
    "Log::ger" => "0.023",
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.98"
  },
  "VERSION" => "0.007",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Exporter" => "5.57",
  "File::Slurper::Temp" => 0,
  "File::Spec" => 0,
  "File::Util::Tempdir" => "0.032",
  "HTTP::Tiny" => "0.057",
  "IO::Handle" => 0,
  "IO::Uncompress::Gunzip" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.023",
  "Test::More" => "0.98",
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

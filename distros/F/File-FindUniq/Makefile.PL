# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Find unique or duplicate file {contents,names}",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "File-FindUniq",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "File::FindUniq",
  "PREREQ_PM" => {
    "Cwd" => 0,
    "Exporter" => "5.57",
    "File::Digest" => "0.009",
    "File::Find" => 0,
    "Log::ger" => "0.038",
    "Perinci::Sub::Util" => "0.472",
    "Regexp::Util" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Slurper" => 0,
    "File::Spec" => 0,
    "File::Temp" => "0.2310",
    "File::chdir" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.98"
  },
  "VERSION" => "0.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Cwd" => 0,
  "Exporter" => "5.57",
  "File::Digest" => "0.009",
  "File::Find" => 0,
  "File::Slurper" => 0,
  "File::Spec" => 0,
  "File::Temp" => "0.2310",
  "File::chdir" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Log::ger" => "0.038",
  "Perinci::Sub::Util" => "0.472",
  "Regexp::Util" => 0,
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

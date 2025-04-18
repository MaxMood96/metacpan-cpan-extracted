# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.031.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "SMTP support for IO::Async",
  "AUTHOR" => "Tom Molesworth <TEAM\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Net-Async-SMTP",
  "LICENSE" => "perl",
  "NAME" => "Net::Async::SMTP",
  "PREREQ_PM" => {
    "Future" => "0.24",
    "IO::Async" => "0.54",
    "IO::Async::Resolver::DNS" => "0.04",
    "IO::Socket::SSL" => 0,
    "Protocol::SMTP" => "0.001",
    "parent" => 0
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::CheckDeps" => "0.010",
    "Test::Fatal" => "0.010",
    "Test::More" => "0.98"
  },
  "VERSION" => "0.004",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Future" => "0.24",
  "IO::Async" => "0.54",
  "IO::Async::Resolver::DNS" => "0.04",
  "IO::Handle" => 0,
  "IO::Socket::SSL" => 0,
  "IPC::Open3" => 0,
  "Protocol::SMTP" => "0.001",
  "Test::CheckDeps" => "0.010",
  "Test::Fatal" => "0.010",
  "Test::More" => "0.98",
  "parent" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

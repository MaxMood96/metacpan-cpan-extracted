# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.031.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A generic EPP proxy server framework.",
  "AUTHOR" => "Gavin Brown <gavin.brown\@icann.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Net-EPP-MITMProxy",
  "LICENSE" => "perl",
  "NAME" => "Net::EPP::MITMProxy",
  "PREREQ_PM" => {
    "IO::Socket::SSL" => 0,
    "Mozilla::CA" => 0,
    "Net::EPP::Protocol" => 0,
    "Net::Server::PreFork" => 0,
    "SUPER" => 0,
    "Socket" => 0,
    "Socket6" => 0,
    "XML::LibXML" => 0,
    "base" => 0,
    "bytes" => 0,
    "feature" => 0,
    "strict" => 0,
    "vars" => 0
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "IO::Socket::SSL" => 0,
  "Mozilla::CA" => 0,
  "Net::EPP::Protocol" => 0,
  "Net::Server::PreFork" => 0,
  "SUPER" => 0,
  "Socket" => 0,
  "Socket6" => 0,
  "Test::More" => 0,
  "XML::LibXML" => 0,
  "base" => 0,
  "bytes" => 0,
  "feature" => 0,
  "strict" => 0,
  "vars" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

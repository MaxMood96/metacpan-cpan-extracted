# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.025.
use strict;
use warnings;

use 5.032000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Signs requests using Amazon's Signature Version 4.",
  "AUTHOR" => "Charles A. Wimmer <charles\@wimmer.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Net-Amazon-SignatureVersion4",
  "LICENSE" => "bsd",
  "MIN_PERL_VERSION" => "5.032000",
  "NAME" => "Net::Amazon::SignatureVersion4",
  "PREREQ_PM" => {
    "Class::XSAccessor" => 0,
    "Data::Dumper" => 0,
    "Digest::SHA" => 0,
    "HTTP::Date" => 0,
    "MooseX::App" => 0,
    "POSIX" => 0,
    "URI::Encode" => 0,
    "feature" => 0,
    "open" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Config::Any" => "0.32",
    "Config::General" => "2.65",
    "Dist::Zilla::App::Command::cover" => "1.101001",
    "File::Slurp" => 0,
    "HTTP::Request" => 0,
    "JSON" => 0,
    "LWP::UserAgent" => 0,
    "List::Compare" => 0,
    "Pod::Coverage::TrustPod" => "0.1000005",
    "TAP::Formatter::JUnit" => "0.16",
    "TAP::Harness::JUnit" => "0.42",
    "Test::More" => 0,
    "Test::Perl::Critic" => "1.04",
    "Test::Pod" => "1.52",
    "Test::Pod::Coverage" => "1.10"
  },
  "VERSION" => "0.007",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Class::XSAccessor" => 0,
  "Config::Any" => "0.32",
  "Config::General" => "2.65",
  "Data::Dumper" => 0,
  "Digest::SHA" => 0,
  "Dist::Zilla::App::Command::cover" => "1.101001",
  "File::Slurp" => 0,
  "HTTP::Date" => 0,
  "HTTP::Request" => 0,
  "JSON" => 0,
  "LWP::UserAgent" => 0,
  "List::Compare" => 0,
  "MooseX::App" => 0,
  "POSIX" => 0,
  "Pod::Coverage::TrustPod" => "0.1000005",
  "TAP::Formatter::JUnit" => "0.16",
  "TAP::Harness::JUnit" => "0.42",
  "Test::More" => 0,
  "Test::Perl::Critic" => "1.04",
  "Test::Pod" => "1.52",
  "Test::Pod::Coverage" => "1.10",
  "URI::Encode" => 0,
  "feature" => 0,
  "open" => 0,
  "utf8" => 0,
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

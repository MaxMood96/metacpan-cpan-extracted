# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.010.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Interact with the Palo Alto firewall API",
  "AUTHOR" => "Greg Foletta <greg\@foletta.org>",
  "BUILD_REQUIRES" => {
    "Pod::Coverage::TrustPod" => 0,
    "Test::Pod" => 0,
    "Test::Pod::Coverage" => 0
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Device-PaloAlto-Firewall",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Device::PaloAlto::Firewall",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Data::Dumper" => 0,
    "Devel::StackTrace" => 0,
    "HTTP::Request" => 0,
    "LWP::UserAgent" => 0,
    "List::Util" => 0,
    "Memoize" => 0,
    "Modern::Perl" => 0,
    "Moose" => 0,
    "POSIX" => 0,
    "Params::Validate" => 0,
    "URI" => "1.61",
    "XML::Twig" => 0,
    "strict" => 0,
    "version" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "HTTP::Response" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "Test::Warn" => 0
  },
  "VERSION" => "0.091",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Dumper" => 0,
  "Devel::StackTrace" => 0,
  "HTTP::Request" => 0,
  "HTTP::Response" => 0,
  "LWP::UserAgent" => 0,
  "List::Util" => 0,
  "Memoize" => 0,
  "Modern::Perl" => 0,
  "Moose" => 0,
  "POSIX" => 0,
  "Params::Validate" => 0,
  "Pod::Coverage::TrustPod" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0,
  "Test::Pod" => 0,
  "Test::Pod::Coverage" => 0,
  "Test::Warn" => 0,
  "URI" => "1.61",
  "XML::Twig" => 0,
  "strict" => 0,
  "version" => 0,
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

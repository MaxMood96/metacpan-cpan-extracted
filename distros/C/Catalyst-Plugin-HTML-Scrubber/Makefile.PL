# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.025.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Catalyst plugin for scrubbing/sanitizing incoming parameters",
  "AUTHOR" => "David Precious <davidp\@preshweb.co.uk>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Catalyst-Plugin-HTML-Scrubber",
  "LICENSE" => "perl",
  "NAME" => "Catalyst::Plugin::HTML::Scrubber",
  "PREREQ_PM" => {
    "Catalyst::ClassData" => 0,
    "HTML::Scrubber" => 0,
    "MRO::Compat" => 0,
    "Moose" => 0,
    "namespace::autoclean" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Catalyst" => 0,
    "Catalyst::Controller" => 0,
    "Catalyst::Controller::REST" => 0,
    "Catalyst::Test" => 0,
    "FindBin" => 0,
    "HTTP::Request::Common" => 0,
    "HTTP::Status" => 0,
    "Test::More" => 0,
    "lib" => 0,
    "strict" => 0
  },
  "VERSION" => "0.07",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Catalyst" => 0,
  "Catalyst::ClassData" => 0,
  "Catalyst::Controller" => 0,
  "Catalyst::Controller::REST" => 0,
  "Catalyst::Test" => 0,
  "FindBin" => 0,
  "HTML::Scrubber" => 0,
  "HTTP::Request::Common" => 0,
  "HTTP::Status" => 0,
  "MRO::Compat" => 0,
  "Moose" => 0,
  "Test::More" => 0,
  "lib" => 0,
  "namespace::autoclean" => 0,
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

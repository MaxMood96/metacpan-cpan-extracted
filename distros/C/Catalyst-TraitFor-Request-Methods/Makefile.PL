# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.014000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Add enumerated methods for HTTP requests",
  "AUTHOR" => "Robert Rothenberg <rrwo\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Catalyst-TraitFor-Request-Methods",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.014000",
  "NAME" => "Catalyst::TraitFor::Request::Methods",
  "PREREQ_PM" => {
    "Catalyst" => "5.90090",
    "List::Util" => "1.33",
    "Moose::Role" => 0,
    "namespace::autoclean" => 0
  },
  "TEST_REQUIRES" => {
    "Catalyst" => "5.90090",
    "Catalyst::Test" => 0,
    "File::Spec" => 0,
    "HTTP::Request" => 0,
    "HTTP::Request::Common" => 0,
    "Module::Metadata" => 0,
    "Moose" => 0,
    "Plack::Middleware::MethodOverride" => 0,
    "Test::More" => 0,
    "Test::Most" => 0,
    "lib" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "v0.5.2",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Catalyst" => "5.90090",
  "Catalyst::Test" => 0,
  "File::Spec" => 0,
  "HTTP::Request" => 0,
  "HTTP::Request::Common" => 0,
  "List::Util" => "1.33",
  "Module::Metadata" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "Plack::Middleware::MethodOverride" => 0,
  "Test::More" => 0,
  "Test::Most" => 0,
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

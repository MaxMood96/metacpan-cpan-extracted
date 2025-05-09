# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.031.
use strict;
use warnings;

use 5.026000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Integrate Authorization::AccessControl into Mojolicious",
  "AUTHOR" => "Mark Tyrrell <mark\@tyrrminal.dev>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Mojolicious-Plugin-Authorization-AccessControl",
  "LICENSE" => "mit",
  "MIN_PERL_VERSION" => "5.026000",
  "NAME" => "Mojolicious::Plugin::Authorization::AccessControl",
  "PREREQ_PM" => {
    "Authorization::AccessControl" => "0.03",
    "Mojolicious" => "9.00",
    "Readonly" => "2.05",
    "Syntax::Keyword::Try" => "0.29"
  },
  "TEST_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test2::Suite" => "0.000155",
    "Test::More" => 0
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Authorization::AccessControl" => "0.03",
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Mojolicious" => "9.00",
  "Readonly" => "2.05",
  "Syntax::Keyword::Try" => "0.29",
  "Test2::Suite" => "0.000155",
  "Test::More" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

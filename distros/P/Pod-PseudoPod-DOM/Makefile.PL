# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "an object model for Pod::PseudoPod documents",
  "AUTHOR" => "chromatic <chromatic\@wgz.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Pod-PseudoPod-DOM",
  "EXE_FILES" => [
    "bin/ppdom2html",
    "bin/ppdom2latex"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Pod::PseudoPod::DOM",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::Load" => 0,
    "Exporter" => 0,
    "File::Basename" => 0,
    "HTML::Entities" => 0,
    "List::Util" => 0,
    "MIME::Base64" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "MooseX::Traits" => 0,
    "Path::Class" => 0,
    "Pod::PseudoPod" => 0,
    "Scalar::Util" => 0,
    "autodie" => 0,
    "constant" => 0,
    "open" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Slurp" => 0,
    "File::Spec::Functions" => 0,
    "Modern::Perl" => 0,
    "Module::Pluggable" => 0,
    "Test::LongString" => 0,
    "Test::More" => 0,
    "lib" => 0
  },
  "VERSION" => "1.20210620.2040",
  "test" => {
    "TESTS" => "t/*.t t/html/*.t t/index/*.t t/latex/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Class::Load" => 0,
  "Exporter" => 0,
  "File::Basename" => 0,
  "File::Slurp" => 0,
  "File::Spec::Functions" => 0,
  "HTML::Entities" => 0,
  "List::Util" => 0,
  "MIME::Base64" => 0,
  "Modern::Perl" => 0,
  "Module::Pluggable" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "MooseX::Traits" => 0,
  "Path::Class" => 0,
  "Pod::PseudoPod" => 0,
  "Scalar::Util" => 0,
  "Test::LongString" => 0,
  "Test::More" => 0,
  "autodie" => 0,
  "constant" => 0,
  "lib" => 0,
  "open" => 0,
  "parent" => 0,
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

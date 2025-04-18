# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Danish postal code validator and container",
  "AUTHOR" => "Jonas B. <jonasbn\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Module::Build" => "0.30"
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.30"
  },
  "DISTNAME" => "Business-DK-Postalcode",
  "EXE_FILES" => [
    "bin/parse-excel.pl",
    "bin/postdanmark.pl"
  ],
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Business::DK::Postalcode",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Exporter" => 0,
    "Params::Validate" => 0,
    "Scalar::Util" => 0,
    "Tree::Simple" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Dumper" => 0,
    "Data::FormValidator" => 0,
    "English" => 0,
    "Env" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Pod::Coverage::TrustPod" => 0,
    "Test::CPAN::Changes" => 0,
    "Test::Class" => 0,
    "Test::Exception" => 0,
    "Test::Kwalitee" => "1.21",
    "Test::More" => "0.88",
    "Test::Pod" => "1.41",
    "Test::Pod::Coverage" => "1.08",
    "Test::Taint" => 0,
    "Test::Tester" => "1.302111"
  },
  "VERSION" => "0.12",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Dumper" => 0,
  "Data::FormValidator" => 0,
  "English" => 0,
  "Env" => 0,
  "Exporter" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.30",
  "Params::Validate" => 0,
  "Pod::Coverage::TrustPod" => 0,
  "Scalar::Util" => 0,
  "Test::CPAN::Changes" => 0,
  "Test::Class" => 0,
  "Test::Exception" => 0,
  "Test::Kwalitee" => "1.21",
  "Test::More" => "0.88",
  "Test::Pod" => "1.41",
  "Test::Pod::Coverage" => "1.08",
  "Test::Taint" => 0,
  "Test::Tester" => "1.302111",
  "Tree::Simple" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

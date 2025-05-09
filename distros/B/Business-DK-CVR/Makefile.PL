# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;

use 5.008;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Danish CVR (VAT Registration) number generator/validator",
  "AUTHOR" => "Jonas B. <jonasbn\@cpan.org>",
  "BUILD_REQUIRES" => {
    "Module::Build" => "0.30"
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0,
    "Module::Build" => "0.30"
  },
  "DISTNAME" => "Business-DK-CVR",
  "EXE_FILES" => [
    "bin/validate_cvr.pl"
  ],
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Business::DK::CVR",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Class::InsideOut" => 0,
    "Data::FormValidator" => 0,
    "English" => 0,
    "Exporter" => 0,
    "Params::Validate" => 0,
    "Readonly" => 0,
    "Scalar::Util" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Pod::Coverage::TrustPod" => 0,
    "Taint::Runtime" => 0,
    "Test::Exception" => 0,
    "Test::Fatal" => 0,
    "Test::Kwalitee" => "1.21",
    "Test::More" => 0,
    "Test::Pod" => "1.41",
    "Test::Pod::Coverage" => "1.08",
    "Test::Taint" => 0,
    "Test::Tester" => "1.302111"
  },
  "VERSION" => "0.12",
  "test" => {
    "TESTS" => "t/*.t t/Business/DK/CVR/*.t t/Class/Business/DK/CVR/*.t t/Data/FormValidator/Constraints/Business/DK/CVR/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Class::InsideOut" => 0,
  "Data::FormValidator" => 0,
  "English" => 0,
  "Exporter" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Module::Build" => "0.30",
  "Params::Validate" => 0,
  "Pod::Coverage::TrustPod" => 0,
  "Readonly" => 0,
  "Scalar::Util" => 0,
  "Taint::Runtime" => 0,
  "Test::Exception" => 0,
  "Test::Fatal" => 0,
  "Test::Kwalitee" => "1.21",
  "Test::More" => 0,
  "Test::Pod" => "1.41",
  "Test::Pod::Coverage" => "1.08",
  "Test::Taint" => 0,
  "Test::Tester" => "1.302111"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Automatically hash password/passphrase columns",
  "AUTHOR" => "Leon Timmermans <leont\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "DBIx-Class-CryptColumn",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "DBIx::Class::CryptColumn",
  "PREREQ_PM" => {
    "Crypt::Passphrase" => "0.019",
    "DBIx::Class" => 0,
    "Scalar::Util" => 0,
    "Sub::Util" => "1.40",
    "namespace::clean" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Crypt::Passphrase::Encoder" => 0,
    "DBIx::Class::Core" => 0,
    "DBIx::Class::Schema" => 0,
    "Digest::SHA" => 0,
    "Encode" => 0,
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => "0.89",
    "lib" => 0
  },
  "VERSION" => "0.009",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Crypt::Passphrase" => "0.019",
  "Crypt::Passphrase::Encoder" => 0,
  "DBIx::Class" => 0,
  "DBIx::Class::Core" => 0,
  "DBIx::Class::Schema" => 0,
  "Digest::SHA" => 0,
  "Encode" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Scalar::Util" => 0,
  "Sub::Util" => "1.40",
  "Test::More" => "0.89",
  "lib" => 0,
  "namespace::clean" => 0,
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

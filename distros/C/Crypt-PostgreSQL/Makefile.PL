# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.006000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "generate PostgreSQl password hashes",
  "AUTHOR" => "Guido Brugnara <gdo\@leader.it>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Crypt-PostgreSQL",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.006000",
  "NAME" => "Crypt::PostgreSQL",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Crypt::Digest::SHA256" => 0,
    "Crypt::KeyDerivation" => 0,
    "Crypt::Mac::HMAC" => 0,
    "Crypt::URandom" => 0,
    "Digest::MD5" => 0,
    "MIME::Base64" => 0
  },
  "TEST_REQUIRES" => {
    "Test::Simple" => 0
  },
  "VERSION" => "0.02",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Crypt::Digest::SHA256" => 0,
  "Crypt::KeyDerivation" => 0,
  "Crypt::Mac::HMAC" => 0,
  "Crypt::URandom" => 0,
  "Digest::MD5" => 0,
  "MIME::Base64" => 0,
  "Test::Simple" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

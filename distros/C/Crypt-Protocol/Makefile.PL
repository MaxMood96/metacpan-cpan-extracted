# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Crypt Protocol",
  "AUTHOR" => "Pan Lanlan <abbypan\@gmail.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Crypt-Protocol",
  "LICENSE" => "mozilla",
  "NAME" => "Crypt::Protocol",
  "PREREQ_PM" => {
    "CBOR::XS" => 0,
    "Crypt::OpenSSL::BaseFunc" => "0.039",
    "Crypt::OpenSSL::Bignum" => "0.09",
    "Crypt::OpenSSL::EC" => "1.31",
    "Crypt::OpenSSL::ECDSA" => 0,
    "Crypt::Perl" => 0,
    "Crypt::ScryptKDF" => 0,
    "CryptX" => 0,
    "Digest::CMAC" => 0,
    "List::Util" => "1.55",
    "Math::BigInt" => 0,
    "Smart::Comments" => 0,
    "bignum" => "0.52"
  },
  "VERSION" => "0.002",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "CBOR::XS" => 0,
  "Crypt::OpenSSL::BaseFunc" => "0.039",
  "Crypt::OpenSSL::Bignum" => "0.09",
  "Crypt::OpenSSL::EC" => "1.31",
  "Crypt::OpenSSL::ECDSA" => 0,
  "Crypt::Perl" => 0,
  "Crypt::ScryptKDF" => 0,
  "CryptX" => 0,
  "Digest::CMAC" => 0,
  "List::Util" => "1.55",
  "Math::BigInt" => 0,
  "Smart::Comments" => 0,
  "bignum" => "0.52"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

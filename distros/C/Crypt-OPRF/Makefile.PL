# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.030.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Oblivious Pseudorandom Functions (OPRFs) using Prime-Order Groups",
  "AUTHOR" => "Pan Lanlan <abbypan\@gmail.com>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Crypt-OPRF",
  "LICENSE" => "mozilla",
  "NAME" => "Crypt::OPRF",
  "PREREQ_PM" => {
    "Crypt::OpenSSL::Base::Func" => "0.038",
    "Crypt::OpenSSL::Bignum" => "0.09",
    "Crypt::OpenSSL::EC" => "1.31",
    "Crypt::OpenSSL::Hash2Curve" => "0.033",
    "bignum" => "0.52"
  },
  "VERSION" => "0.012",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Crypt::OpenSSL::Base::Func" => "0.038",
  "Crypt::OpenSSL::Bignum" => "0.09",
  "Crypt::OpenSSL::EC" => "1.31",
  "Crypt::OpenSSL::Hash2Curve" => "0.033",
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

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.032.
use strict;
use warnings;

use 5.020000;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "BIMI object",
  "AUTHOR" => "Marc Bradshaw <marc\@marcbradshaw.net>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Mail-BIMI",
  "EXE_FILES" => [
    "bin/mailbimi"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.020000",
  "NAME" => "Mail::BIMI",
  "PREREQ_PM" => {
    "App::Cmd::Setup" => 0,
    "Cache::FastMmap" => 0,
    "Carp" => 0,
    "Convert::ASN1" => 0,
    "Crypt::OpenSSL::Verify" => "0.20",
    "Crypt::OpenSSL::X509" => "1.812",
    "Digest::SHA" => 0,
    "Exporter" => 0,
    "File::Slurp" => 0,
    "File::Temp" => 0,
    "HTTP::Tiny::Paranoid" => 0,
    "IO::Uncompress::Gunzip" => 0,
    "Import::Into" => 0,
    "JSON" => 0,
    "MIME::Base64" => 0,
    "Mail::AuthenticationResults::Header::Comment" => 0,
    "Mail::AuthenticationResults::Header::Entry" => 0,
    "Mail::AuthenticationResults::Header::SubEntry" => 0,
    "Mail::DMARC" => 0,
    "Mail::DMARC::PurePerl" => 0,
    "Moose" => 0,
    "Moose::Role" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "Mozilla::CA" => 0,
    "Net::DNS::Resolver" => 0,
    "Sereal" => 0,
    "Sub::Install" => 0,
    "Term::ANSIColor" => 0,
    "Time::HiRes" => 0,
    "XML::LibXML" => "2.0202",
    "constant" => 0,
    "feature" => 0,
    "open" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "App::Cmd::Tester" => 0,
    "Capture::Tiny" => 0,
    "Class::Load" => 0,
    "Digest::MD5" => 0,
    "Encode" => 0,
    "Mail::SPF::Request" => 0,
    "Mail::SPF::Server" => 0,
    "Moo" => 0,
    "Net::DNS::Resolver::Mock" => "1.20200214",
    "Pod::Elemental::Element::Nested" => 0,
    "Pod::Elemental::Element::Pod5::Command" => 0,
    "Pod::Elemental::Element::Pod5::Ordinary" => 0,
    "Pod::Weaver::Role::Section" => 0,
    "Test::Class" => 0,
    "Test::Differences" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0,
    "Test::RequiresInternet" => 0,
    "Try::Tiny" => 0,
    "lib" => 0
  },
  "VERSION" => "3.20250130",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "App::Cmd::Setup" => 0,
  "App::Cmd::Tester" => 0,
  "Cache::FastMmap" => 0,
  "Capture::Tiny" => 0,
  "Carp" => 0,
  "Class::Load" => 0,
  "Convert::ASN1" => 0,
  "Crypt::OpenSSL::Verify" => "0.20",
  "Crypt::OpenSSL::X509" => "1.812",
  "Digest::MD5" => 0,
  "Digest::SHA" => 0,
  "Encode" => 0,
  "Exporter" => 0,
  "File::Slurp" => 0,
  "File::Temp" => 0,
  "HTTP::Tiny::Paranoid" => 0,
  "IO::Uncompress::Gunzip" => 0,
  "Import::Into" => 0,
  "JSON" => 0,
  "MIME::Base64" => 0,
  "Mail::AuthenticationResults::Header::Comment" => 0,
  "Mail::AuthenticationResults::Header::Entry" => 0,
  "Mail::AuthenticationResults::Header::SubEntry" => 0,
  "Mail::DMARC" => 0,
  "Mail::DMARC::PurePerl" => 0,
  "Mail::SPF::Request" => 0,
  "Mail::SPF::Server" => 0,
  "Moo" => 0,
  "Moose" => 0,
  "Moose::Role" => 0,
  "Moose::Util::TypeConstraints" => 0,
  "Mozilla::CA" => 0,
  "Net::DNS::Resolver" => 0,
  "Net::DNS::Resolver::Mock" => "1.20200214",
  "Pod::Elemental::Element::Nested" => 0,
  "Pod::Elemental::Element::Pod5::Command" => 0,
  "Pod::Elemental::Element::Pod5::Ordinary" => 0,
  "Pod::Weaver::Role::Section" => 0,
  "Sereal" => 0,
  "Sub::Install" => 0,
  "Term::ANSIColor" => 0,
  "Test::Class" => 0,
  "Test::Differences" => 0,
  "Test::Exception" => 0,
  "Test::More" => 0,
  "Test::RequiresInternet" => 0,
  "Time::HiRes" => 0,
  "Try::Tiny" => 0,
  "XML::LibXML" => "2.0202",
  "constant" => 0,
  "feature" => 0,
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


# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.015.
use strict;
use warnings;

use 5.006;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Use the Amazon S3 - Simple Storage Service",
  "AUTHOR" => "Yasutaka ATARASHI <yakex\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "AnyEvent-Net-Amazon-S3",
  "EXE_FILES" => [
    "bin/s3cl_ae"
  ],
  "LICENSE" => "perl",
  "NAME" => "AnyEvent::Net::Amazon::S3",
  "PREREQ_PM" => {
    "AnyEvent" => 0,
    "AnyEvent::HTTP::LWP::UserAgent" => "0.10",
    "AnyEvent::HTTP::LWP::UserAgent::Determined" => 0,
    "Data::Stream::Bulk::AnyEvent" => 0,
    "Module::AnyEvent::Helper" => 0,
    "Net::Amazon::S3" => "0.60",
    "filtered" => 0,
    "parent" => 0
  },
  "TEST_REQUIRES" => {
    "Digest::MD5::File" => 0,
    "File::Spec" => 0,
    "File::Temp" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "LWP::Simple" => 0,
    "Test::Exception" => 0,
    "Test::More" => 0
  },
  "VERSION" => "v0.04.0.80",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "AnyEvent" => 0,
  "AnyEvent::HTTP::LWP::UserAgent" => "0.10",
  "AnyEvent::HTTP::LWP::UserAgent::Determined" => 0,
  "Data::Stream::Bulk::AnyEvent" => 0,
  "Digest::MD5::File" => 0,
  "File::Spec" => 0,
  "File::Temp" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "LWP::Simple" => 0,
  "Module::AnyEvent::Helper" => 0,
  "Net::Amazon::S3" => "0.60",
  "Test::Exception" => 0,
  "Test::More" => 0,
  "filtered" => 0,
  "parent" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);




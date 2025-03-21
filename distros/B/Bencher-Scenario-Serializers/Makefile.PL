# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Benchmark Perl data serialization modules",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Bencher-Scenario-Serializers",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "Bencher::Scenario::Serializers",
  "PREREQ_PM" => {
    "Cpanel::JSON::XS" => 0,
    "Data::MessagePack" => 0,
    "Data::Undump" => 0,
    "Data::Undump::PPI" => 0,
    "JSON::Create" => 0,
    "JSON::Decode::Marpa" => 0,
    "JSON::Decode::Regexp" => 0,
    "JSON::MaybeXS" => 0,
    "JSON::PP" => 0,
    "JSON::Parse" => 0,
    "JSON::Parser::Regexp" => 0,
    "JSON::Tiny" => 0,
    "JSON::XS" => 0,
    "MarpaX::ESLIF::ECMA404" => 0,
    "Pegex::JSON" => 0,
    "Sereal" => 0,
    "Storable" => "3.08",
    "YAML" => 0,
    "YAML::Old" => 0,
    "YAML::Syck" => 0,
    "YAML::XS" => 0,
    "strict" => 0,
    "utf8" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Bencher::Backend" => "1.060",
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.161",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Bencher::Backend" => "1.060",
  "Cpanel::JSON::XS" => 0,
  "Data::MessagePack" => 0,
  "Data::Undump" => 0,
  "Data::Undump::PPI" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "JSON::Create" => 0,
  "JSON::Decode::Marpa" => 0,
  "JSON::Decode::Regexp" => 0,
  "JSON::MaybeXS" => 0,
  "JSON::PP" => 0,
  "JSON::Parse" => 0,
  "JSON::Parser::Regexp" => 0,
  "JSON::Tiny" => 0,
  "JSON::XS" => 0,
  "MarpaX::ESLIF::ECMA404" => 0,
  "Pegex::JSON" => 0,
  "Sereal" => 0,
  "Storable" => "3.08",
  "Test::More" => 0,
  "YAML" => 0,
  "YAML::Old" => 0,
  "YAML::Syck" => 0,
  "YAML::XS" => 0,
  "strict" => 0,
  "utf8" => 0,
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

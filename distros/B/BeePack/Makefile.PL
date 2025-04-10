# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.012.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Primitive MsgPack based key value storage",
  "AUTHOR" => "Torsten Raudssus <torsten\@raudss.us>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "BeePack",
  "EXE_FILES" => [
    "bin/bee"
  ],
  "LICENSE" => "perl",
  "NAME" => "BeePack",
  "PREREQ_PM" => {
    "CDB::TinyCDB" => "0.05",
    "Data::MessagePack" => "0.48",
    "File::Temp" => "0.2304",
    "Moo" => "1.006001"
  },
  "TEST_REQUIRES" => {
    "Test::More" => "1.001009"
  },
  "VERSION" => "0.103",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "CDB::TinyCDB" => "0.05",
  "Data::MessagePack" => "0.48",
  "File::Temp" => "0.2304",
  "Moo" => "1.006001",
  "Test::More" => "1.001009"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.031.
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Collection of TableData:: modules that contain CPAN releases data",
  "AUTHOR" => "perlancar <perlancar\@cpan.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "TableDataBundle-Perl-CPAN-Release",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010001",
  "NAME" => "TableDataBundle::Perl::CPAN::Release",
  "PREREQ_PM" => {
    "DateTime" => 0,
    "File::ShareDir" => 0,
    "Role::Tiny" => 0,
    "Role::Tiny::With" => 0,
    "TableData::Munge::Concat" => 0,
    "TableData::Munge::GroupRows" => 0,
    "TableData::Perl::CPAN::Release::Static::2022" => 0,
    "TableData::Perl::CPAN::Release::Static::2023" => "20231126.0",
    "TableDataBundle::Perl::CPAN::Release::Static::Older" => "20220218.2",
    "TableDataRole::Source::CSVInFiles" => 0,
    "parent" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Bencher::Backend" => "1.063",
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "20231228.0",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Bencher::Backend" => "1.063",
  "DateTime" => 0,
  "File::ShareDir" => 0,
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Role::Tiny" => 0,
  "Role::Tiny::With" => 0,
  "TableData::Munge::Concat" => 0,
  "TableData::Munge::GroupRows" => 0,
  "TableData::Perl::CPAN::Release::Static::2022" => 0,
  "TableData::Perl::CPAN::Release::Static::2023" => "20231126.0",
  "TableDataBundle::Perl::CPAN::Release::Static::Older" => "20220218.2",
  "TableDataRole::Source::CSVInFiles" => 0,
  "Test::More" => 0,
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

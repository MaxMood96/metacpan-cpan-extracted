# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Scripts for parsing trees",
  "AUTHOR" => "Denis BAURAIN <denis.baurain\@uliege.be>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Bio-MUST-Tools-TreeParsing",
  "EXE_FILES" => [
    "bin/tree-clan-splitter.pl"
  ],
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Bio::MUST::Tools::TreeParsing",
  "PREREQ_PM" => {
    "Bio::MUST::Core" => 0,
    "Bio::MUST::Core::Ali" => 0,
    "Bio::MUST::Core::IdList" => 0,
    "Bio::MUST::Core::IdMapper" => 0,
    "Bio::MUST::Core::SeqId" => 0,
    "Bio::MUST::Core::Taxonomy" => 0,
    "Bio::MUST::Core::Taxonomy::Category" => 0,
    "Bio::MUST::Core::Taxonomy::Classifier" => 0,
    "Bio::MUST::Core::Taxonomy::Criterion" => 0,
    "Bio::MUST::Core::Taxonomy::Filter" => 0,
    "Bio::MUST::Core::Tree" => 0,
    "Bio::MUST::Core::Utils" => 0,
    "Carp" => 0,
    "File::Basename" => 0,
    "File::Copy" => 0,
    "File::Find::Rule" => 0,
    "File::Spec" => 0,
    "Getopt::Euclid" => 0,
    "List::AllUtils" => 0,
    "List::Compare" => 0,
    "Modern::Perl" => 0,
    "Path::Class" => 0,
    "Smart::Comments" => 0,
    "Test::Most" => 0,
    "Tie::IxHash" => 0,
    "aliased" => 0,
    "autodie" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "VERSION" => "0.210200",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Bio::MUST::Core" => 0,
  "Bio::MUST::Core::Ali" => 0,
  "Bio::MUST::Core::IdList" => 0,
  "Bio::MUST::Core::IdMapper" => 0,
  "Bio::MUST::Core::SeqId" => 0,
  "Bio::MUST::Core::Taxonomy" => 0,
  "Bio::MUST::Core::Taxonomy::Category" => 0,
  "Bio::MUST::Core::Taxonomy::Classifier" => 0,
  "Bio::MUST::Core::Taxonomy::Criterion" => 0,
  "Bio::MUST::Core::Taxonomy::Filter" => 0,
  "Bio::MUST::Core::Tree" => 0,
  "Bio::MUST::Core::Utils" => 0,
  "Carp" => 0,
  "File::Basename" => 0,
  "File::Copy" => 0,
  "File::Find::Rule" => 0,
  "File::Spec" => 0,
  "Getopt::Euclid" => 0,
  "List::AllUtils" => 0,
  "List::Compare" => 0,
  "Modern::Perl" => 0,
  "Path::Class" => 0,
  "Smart::Comments" => 0,
  "Test::Most" => 0,
  "Tie::IxHash" => 0,
  "aliased" => 0,
  "autodie" => 0,
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

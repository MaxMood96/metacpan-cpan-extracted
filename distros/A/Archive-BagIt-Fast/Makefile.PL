# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v6.017.
use strict;
use warnings;

use 5.010;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "A module to use L<IO::AIO> to get better performance",
  "AUTHOR" => "Andreas Romeyke <cpan\@andreas.romeyke.de>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Archive-BagIt-Fast",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.010",
  "NAME" => "Archive::BagIt::Fast",
  "PREREQ_PM" => {
    "Archive::BagIt" => "0.09",
    "IO::AIO" => 0,
    "Moo" => 0,
    "Net::SSLeay" => "1.43"
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.090",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Archive::BagIt" => "0.09",
  "File::Spec" => 0,
  "IO::AIO" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Moo" => 0,
  "Net::SSLeay" => "1.43",
  "Test::More" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

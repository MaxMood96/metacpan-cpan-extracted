# This Makefile.PL for Crypt-Bear was generated by
# Dist::Zilla::Plugin::MakeMaker::Awesome 0.49.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use 5.014;
use ExtUtils::MakeMaker 7.12;

use File::Find;
use File::Spec::Functions 'abs2rel';

my %args;
my $use_system = $ENV{PERL_USE_SYSTEM_BEARSSL};
if ($use_system) {
	%args = (
		LIBS => [ '-lbearssl' ],
	);
} else {
	my @sources;
	find({
		wanted => sub {
			return unless -f;
			return unless /\.c$/;
			push @sources, abs2rel($_);
		},
		no_chdir => 1,
	} , 'src');

	my @objects = map { s/\.c$/\$(OBJ_EXT)/r } @sources;

	%args = (
		INC => '-Iinclude -Isrc',
		XSBUILD => {
			xs => {
				'lib/Crypt/Bear' => {
					OBJECT  => join(' ', 'lib/Crypt/Bear$(OBJ_EXT)', @objects),
				}
			}
		},
	);
}

my %WriteMakefileArgs = (
  "ABSTRACT" => "BearSSL for Perl",
  "AUTHOR" => "Leon Timmermans <fawaka\@gmail.com>",
  "BUILD_REQUIRES" => {
    "ExtUtils::ParseXS" => "3.50"
  },
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "7.12"
  },
  "DISTNAME" => "Crypt-Bear",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.014",
  "NAME" => "Crypt::Bear",
  "PREREQ_PM" => {
    "Exporter" => 0,
    "File::Spec" => 0,
    "XSLoader" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Spec" => 0,
    "IO::Handle" => 0,
    "IPC::Open3" => 0,
    "Test::More" => 0
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

%WriteMakefileArgs = (
    %WriteMakefileArgs,
    %args,
    XSMULTI => 1,
);

my %FallbackPrereqs = (
  "Exporter" => 0,
  "ExtUtils::ParseXS" => "3.50",
  "File::Spec" => 0,
  "IO::Handle" => 0,
  "IPC::Open3" => 0,
  "Test::More" => 0,
  "XSLoader" => 0,
  "strict" => 0,
  "warnings" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

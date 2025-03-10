# This Makefile.PL for Intertangle-API-Kiwisolver was generated by
# inc::KiwisolverMaker <self>
# and Dist::Zilla::Plugin::MakeMaker::Awesome 0.48.
# Don't edit it but the dist.ini and plugins used to construct it.

use strict;
use warnings;

use 5.008;
use XS::Install;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "API for Kiwisolver constraint solver",
  "AUTHOR" => "Zakariyya Mughal <zmughal\@cpan.org>",
  "BIN_DEPS" => [
    "XS::Framework"
  ],
  "CONFIGURE_REQUIRES" => {
    "Alien::Kiwisolver" => 0,
    "ExtUtils::MakeMaker" => 0,
    "List::UtilsBy" => 0,
    "Modern::Perl" => 0,
    "XS::Framework" => 0
  },
  "CPLUS" => 14,
  "DISTNAME" => "Intertangle-API-Kiwisolver",
  "LICENSE" => "perl",
  "MIN_PERL_VERSION" => "5.008",
  "NAME" => "Intertangle::API::Kiwisolver",
  "PARSE_XS" => "XS::Framework::ParseXS",
  "PREREQ_PM" => {
    "Renard::Incunabula::Common::Setup" => 0,
    "XS::Framework" => 0,
    "XS::Loader" => 0,
    "overload" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Perl" => 0,
    "MooX::HandlesVia" => 0,
    "MooX::InsideOut" => 0,
    "Mu" => 0,
    "Path::Tiny" => 0,
    "SVG" => 0,
    "Test::Most" => 0,
    "aliased" => 0,
    "constant" => 0,
    "lib" => 0
  },
  "VERSION" => "0.001",
  "test" => {
    "TESTS" => "t/*.t t/Intertangle/API/Kiwisolver/*.t t/benchmark/cassowary/*.t"
  }
);
$WriteMakefileArgs{CONFIGURE} = sub {
	require Alien::Kiwisolver;
	require Config;
	my $k = Alien::Kiwisolver->new;
	+{
		CCFLAGS => join(" ",
			$Config::Config{ccflags},
			$k->cflags, '-std=c++14',
		),
		LIBS => $k->libs
	};
};

my %FallbackPrereqs = (
  "Data::Perl" => 0,
  "MooX::HandlesVia" => 0,
  "MooX::InsideOut" => 0,
  "Mu" => 0,
  "Path::Tiny" => 0,
  "Renard::Incunabula::Common::Setup" => 0,
  "SVG" => 0,
  "Test::Most" => 0,
  "XS::Framework" => 0,
  "XS::Loader" => 0,
  "aliased" => 0,
  "constant" => 0,
  "lib" => 0,
  "overload" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

write_makefile(%WriteMakefileArgs);

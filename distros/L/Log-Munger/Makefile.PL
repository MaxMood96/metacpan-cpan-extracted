use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

install_share 'share';

my %WriteMakefileArgs = (
	NAME               => 'Log::Munger',
	AUTHOR             => q{Zane C. Bowers-Hadley <vvelox@vvelox.net>},
	VERSION_FROM       => 'lib/Log/Munger.pm',
	ABSTRACT_FROM      => 'lib/Log/Munger.pm',
	LICENSE            => 'lgpl_3_0',
	MIN_PERL_VERSION   => '5.006',
	EXE_FILES          => ['src_bin/log_munger'],
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker'     => '0',
		'File::ShareDir::Install' => '0',
	},
	TEST_REQUIRES => {
		'Test::More' => '0',
	},
	PREREQ_PM => {
		'YAML::XS'                           => '0',
		'JSON'                               => '0',
		'File::ShareDir'                     => '0',
		'File::Slurp'                        => '0',
		'Template'                           => '0',
		'Hash::Merge'                        => '0',
		'App::Cmd'                           => '0',
		'Algorithm::Dependency::Source::HoA' => '0',
		'Algorithm::Dependency::Ordered'     => '0',
	},
	dist       => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean      => { FILES    => 'Log-Munger-*' },
	META_MERGE => {
		"meta-spec" => { version => 2 },
		resources   => {
			repository => {
				type => 'git',
				url  => 'git@github.com:LilithSec/Log-Munger.git',
				web  => 'https://github.com/LilithSec/Log-Munger',
			},
		},
		prereqs => {
			runtime => {
				# optional: only needed for the geoip enrichment feature
				recommends => { 'IP::Geolocation::MMDB' => '0', },
			},
		},
	}
);

# Compatibility with old versions of ExtUtils::MakeMaker
unless ( eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 } ) {
	my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
	@{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$test_requires } = values %$test_requires;
}

unless ( eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 } ) {
	my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
	@{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$build_requires } = values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
	unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
	unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
	unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);

package MY;
use File::ShareDir::Install qw(postamble);

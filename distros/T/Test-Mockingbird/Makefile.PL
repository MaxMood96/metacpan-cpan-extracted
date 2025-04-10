use strict;
use warnings;
use ExtUtils::MakeMaker;

my $dist = {
	COMPRESS => 'gzip -9f', # Compress tarball using gzip
	SUFFIX => 'gz',	# File suffix for tarball
};

if($^O eq 'darwin') {
	$dist->{'TAR'} = 'gtar';
}

WriteMakefile(
	NAME => 'Test::Mockingbird',
	VERSION_FROM => 'lib/Test/Mockingbird.pm', # finds $VERSION in the module
	AUTHOR => 'Nigel Horne <njh@bandsman.co.uk>',
	ABSTRACT => 'Advanced mocking library for Perl with support for dependency injection and spies',
	((defined($ExtUtils::MakeMaker::VERSION) && ($ExtUtils::MakeMaker::VERSION >= 6.3002))
		? ('LICENSE'=> 'GPL')
		: ()),
	META_MERGE => {	# https://perldoc.perl.org/CPAN::Meta::Spec
		'meta-spec' => { version => 2 },
		resources => {
			repository => {
				repository => 'https://github.com/nigelhorne/Test-Mockingbird',
				type => 'git',
				url => 'git://github.com/nigelhorne/Test-Mockingbird.git',
				web => 'https://github.com/nigelhorne/Test-Mockingbird'
			}, bugtracker => {
				mailto => 'bug-Test-Mockingbird@rt.cpan.org',
				url => 'https://github.com/nigelhorne/Test-Mockingbird/issues',
				# web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Test-Mockingbird',
				web => 'https://github.com/nigelhorne/Test-Mockingbird/issues'
			}
		},
	},
	PREREQ_PM => {
		'Carp' => 0,
		'ExtUtils::MakeMaker' => 6.64,	# Minimum version for TEST_REQUIRES
	}, TEST_REQUIRES => {
		'Test::DescribeMe' => 0,
		'Test::Most' => 0,
		'Test::Needs' => 0
	}, dist => $dist,
		clean	 => {
		FILES => 'Test-Mockingbird-*',
	},
);

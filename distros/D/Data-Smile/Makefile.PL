use strict;
use ExtUtils::MakeMaker 6.17;

my $EUMM = eval( $ExtUtils::MakeMaker::VERSION );

my $meta = {
  "abstract"       => "support for the Smile data interchange format (binary JSON serialization)",
  "author"         => ["Toby Inkster (TOBYINK) <tobyink\@cpan.org>"],
  "dynamic_config" => 1,
  "generated_by"   => "Dist::Inkt::Profile::TOBYINK version 0.024, CPAN::Meta::Converter version 2.150010",
  "keywords"       => [],
  "license"        => ["perl_5"],
  "meta-spec"      => {
                        url => "http://search.cpan.org/perldoc?CPAN::Meta::Spec",
                        version => 2,
                      },
  "name"           => "Data-Smile",
  "no_index"       => { directory => ["eg", "examples", "inc", "t", "xt"] },
  "prereqs"        => {
                        configure => { requires => { "ExtUtils::MakeMaker" => 6.17 } },
                        develop   => { recommends => { "Dist::Inkt" => 0.001 } },
                        runtime   => {
                                       recommends => { "Data::Smile::XS" => 0 },
                                       requires   => { "Exporter::Tiny" => 0, "Math::BigInt" => 1.999822, "perl" => 5.008008 },
                                     },
                        test      => {
                                       recommends => { "Path::Tiny" => 0 },
                                       requires   => {
                                                       "JSON::PP" => 0,
                                                       "Test2::Plugin::BailOnFail" => 0,
                                                       "Test2::Require::AuthorTesting" => 0,
                                                       "Test2::Require::Module" => 0,
                                                       "Test2::Tools::Spec" => 0,
                                                       "Test2::V0" => 0,
                                                     },
                                     },
                      },
  "provides"       => {
                        "Data::Smile"     => { file => "lib/Data/Smile.pm", version => "0.001000" },
                        "Data::Smile::PP" => { file => "lib/Data/Smile/PP.pm", version => "0.001000" },
                      },
  "release_status" => "stable",
  "resources"      => {
                        bugtracker   => { web => "https://github.com/tobyink/p5-data-smile/issues" },
                        homepage     => "https://metacpan.org/release/Data-Smile",
                        license      => ["http://dev.perl.org/licenses/"],
                        repository   => {
                                          type => "git",
                                          url  => "git://github.com/tobyink/p5-data-smile.git",
                                          web  => "https://github.com/tobyink/p5-data-smile",
                                        },
                        x_identifier => "http://purl.org/NET/cpan-uri/dist/Data-Smile/project",
                      },
  "version"        => "0.001000",
};

my %dynamic_config;
do {
	use strict;
	use warnings;
	no warnings 'uninitialized';
	
	# Data::Smile::PP is broken for some things on Perl 5.8.
	if ( $] lt 5.010 ) {
		$meta->{prereqs}{runtime}{requires}{'Data::Smile::XS'} = 0;
	}

};

my %WriteMakefileArgs = (
	ABSTRACT   => $meta->{abstract},
	AUTHOR     => ($EUMM >= 6.5702 ? $meta->{author} : $meta->{author}[0]),
	DISTNAME   => $meta->{name},
	VERSION    => $meta->{version},
	EXE_FILES  => [ map $_->{file}, values %{ $meta->{x_provides_scripts} || {} } ],
	NAME       => do { my $n = $meta->{name}; $n =~ s/-/::/g; $n },
	test       => { TESTS => "t/*.t t/integration/*.t" },
	%dynamic_config,
);

$WriteMakefileArgs{LICENSE} = $meta->{license}[0] if $EUMM >= 6.3001;

sub deps
{
	my %r;
	for my $stage (@_)
	{
		for my $dep (keys %{$meta->{prereqs}{$stage}{requires}})
		{
			next if $dep eq 'perl';
			my $ver = $meta->{prereqs}{$stage}{requires}{$dep};
			$r{$dep} = $ver if !exists($r{$dep}) || $ver >= $r{$dep};
		}
	}
	\%r;
}

my ($build_requires, $configure_requires, $runtime_requires, $test_requires);
if ($EUMM >= 6.6303)
{
	$WriteMakefileArgs{BUILD_REQUIRES}     ||= deps('build');
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{TEST_REQUIRES}      ||= deps('test');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime');
}
elsif ($EUMM >= 6.5503)
{
	$WriteMakefileArgs{BUILD_REQUIRES}     ||= deps('build', 'test');
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime');	
}
elsif ($EUMM >= 6.52)
{
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime', 'build', 'test');	
}
else
{
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('configure', 'build', 'test', 'runtime');	
}

{
	my ($minperl) = reverse sort(
		grep defined && /^[0-9]+(\.[0-9]+)?$/,
		map $meta->{prereqs}{$_}{requires}{perl},
		qw( configure build runtime )
	);
	
	if (defined($minperl))
	{
		die "Installing $meta->{name} requires Perl >= $minperl"
			unless $] >= $minperl;
		
		$WriteMakefileArgs{MIN_PERL_VERSION} ||= $minperl
			if $EUMM >= 6.48;
	}
}


my $mm = WriteMakefile(%WriteMakefileArgs);

exit(0);


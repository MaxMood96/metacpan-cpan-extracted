use strict;
use ExtUtils::MakeMaker 6.17;

my $EUMM = eval( $ExtUtils::MakeMaker::VERSION );

my $meta = {
  "abstract"           => "a distinctly Dist-Inkt-flavoured distribution mint",
  "author"             => ["Toby Inkster (TOBYINK) <tobyink\@cpan.org>"],
  "dynamic_config"     => 0,
  "generated_by"       => "Dist::Inkt::Profile::TOBYINK version 0.024, CPAN::Meta::Converter version 2.150010",
  "keywords"           => [],
  "license"            => ["perl_5"],
  "meta-spec"          => {
                            url => "http://search.cpan.org/perldoc?CPAN::Meta::Spec",
                            version => 2,
                          },
  "name"               => "Dist-Inktly-Minty",
  "no_index"           => { directory => ["eg", "examples", "inc", "t", "xt"] },
  "prereqs"            => {
                            configure => { requires => { "ExtUtils::MakeMaker" => 6.17 } },
                            runtime   => {
                                           requires => {
                                             "File::chdir"       => 0,
                                             "Getopt::ArgvFile"  => 0,
                                             "Path::Tiny"        => 0,
                                             "perl"              => 5.010001,
                                             "Software::License" => 0,
                                             "Text::Template"    => 0,
                                             "URI::Escape"       => 0,
                                           },
                                         },
                          },
  "provides"           => {
                            "Dist::Inktly::Bovine"  => { file => "lib/Dist/Inktly/Bovine.pm", version => 0.005 },
                            "Dist::Inktly::Cervine" => { file => "lib/Dist/Inktly/Cervine.pm", version => 0.005 },
                            "Dist::Inktly::Minty"   => { file => "lib/Dist/Inktly/Minty.pm", version => 0.005 },
                          },
  "release_status"     => "stable",
  "resources"          => {
                            bugtracker   => { web => "https://github.com/tobyink/p5-dist-inktly-minty/issues" },
                            homepage     => "https://metacpan.org/release/Dist-Inktly-Minty",
                            license      => ["http://dev.perl.org/licenses/"],
                            repository   => {
                                              type => "git",
                                              url  => "git://github.com/tobyink/p5-dist-inktly-minty.git",
                                              web  => "https://github.com/tobyink/p5-dist-inktly-minty",
                                            },
                            x_identifier => "http://purl.org/NET/cpan-uri/dist/Dist-Inktly-Minty/project",
                          },
  "version"            => 0.005,
  "x_provides_scripts" => { "distinkt-mint" => { file => "bin/distinkt-mint" } },
};

my %dynamic_config;

my %WriteMakefileArgs = (
	ABSTRACT   => $meta->{abstract},
	AUTHOR     => ($EUMM >= 6.5702 ? $meta->{author} : $meta->{author}[0]),
	DISTNAME   => $meta->{name},
	VERSION    => $meta->{version},
	EXE_FILES  => [ map $_->{file}, values %{ $meta->{x_provides_scripts} || {} } ],
	NAME       => do { my $n = $meta->{name}; $n =~ s/-/::/g; $n },
	test       => { TESTS => "t/*.t" },
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


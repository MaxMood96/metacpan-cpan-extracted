use strict;
use ExtUtils::MakeMaker 6.17;

my $EUMM = eval( $ExtUtils::MakeMaker::VERSION );

my $meta = {
  "abstract"         => "use Class::XSAccessor to speed up Moose accessors",
  "author"           => ["Toby Inkster (TOBYINK) <tobyink\@cpan.org>"],
  "dynamic_config"   => 0,
  "generated_by"     => "Dist::Inkt::Profile::TOBYINK version 0.024, CPAN::Meta::Converter version 2.150010",
  "keywords"         => [],
  "license"          => ["perl_5"],
  "meta-spec"        => {
                          url => "http://search.cpan.org/perldoc?CPAN::Meta::Spec",
                          version => 2,
                        },
  "name"             => "MooseX-XSAccessor",
  "no_index"         => { directory => ["eg", "examples", "inc", "t", "xt"] },
  "prereqs"          => {
                          configure => { requires => { "ExtUtils::MakeMaker" => 6.17 } },
                          runtime => {
                            requires => { "Class::XSAccessor" => 1.09, "Moose" => "2.0600", "perl" => 5.008 },
                            suggests => { "MooseX::Attribute::Chained" => 0, "MooseX::LvalueAttribute" => 0 },
                          },
                          test => {
                            recommends => {
                                            "MooseX::Attribute::Chained" => 0,
                                            "MooseX::FunkyAttributes"    => 0,
                                            "MooseX::LvalueAttribute"    => 0,
                                          },
                            requires   => {
                                            "Import::Into"   => "1.001000",
                                            "Test::Fatal"    => 0,
                                            "Test::Moose"    => 0,
                                            "Test::More"     => 0.96,
                                            "Test::Requires" => 0,
                                          },
                          },
                        },
  "provides"         => {
                          "MooseX::XSAccessor" => { file => "lib/MooseX/XSAccessor.pm", version => "0.010" },
                          "MooseX::XSAccessor::Trait::Attribute" => {
                            file => "lib/MooseX/XSAccessor/Trait/Attribute.pm",
                            version => "0.010",
                          },
                        },
  "release_status"   => "stable",
  "resources"        => {
                          bugtracker   => { web => "https://github.com/tobyink/p5-moosex-xsaccessor/issues" },
                          homepage     => "https://metacpan.org/release/MooseX-XSAccessor",
                          license      => ["http://dev.perl.org/licenses/"],
                          repository   => {
                                            type => "git",
                                            url  => "git://github.com/tobyink/p5-moosex-xsaccessor.git",
                                            web  => "https://github.com/tobyink/p5-moosex-xsaccessor",
                                          },
                          x_identifier => "http://purl.org/NET/cpan-uri/dist/MooseX-XSAccessor/project",
                        },
  "version"          => "0.010",
  "x_contributors"   => ["Florian Ragwitz (FLORA) <flora\@cpan.org>"],
  "x_static_install" => 1,
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


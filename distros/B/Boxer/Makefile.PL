use strict;
use ExtUtils::MakeMaker 6.17;

my $EUMM = eval( $ExtUtils::MakeMaker::VERSION );

my $meta = {
  "abstract"           => "boxer command line utils",
  "author"             => ["Jonas Smedegaard (JONASS) <jonass\@cpan.org>"],
  "dynamic_config"     => 0,
  "generated_by"       => "Dist::Inkt::Profile::TOBYINK version 0.024, CPAN::Meta::Converter version 2.150010",
  "keywords"           => ["Debian", "Distribution"],
  "license"            => ["perl_5"],
  "meta-spec"          => {
                            url => "http://search.cpan.org/perldoc?CPAN::Meta::Spec",
                            version => 2,
                          },
  "name"               => "Boxer",
  "no_index"           => { directory => ["eg", "examples", "inc", "t", "xt"] },
  "prereqs"            => {
                            configure => {
                              requires => { "ExtUtils::MakeMaker" => 6.17, "File::ShareDir::Install" => 0.02 },
                            },
                            runtime => {
                              requires => {
                                "App::Cmd"                  => 0,
                                "autodie"                   => 0,
                                "Class::XSAccessor"         => 0,
                                "File::BaseDir"             => 0,
                                "File::ShareDir"            => 0,
                                "Hash::Merge"               => 0,
                                "IPC::System::Simple"       => 0,
                                "List::MoreUtils"           => 0,
                                "Log::Any::Adapter::Screen" => 0,
                                "match::simple"             => 0,
                                "Module::Find"              => 0,
                                "Module::Load::Conditional" => 0,
                                "Module::Runtime"           => 0,
                                "Moo"                       => "1.001000",
                                "MooX::Role::Logger"        => 0,
                                "MooX::StrictConstructor"   => 0,
                                "namespace::autoclean"      => 0.16,
                                "Path::Tiny"                => 0.054,
                                "perl"                      => "5.020000",
                                "Role::Commons"             => 0,
                                "strictures"                => 2,
                                "Template::Tiny"            => 0.11,
                                "Try::Tiny"                 => 0,
                                "Types::Path::Tiny"         => 0,
                                "Types::Standard"           => 0,
                                "YAML::XS"                  => 0,
                              },
                            },
                            test => {
                              requires => {
                                "English"               => 0,
                                "File::Spec"            => 0,
                                "File::Which"           => 0,
                                "Test::CleanNamespaces" => 0,
                                "Test::Compile"         => 0,
                                "Test::Deep"            => 0.111,
                                "Test::Fatal"           => 0,
                                "Test::File::Contents"  => 0,
                                "Test::Fixme"           => 0,
                                "Test::MinimumVersion"  => 0,
                                "Test::More"            => 0.61,
                                "Test::Pod"             => "1.00",
                                "Test::Synopsis"        => 0,
                              },
                            },
                          },
  "provides"           => {
                            "Boxer"                          => { file => "lib/Boxer.pm", version => "v1.4.3" },
                            "Boxer::CLI"                     => { file => "lib/Boxer/CLI.pm", version => "v1.4.3" },
                            "Boxer::CLI::Command"            => { file => "lib/Boxer/CLI/Command.pm", version => "v1.4.3" },
                            "Boxer::CLI::Command::About"     => { file => "lib/Boxer/CLI/Command/About.pm", version => "v1.4.3" },
                            "Boxer::CLI::Command::Aliases"   => { file => "lib/Boxer/CLI/Command/Aliases.pm", version => "v1.4.3" },
                            "Boxer::CLI::Command::Bootstrap" => { file => "lib/Boxer/CLI/Command/Bootstrap.pm", version => "v1.4.3" },
                            "Boxer::CLI::Command::Commands"  => { file => "lib/Boxer/CLI/Command/Commands.pm", version => "v1.4.3" },
                            "Boxer::CLI::Command::Compose"   => { file => "lib/Boxer/CLI/Command/Compose.pm", version => "v1.4.3" },
                            "Boxer::File::WithSkeleton"      => { file => "lib/Boxer/File/WithSkeleton.pm", version => "v1.4.3" },
                            "Boxer::Part"                    => { file => "lib/Boxer/Part.pm", version => "v1.4.3" },
                            "Boxer::Part::Reclass"           => { file => "lib/Boxer/Part/Reclass.pm", version => "v1.4.3" },
                            "Boxer::Role::Interact"          => { file => "lib/Boxer/Role/Interact.pm", version => "v1.4.3" },
                            "Boxer::Task"                    => { file => "lib/Boxer/Task.pm", version => "v1.4.3" },
                            "Boxer::Task::Bootstrap"         => { file => "lib/Boxer/Task/Bootstrap.pm", version => "v1.4.3" },
                            "Boxer::Task::Classify"          => { file => "lib/Boxer/Task/Classify.pm", version => "v1.4.3" },
                            "Boxer::Task::Serialize"         => { file => "lib/Boxer/Task/Serialize.pm", version => "v1.4.3" },
                            "Boxer::Types"                   => { file => "lib/Boxer/Types.pm", version => "v1.4.3" },
                            "Boxer::World"                   => { file => "lib/Boxer/World.pm", version => "v1.4.3" },
                            "Boxer::World::Flat"             => { file => "lib/Boxer/World/Flat.pm", version => "v1.4.3" },
                            "Boxer::World::Reclass"          => { file => "lib/Boxer/World/Reclass.pm", version => "v1.4.3" },
                          },
  "release_status"     => "stable",
  "resources"          => {
                            bugtracker   => { web => "http://rt.cpan.org/Dist/Display.html?Queue=Boxer" },
                            homepage     => "https://wiki.debian.org/Boxer",
                            license      => ["http://dev.perl.org/licenses/"],
                            repository   => { type => "git", web => "https://salsa.debian.org/boxer-team/boxer" },
                            x_identifier => "http://purl.org/NET/cpan-uri/dist/Boxer/project",
                          },
  "version"            => "v1.4.3",
  "x_help_wanted"      => ["documenter", "tester"],
  "x_provides_scripts" => { boxer => { file => "bin/boxer" } },
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


use File::ShareDir::Install;
install_share 'share';
{ package MY; use File::ShareDir::Install qw(postamble) };

my $mm = WriteMakefile(%WriteMakefileArgs);

exit(0);


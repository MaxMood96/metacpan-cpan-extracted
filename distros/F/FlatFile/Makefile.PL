use 5.006; use strict; use warnings;

my $sc = q<https://github.com/ap/FlatFile>;
my $bt = q<https://rt.cpan.org/Public/Dist/Display.html?Name=FlatFile>;

my %META = (
	name             => 'FlatFile',
	author           => 'Mark Jason Dominus',
	x_copyright      => { holder => 'Mark Jason Dominus', year => 2006 },
	license          => 'perl_5',
	prereqs          => {
		test         => {
			requires => {
				'Test::More'    => 0,
				'File::Copy'    => 0,
				'Tie::File'     => 0,
			},
		},
		runtime      => {
			requires => {
				perl            => '5.006',
				'Tie::File'     => 0,
			},
		},
	},
	dynamic_config => 0,
	resources      => {
		repository => { type => 'git', url => "$sc.git", web => $sc },
		bugtracker => { web => $bt },
		license    => [ 'http://dev.perl.org/licenses/' ],
	},
);

sub MY::postamble { -f 'META.yml' ? return : <<'' }
create_distdir : MANIFEST
MANIFEST :
	( git ls-files ':!README.pod' ; echo MANIFEST ) | sort -f > MANIFEST
distdir : boilerplate
.PHONY  : boilerplate
boilerplate : distmeta
	$(PERL) -I. boilerplate.pl $(DISTVNAME)

## BOILERPLATE ###############################################################
require ExtUtils::MakeMaker;

my %MM_ARGS;

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $eumm_version  = eval $ExtUtils::MakeMaker::VERSION;
my $mymeta        = $eumm_version >= 6.57_02;
my $mymeta_broken = $mymeta && $eumm_version < 6.57_07;

($MM_ARGS{NAME} = $META{name}) =~ s/-/::/g;
($MM_ARGS{VERSION_FROM} = "$MM_ARGS{NAME}.pm") =~ s{::}{/}g;
$MM_ARGS{ABSTRACT_FROM} = $MM_ARGS{VERSION_FROM};
$META{license} = [ $META{license} ]
	if $META{license} && !ref $META{license};
$MM_ARGS{LICENSE} = $META{license}[0]
	if $META{license} && $eumm_version >= 6.30;
$MM_ARGS{NO_MYMETA} = 1
	if $mymeta_broken;
$MM_ARGS{META_ADD} = { 'meta-spec' => { version => 2 }, %META }
	unless -f 'META.yml';
$MM_ARGS{PL_FILES} ||= {};
$MM_ARGS{NORECURS} = 1
	if not exists $MM_ARGS{NORECURS};

for (qw(configure build test runtime)) {
	my $key = $_ eq 'runtime' ? 'PREREQ_PM' : uc $_.'_REQUIRES';
	my $r = $MM_ARGS{$key} = {
		%{$META{prereqs}{$_}{requires} || {}},
		%{delete $MM_ARGS{$key} || {}},
	};
	defined $r->{$_} or delete $r->{$_} for keys %$r;
}

$MM_ARGS{MIN_PERL_VERSION} = eval delete $MM_ARGS{PREREQ_PM}{perl} || 0;

delete $MM_ARGS{MIN_PERL_VERSION}
	if $eumm_version < 6.47_01;
$MM_ARGS{BUILD_REQUIRES} = {%{$MM_ARGS{BUILD_REQUIRES}}, %{delete $MM_ARGS{TEST_REQUIRES}}}
	if $eumm_version < 6.63_03;
$MM_ARGS{PREREQ_PM} = {%{$MM_ARGS{PREREQ_PM}}, %{delete $MM_ARGS{BUILD_REQUIRES}}}
	if $eumm_version < 6.55_01;
delete $MM_ARGS{CONFIGURE_REQUIRES}
	if $eumm_version < 6.51_03;

ExtUtils::MakeMaker::WriteMakefile(%MM_ARGS);
## END BOILERPLATE ###########################################################

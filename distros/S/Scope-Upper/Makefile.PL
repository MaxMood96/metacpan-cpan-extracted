use 5.006_001;

use strict;
use warnings;
use ExtUtils::MakeMaker;

use Config;

if ($Config{d_cplusplus}) {
 print STDERR <<'FAILPLUSPLUS';
Configuration aborted: C++ compilers are not supported

    Your perl has been built with a C++ compiler, which is then handed to
    XS extensions as if it were a proper C compiler. This extension is
    written in C, and naturally only supports C compilers, so it cannot be
    built with your perl.

    Note that building perl with a C++ compiler is only supposed to be done
    by core developers in order to check that the perl headers can be
    included from C++ code. Its use in the wild is not supported by the
    perl5 porters. If your vendor has built its perl binary with a C++
    compiler, please consider reporting this issue to them.

    This text will be displayed 10 seconds, and then the configuration
    script will exit.
FAILPLUSPLUS
 sleep 10;
 exit 0;
}

my $pl   = $Config{perl_patchlevel};
my $desc = $Config{git_describe};
for ($pl, $desc) {
 $_ = undef unless defined and length;
}

my @DEFINES;
my %macro;

print "Checking if this is an official release of perl... ";
my $is_release = ("$]" < 5.011) ? (defined($pl) || defined($desc) ? 0 : 1)
                                : (defined($desc)                 ? 0 : 1);
push @DEFINES, "-DSU_RELEASE=$is_release";
print $is_release  ? "yes\n" : "no\n";

my $is_gcc_34 = 0;
print "Checking if this is gcc 3.4 on Windows trying to link against an import library... ";
if ($^O eq 'MSWin32' and not grep /^LD[A-Z]*=/, @ARGV) {
 my ($libperl, $gccversion) = map $_ || '', @Config{qw<libperl gccversion>};
 if ($gccversion =~ /^3\.4\.[0-9]+/ and $libperl =~ s/\.lib$//) {
  $is_gcc_34 = 1;
  my ($lddlflags, $ldflags) = @Config{qw<lddlflags ldflags>};
  $_ ||= '', s/-L(?:".*?"|\S+)//g for $lddlflags, $ldflags;
  $libperl = "-l$libperl";
  my $libdirs = join ' ',
                 map { s/(?<!\\)((?:\\\\)*")/\\$1/g; qq[-L"$_"] }
                  @Config{qw<bin sitebin>};
  $macro{LDDLFLAGS}    = "$lddlflags $libdirs $libperl";
  $macro{LDFLAGS}      = "$ldflags $libdirs $libperl";
  eval <<'  MY_SECTION';
   package MY;
   sub dynamic_lib {
    my $self = shift;
    my $inherited = $self->SUPER::dynamic_lib(@_);
    $inherited =~ s/"?\$\(PERL_ARCHIVE\)"?//g;
    return $inherited;
   }
  MY_SECTION
  die $@ if $@;
 }
}
print $is_gcc_34 ? "yes\n" : "no\n";

# Threads, Windows and 5.8.x don't seem to be best friends
if ($^O eq 'MSWin32' && "$]" < 5.009) {
 push @DEFINES, '-DXSH_MULTIPLICITY=0';
}

@DEFINES = (DEFINE => join ' ', @DEFINES) if @DEFINES;
%macro   = (macro  => { %macro })         if %macro; # Beware of the cycle

my $dist = 'Scope-Upper';

(my $name = $dist) =~ s{-}{::}g;

(my $file = $dist) =~ s{-}{/}g;
$file = "lib/$file.pm";

my $bug_web    = "http://rt.cpan.org/Dist/Display.html?Name=$dist",
my $bug_mailto = 'bug-' . lc($dist) . '@rt.cpan.org';

my $repo_host = 'git.vpit.fr';
my @repo_path = ('perl', 'modules', "$dist.git");
my $repo_url  = join '/', 'http:', '', $repo_host, @repo_path, '';
my $repo_web  = "http://$repo_host/?p=" . join('%2F', @repo_path);

my %PREREQ_PM = (
 'Exporter' => 0,
 'XSLoader' => 0,
 'base'     => 0,
);

my %BUILD_REQUIRES = (
 'ExtUtils::MakeMaker' => 0,
 'Config'              => 0,
 'POSIX'               => 0,
 'Test::More'          => 0,
 %PREREQ_PM,
);

my %META = (
 'meta-spec' => {
  version => '2',
  url     => 'http://search.cpan.org/perldoc?CPAN::Meta::Spec',
 },
 configure_requires => {
  'Config'              => 0,
  'ExtUtils::MakeMaker' => 0,
 },
 build_requires => {
  %BUILD_REQUIRES,
 },
 dynamic_config => 1,
 resources => {
  bugtracker => {
   web    => $bug_web,
   mailto => $bug_mailto,
  },
  homepage   => "http://search.cpan.org/dist/$dist/",
  license    => 'http://dev.perl.org/licenses/',
  repository => {
   type => 'git',
   url  => $repo_url,
   web  => $repo_web,
  },
 },
);

WriteMakefile(
 NAME             => $name,
 AUTHOR           => 'Vincent Pit <vpit@cpan.org>',
 LICENSE          => 'perl',
 VERSION_FROM     => $file,
 ABSTRACT_FROM    => $file,
 PL_FILES         => {},
 @DEFINES,
 BUILD_REQUIRES   => \%BUILD_REQUIRES,
 PREREQ_PM        => \%PREREQ_PM,
 MIN_PERL_VERSION => '5.006001',
 META_MERGE       => \%META,
 dist             => {
  PREOP    => "pod2text -u $file > \$(DISTVNAME)/README",
  COMPRESS => 'gzip -9f', SUFFIX => 'gz'
 },
 clean            => {
  FILES => "$dist-* *.gcov *.gcda *.gcno cover_db Debian_CPANTS.txt*"
 },
 %macro,
);

package MY;

sub postamble {
 return <<'POSTAMBLE';
testdeb: all
	PERL_DL_NONLAZY=1 PERLDB_OPTS="NonStop=1" $(FULLPERLRUN) -MTAP::Harness -e 'TAP::Harness->new({verbosity => q{$(TEST_VERBOSE)}, lib => [ q{$(INST_LIB)}, q{$(INST_ARCHLIB)} ], switches => [ q{-d} ]})->runtests(@ARGV)' $(TEST_FILES)
POSTAMBLE
}

use v5.10; use strict; use warnings;
use ExtUtils::MakeMaker;
use Alien::Base::Wrapper ();
use Alien::curlimpersonate ();

# 0.02 is where curl-impersonate 2.x arrived. Checked here as well as declared
# below, because a git checkout has no META to read the requirement from.
Alien::curlimpersonate->VERSION('0.02');

# cflags/libs (and CONFIGURE_REQUIRES on the Alien) come from the wrapper.
my %aw = Alien::Base::Wrapper->new('Alien::curlimpersonate')->mm_args2;
$aw{CONFIGURE_REQUIRES}{'Alien::curlimpersonate'} = '0.02';   # wrapper asks for any

# Alien::Base relocates -L but not -Wl,-rpath, so the wrapper emits no rpath.
# Add one to the resolved lib dir so the linked XS finds
# libcurl-impersonate.so.4 at runtime without LD_LIBRARY_PATH.
my ($libdir) = Alien::curlimpersonate->dynamic_libs;
$libdir =~ s{/[^/]+$}{} if defined $libdir;
$aw{LDDLFLAGS} = join ' ',
    grep { defined && length }
    $aw{LDDLFLAGS}, ($libdir ? "-Wl,-rpath,$libdir" : ());

WriteMakefile(
    NAME             => 'Curl::Impersonate',
    VERSION_FROM     => 'lib/Curl/Impersonate.pm',
    ABSTRACT         => 'HTTP client that impersonates a browser TLS/HTTP2 fingerprint',
    AUTHOR           => 'vividsnow',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    TEST_REQUIRES    => { 'Test::More' => 0 },
    META_MERGE       => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/vividsnow/perl5-curl-impersonate.git',
                web  => 'https://github.com/vividsnow/perl5-curl-impersonate',
            },
            bugtracker => { web => 'https://github.com/vividsnow/perl5-curl-impersonate/issues' },
        },
        (eval { require Module::Metadata; 1 }
            ? (provides => Module::Metadata->provides(version => 2, dir => 'lib'))
            : ()),
    },
    %aw,
);

# README is generated, never edited -- a hand-kept one drifts from the POD.
# distdir depends on it so a release cannot ship a stale one.
sub MY::postamble {
    return <<"MAKE";

readme : README

README : lib/Curl/Impersonate.pm
\t\$(PERLRUN) -MPod::Text -e "Pod::Text->new->parse_from_file(q{lib/Curl/Impersonate.pm}, q{README})"

# create_distdir, not distdir: distdir's prerequisites are built left to right,
# so create_distdir would copy the files before README was regenerated.
create_distdir : README

MAKE
}

use strict;
use warnings;
use ExtUtils::MakeMaker;
use Alien::Build::MM;

my $abmm = Alien::Build::MM->new;

WriteMakefile($abmm->mm_args(
    NAME             => 'Alien::TDLib',
    DISTNAME         => 'Alien-TDLib',
    VERSION_FROM     => 'lib/Alien/TDLib.pm',
    ABSTRACT         => 'Find or build TDLib, the Telegram client library',
    AUTHOR           => 'vividsnow',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.012',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.64',
        'Alien::Build::MM'    => '2.40',
        'Alien::Build'        => '2.40',
    },
    BUILD_REQUIRES => {
        'Alien::Build'     => '2.40',
        # the share path fetches the npm registry and GitHub over HTTPS
        'IO::Socket::SSL'  => '1.42',
        'Net::SSLeay'      => '1.49',
        'Mozilla::CA'      => 0,
    },
    PREREQ_PM => {
        'Alien::Base' => '2.40',
    },
    TEST_REQUIRES => {
        'Test::More'   => '0.98',
        'Test::Alien'  => '2.40',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        dynamic_config => 1,
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/vividsnow/perl5-alien-tdlib.git',
                web  => 'https://github.com/vividsnow/perl5-alien-tdlib',
            },
            bugtracker => {
                web => 'https://github.com/vividsnow/perl5-alien-tdlib/issues',
            },
        },
        provides => {
            'Alien::TDLib' => {
                file    => 'lib/Alien/TDLib.pm',
                version => MM->parse_version('lib/Alien/TDLib.pm'),
            },
        },
    },
));

sub MY::postamble {
    my $self = shift;
    return $abmm->mm_postamble($self, @_) . <<"MAKE";
README : lib/Alien/TDLib.pm
	pod2text lib/Alien/TDLib.pm > README

distdir : README

MAKE
}


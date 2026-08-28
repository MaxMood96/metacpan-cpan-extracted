use strict;
use warnings;
use Config;
use ExtUtils::MakeMaker;
use EV::MakeMaker;
use Alien::TDLib;

die "EV::Telegram::TDLib needs a perl with 64-bit integers "
  . "(ivsize=$Config{ivsize}); Telegram message ids do not fit in an NV\n"
    if $Config{ivsize} < 8;

my %ev = EV::MakeMaker::ev_args();

WriteMakefile(
    NAME             => 'EV::Telegram::TDLib',
    VERSION_FROM     => 'lib/EV/Telegram/TDLib.pm',
    ABSTRACT         => 'Asynchronous Telegram client on TDLib and EV',
    AUTHOR           => 'vividsnow',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.012',
    XS               => { 'TDLib.xs' => 'TDLib.c' },
    OBJECT           => 'TDLib$(OBJ_EXT)',
    INC              => Alien::TDLib->cflags . ' ' . $ev{INC},
    LIBS             => [ Alien::TDLib->libs . ' -lpthread' ],
    CCFLAGS          => "$Config{ccflags} -std=gnu11",
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.64',
        'EV::MakeMaker'       => 0,
        'Alien::TDLib'        => 0,
    },
    PREREQ_PM => {
        'EV'               => '4.11',
        'Alien::TDLib'     => 0,
        'Cpanel::JSON::XS' => '4.00',
        # core since well before the perl floor, but declared because the
        # module uses them
        'Carp'             => 0,
        'Encode'           => 0,
        'MIME::Base64'     => 0,
        'XSLoader'         => 0,
    },
    TEST_REQUIRES => { 'Test::More' => '0.98' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        # xt ships a helper module in its own top-level namespace; provides
        # already pins what gets indexed, and this makes doubly sure
        no_index => { directory => [ 'xt' ] },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/vividsnow/perl5-ev-telegram-tdlib.git',
                web  => 'https://github.com/vividsnow/perl5-ev-telegram-tdlib',
            },
            bugtracker => {
                web => 'https://github.com/vividsnow/perl5-ev-telegram-tdlib/issues',
            },
        },
        provides => {
            'EV::Telegram::TDLib' => {
                file    => 'lib/EV/Telegram/TDLib.pm',
                version => MM->parse_version('lib/EV/Telegram/TDLib.pm'),
            },
            map {
                +("EV::Telegram::TDLib::$_" => {
                    file    => "lib/EV/Telegram/TDLib/$_.pm",
                    version => MM->parse_version('lib/EV/Telegram/TDLib.pm'),
                })
            } qw(Users Chats Messages Files Connection Bots
                 WebApps Forum Folders Payments Secret Schema),
        },
    },
);

sub MY::postamble {
    return <<"MAKE";
README : lib/EV/Telegram/TDLib.pm
	pod2text lib/EV/Telegram/TDLib.pm > README

distdir : README

MAKE
}

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'IPTV::Playlist::M3UTools',
    VERSION_FROM => 'lib/IPTV/Playlist/M3UTools.pm',
    ABSTRACT     => 'Offline URL helpers for IPTV Playlist pages',
    AUTHOR       => 'bbwdadfg',
    LICENSE      => 'mit',
    META_MERGE   => {
        resources => {
            homepage => 'https://iptvplaylist.app/',
            repository => 'https://github.com/bbwdadfg/iptvplaylist-m3u-tools',
        },
    },
);

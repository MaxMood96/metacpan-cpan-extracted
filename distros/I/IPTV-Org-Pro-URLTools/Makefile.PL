use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'IPTV::Org::Pro::URLTools',
    VERSION_FROM => 'lib/IPTV/Org/Pro/URLTools.pm',
    ABSTRACT => 'Offline URL helpers for iptv-org pro',
    AUTHOR => 'bbwdadfg',
    LICENSE => 'mit',
    META_MERGE => { resources => { homepage => 'https://iptv-org.pro/', repository => 'https://github.com/bbwdadfg/iptv-org-pro-url-tools' } },
);

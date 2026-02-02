use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Ancient',
    DISTNAME         => 'Ancient',
    VERSION          => '0.14',
    ABSTRACT         => 'Post-Apocalyptic Perl',
    MIN_PERL_VERSION => '5.010',
    AUTHOR       => 'LNATION <email@lnation.org>',
    LICENSE      => 'perl_5',
    macro        => { TARFLAGS => "--format=ustar -c -v -f" },
    DIR          => [qw(xs/slot xs/util xs/noop xs/const xs/doubly xs/object xs/lru xs/heap xs/file xs/nvec t/xs/nvec_api_test t/xs/util_export_test t/xs/file_api_test)],
    META_MERGE   => {
        'meta-spec' => { version => 2 },
        provides => {
            'Ancient' => {
                file    => 'lib/Ancient.pm',
                version => '0.14',
            },
        },
    },
);

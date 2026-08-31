use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Aitextcleaner::FormattingResidue',
    VERSION_FROM => 'lib/Aitextcleaner/FormattingResidue.pm',
    LICENSE      => 'mit',
    ABSTRACT     => 'Local formatting-residue cleanup helper for copied text.',
    PREREQ_PM    => {},
    META_MERGE   => {
        resources => {
            homepage => 'https://aitextcleaner.pro/',
            repository => 'https://aitextcleaner.pro/',
            bugtracker => 'https://aitextcleaner.pro/',
        },
    },
);

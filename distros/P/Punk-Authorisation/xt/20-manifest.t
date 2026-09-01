#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

# The MANIFEST is what `make dist` ships, and this distribution's schema is
# 11 files under lib/ that no default rule would find. A file missing here is
# a tarball that installs a plugin whose Sqitch project is not there.
#
# In xt/ rather than t/: it fails on a working tree that has build artefacts
# a released tarball does not, and a missing-file failure on a user's machine
# helps nobody.

plan skip_all => 'ExtUtils::Manifest required'
    unless eval { require ExtUtils::Manifest; 1 };

{
    my @missing = ExtUtils::Manifest::manicheck();
    is_deeply(\@missing, [], 'every file in MANIFEST is on disk');
    diag("missing from disk: $_") for @missing;
}

# The other direction, minus what the build leaves behind: .c, .o and .bs are
# in ignore.txt, and MANIFEST.SKIP does not cover them here any more than it
# does in Punk-DIY.
{
    local $ExtUtils::Manifest::Quiet = 1;   # it warns about each one as well
    my @extra = grep { !/\.(?:c|o|bs)\z/ } ExtUtils::Manifest::filecheck();
    is_deeply(\@extra, [], 'nothing on disk is missing from MANIFEST');
    diag("not in MANIFEST: $_") for @extra;
}

done_testing();

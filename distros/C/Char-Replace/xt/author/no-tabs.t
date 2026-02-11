use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Char/Replace.pm',
    't/00-load.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/backslash-0.t',
    't/build-map.t',
    't/coderef-map.t',
    't/deletion.t',
    't/iv-map.t',
    't/replace-inplace.t',
    't/replace.t',
    't/taint-safety.t',
    't/trim-inplace.t',
    't/trim.t',
    't/utf8-safety.t'
);

notabs_ok($_) foreach @files;
done_testing;

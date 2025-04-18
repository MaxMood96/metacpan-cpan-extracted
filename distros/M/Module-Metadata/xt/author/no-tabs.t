use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Module/Metadata.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/contains_pod.t',
    't/encoding.t',
    't/endpod.t',
    't/extract-package.t',
    't/extract-version.t',
    't/lib/0_1/Foo.pm',
    't/lib/0_2/Foo.pm',
    't/lib/ENDPOD.pm',
    't/lib/GeneratePackage.pm',
    't/metadata.t',
    't/taint.t',
    't/version.t',
    'xt/author/00-compile.t',
    'xt/author/compat_lc.t',
    'xt/author/distmeta.t',
    'xt/author/eol.t',
    'xt/author/kwalitee.t',
    'xt/author/minimum-version.t',
    'xt/author/mojibake.t',
    'xt/author/no-tabs.t',
    'xt/author/pod-coverage.t',
    'xt/author/pod-no404s.t',
    'xt/author/pod-syntax.t',
    'xt/author/portability.t',
    'xt/release/changes_has_content.t',
    'xt/release/cpan-changes.t'
);

notabs_ok($_) foreach @files;
done_testing;

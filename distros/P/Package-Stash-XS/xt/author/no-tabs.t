use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Package/Stash/XS.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/addsub.t',
    't/anon-basic.t',
    't/anon.t',
    't/bare-anon-basic.t',
    't/bare-anon.t',
    't/basic.t',
    't/compile-time.t',
    't/edge-cases.t',
    't/extension.t',
    't/get.t',
    't/io.t',
    't/isa.t',
    't/lib/CompileTime.pm',
    't/lib/Package/Stash.pm',
    't/magic.t',
    't/paamayim_nekdotayim.t',
    't/scalar-values.t',
    't/stash-deletion.t',
    't/synopsis.t',
    't/warnings.t',
    't/zzz-check-breaks.t',
    'xt/author/00-compile.t',
    'xt/author/clean-namespaces.t',
    'xt/author/distmeta.t',
    'xt/author/eol.t',
    'xt/author/kwalitee.t',
    'xt/author/leaks-debug.t',
    'xt/author/leaks.t',
    'xt/author/minimum-version.t',
    'xt/author/mojibake.t',
    'xt/author/no-tabs.t',
    'xt/author/pod-coverage.t',
    'xt/author/pod-no404s.t',
    'xt/author/pod-spell.t',
    'xt/author/pod-syntax.t',
    'xt/author/portability.t',
    'xt/release/changes_has_content.t',
    'xt/release/cpan-changes.t'
);

notabs_ok($_) foreach @files;
done_testing;

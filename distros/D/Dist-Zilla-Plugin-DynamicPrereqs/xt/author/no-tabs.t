use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Dist/Zilla/Plugin/DynamicPrereqs.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01-basic.t',
    't/02-no-makefile.t',
    't/03-build_pl.t',
    't/04-two-plugins.t',
    't/05-overshadow-static.t',
    't/06-makemaker-awesome.t',
    't/07-unknown-arguments.t',
    't/08-empty-prereqs.t',
    't/09-delimiter-whitespace.t',
    't/10-raw-from-file.t',
    't/11-include-sub.t',
    't/12-include-sub-definitions.t',
    't/13-two-plugins.t',
    't/14-nonexistent-sub.t',
    't/15-conditions-raw.t',
    't/17-sub-prereqs-core.t',
    't/18-subs.t',
    't/19-include-subs-requires.t',
    't/20-include-subs-allraw.t',
    't/21-body-from-file.t',
    't/22-conditions-body.t',
    't/23-inlined-module.t',
    't/lib/Helper.pm',
    't/lib/Inlined/Dependency.pm',
    't/lib/Inlined/Module.pm',
    't/zzz-check-breaks.t',
    'xt/author/00-compile.t',
    'xt/author/clean-namespaces.t',
    'xt/author/distmeta.t',
    'xt/author/eol.t',
    'xt/author/kwalitee.t',
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

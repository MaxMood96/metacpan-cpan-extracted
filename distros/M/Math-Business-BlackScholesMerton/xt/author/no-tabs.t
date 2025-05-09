use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Math/Business/BlackScholesMerton.pm',
    'lib/Math/Business/BlackScholesMerton/Binaries.pm',
    'lib/Math/Business/BlackScholesMerton/NonBinaries.pm',
    't/00-check-deps.t',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/BlackScholes.t',
    't/barrier_infinity.t',
    't/barrier_zero.t',
    't/benchmark.t',
    't/get_min_iterations_pelsser.t',
    't/get_stability_constant_pelsser_1997.t',
    't/lib/Roundnear.pm',
    't/min_accuracy_pelsser.t',
    't/negative_rate.t',
    't/non_negative_price.t',
    't/price_test.t',
    't/pricing_params.csv',
    't/rc/perlcriticrc',
    't/rc/perltidyrc',
    't/small_value_mu.t',
    't/smalltime.t',
    't/sum_to_one.t',
    'xt/author/critic.t',
    'xt/author/distmeta.t',
    'xt/author/eol.t',
    'xt/author/minimum-version.t',
    'xt/author/mojibake.t',
    'xt/author/no-tabs.t',
    'xt/author/pod-syntax.t',
    'xt/author/portability.t',
    'xt/author/test-version.t',
    'xt/release/common_spelling.t',
    'xt/release/cpan-changes.t'
);

notabs_ok($_) foreach @files;
done_testing;
